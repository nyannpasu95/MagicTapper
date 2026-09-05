import Foundation
import CoreGraphics
import AppKit
import IOKit

// Swift wrapper for Multitouch framework
final class MultitouchManager: @unchecked Sendable {
    private var devices: [MTDeviceRef] = []
    private var tapDetector: TapDetector
    private var isEnabled = true
    private var activeTouch: Int32 = -1
    private var touchStartX: Float = 0.0
    private var touchStartY: Float = 0.0
    private var touchStartTime: CFAbsoluteTime = 0  // Use CFAbsoluteTime for better performance
    private var isDraggingActive = false  // Track if we're in drag mode
    private var isCancelled = false  // 当前触摸是否已取消（用于防止取消后的误触）
    private var lastCursorLocation: CGPoint = .zero  // Cache cursor location
    private var touchStartCursorLocation: CGPoint = .zero

    // Scroll-intent tracking. Displacement from the touch-start point can be
    // fooled by a finger that slides out and back (an aborted scroll or an
    // unconscious rub), so we additionally accumulate the total surface path
    // and watch the reported finger velocity — both are strong scroll signals
    // that a genuine tap never produces.
    private var lastSurfaceX: Float = 0.0
    private var lastSurfaceY: Float = 0.0
    private var surfacePathLength: Float = 0.0

    // Configuration-driven thresholds
    private var rightClickThreshold: Float      // X > threshold = right side
    private var surfaceMovementThreshold: Float // 表面移动阈值（用于检测滚动意图）
    private var surfacePathThreshold: Float     // 累积路程阈值（归一化，超出即判定为滑动）
    private var scrollVelocityThreshold: Float  // 表面速度阈值（归一化单位/秒，超出即判定为滚动）
    private var quickTouchTimeThreshold: TimeInterval // 快速触控时间阈值

    // Singleton access guarded by a lock: the C touch callback fires on an
    // arbitrary framework thread while init/deinit run on the main thread.
    private final class SharedStorage: @unchecked Sendable {
        let lock = NSLock()
        var instance: MultitouchManager?
    }

    private static let sharedStorage = SharedStorage()
    fileprivate static var sharedInstance: MultitouchManager? {
        sharedStorage.lock.lock()
        defer { sharedStorage.lock.unlock() }
        return sharedStorage.instance
    }
    fileprivate static func setSharedInstance(_ manager: MultitouchManager?) {
        sharedStorage.lock.lock()
        defer { sharedStorage.lock.unlock() }
        sharedStorage.instance = manager
    }
    fileprivate static func clearSharedInstanceIfMatching(_ candidate: MultitouchManager) {
        sharedStorage.lock.lock()
        defer { sharedStorage.lock.unlock() }
        if sharedStorage.instance === candidate {
            sharedStorage.instance = nil
        }
    }

    private let touchQueue = DispatchQueue(label: "com.magictapper.multitouch")
    private let touchQueueKey = DispatchSpecificKey<Void>()

    // Guards the critical section where the framework callback copies touch data
    // out of the (transient) C pointer. stop() takes the same lock while
    // unregistering/releasing devices, so an in-flight callback can never read
    // a dangling pointer.
    fileprivate let callbackLock = NSLock()
    fileprivate var isStopped = false

    var onClickSynthesized: ((CGPoint, Bool, Int) -> Void)?
    var onDragStarted: ((CGPoint) -> Void)?
    var onDragMoved: ((CGPoint) -> Void)?
    var onDragEnded: ((CGPoint) -> Void)?

    @MainActor
    init() {
        // Load configuration
        let config = ConfigurationManager.shared.current

        // Initialize TapDetector with configuration
        self.tapDetector = TapDetector(configuration: config)

        // Set MultitouchManager-specific thresholds
        self.rightClickThreshold = config.rightClickAreaThreshold
        self.surfaceMovementThreshold = config.surfaceMovementThreshold
        self.surfacePathThreshold = config.surfacePathThreshold
        self.scrollVelocityThreshold = config.scrollVelocityThreshold
        self.quickTouchTimeThreshold = config.quickTouchTimeThreshold

        MultitouchManager.setSharedInstance(self)
        touchQueue.setSpecific(key: touchQueueKey, value: ())

        // Listen for configuration changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(configurationDidChange),
            name: ConfigurationManager.configurationDidChangeNotification,
            object: nil
        )
    }

    @objc private func configurationDidChange(_ notification: Notification) {
        guard let config = notification.userInfo?["configuration"] as? TapConfiguration else { return }

        performOnTouchQueue {
            // Update TapDetector
            tapDetector.updateConfiguration(config)

            // Update MultitouchManager thresholds
            rightClickThreshold = config.rightClickAreaThreshold
            surfaceMovementThreshold = config.surfaceMovementThreshold
            surfacePathThreshold = config.surfacePathThreshold
            scrollVelocityThreshold = config.scrollVelocityThreshold
            quickTouchTimeThreshold = config.quickTouchTimeThreshold
        }

        #if DEBUG
        print("🔧 MultitouchManager: Configuration updated")
        #endif
    }

    @discardableResult
    func start() -> Int {
        return performOnTouchQueue {
            startOnTouchQueue()
        }
    }

    private func startOnTouchQueue() -> Int {
        callbackLock.lock()
        defer { callbackLock.unlock() }

        guard devices.isEmpty else {
            return devices.count
        }

        guard let deviceList = MTDeviceCreateList() else {
            return 0
        }

        let deviceArray = deviceList.takeRetainedValue() as NSArray
        let count = CFArrayGetCount(deviceArray)

        isStopped = false

        for i in 0..<count {
            let device = unsafeBitCast(CFArrayGetValueAtIndex(deviceArray, i), to: MTDeviceRef.self)

            if isSupportedMagicMouse(device) {
                // CFArrayGetValueAtIndex returns a *borrowed* reference whose
                // only owner is `deviceArray`, which is released the moment this
                // function returns. We hold these devices for the lifetime of the
                // manager, so we must take our own +1 retain — otherwise the
                // framework can free the device (e.g. when the Magic Mouse
                // disconnects on sleep) while we still point at it, and the next
                // MTDeviceStop/MTDeviceRelease crashes (use-after-free / over-release).
                // Balanced by MTDeviceRelease in stop(). MTDeviceRef is a CFType
                // (its release path is CFRelease), so CFRetain is the correct +1.
                _ = Unmanaged<AnyObject>.fromOpaque(device).retain()
                devices.append(device)
                MTRegisterContactFrameCallback(device, touchCallback)
                MTDeviceStart(device, 0)
            }
        }

        NSLog("MagicTapper registered %d supported Magic Mouse device(s)", devices.count)

        return devices.count
    }

    func stop() {
        performOnTouchQueue {
            callbackLock.lock()
            defer { callbackLock.unlock() }

            // Mark stopped first so any in-flight callback bails out before
            // touching the (soon-to-be-released) device pointer.
            isStopped = true
            cancelActiveGestureOnTouchQueue()

            for device in devices {
                MTUnregisterContactFrameCallback(device, touchCallback)
                MTDeviceStop(device)
                MTDeviceRelease(device)
            }
            devices.removeAll()

        }
    }

    func setEnabled(_ enabled: Bool) {
        performOnTouchQueue {
            if isEnabled && !enabled {
                cancelActiveGestureOnTouchQueue()
            }
            isEnabled = enabled
        }
    }

    /// Returns the current number of registered devices
    func getDeviceCount() -> Int {
        return performOnTouchQueue {
            devices.count
        }
    }

    /// Check if devices are still valid and responding
    func validateDevices() -> Bool {
        return performOnTouchQueue {
            validateDevicesOnTouchQueue()
        }
    }

    private func validateDevicesOnTouchQueue() -> Bool {
        guard !devices.isEmpty else { return false }

        // Try to get fresh device list and compare
        guard let deviceList = MTDeviceCreateList() else { return false }

        let deviceArray = deviceList.takeRetainedValue() as NSArray
        let count = CFArrayGetCount(deviceArray)

        var currentDeviceIDs = Set<UInt64>()
        for i in 0..<count {
            let device = unsafeBitCast(CFArrayGetValueAtIndex(deviceArray, i), to: MTDeviceRef.self)
            if isSupportedMagicMouse(device), let deviceID = stableDeviceID(for: device) {
                currentDeviceIDs.insert(deviceID)
            }
        }

        let registeredDeviceIDs = Set(devices.compactMap { stableDeviceID(for: $0) })
        return registeredDeviceIDs.count == devices.count &&
               !registeredDeviceIDs.isEmpty &&
               registeredDeviceIDs == currentDeviceIDs
    }

    /// Called from the MultitouchSupport callback thread.
    /// The touches pointer is only valid for the duration of the callback, so
    /// the caller must have already copied it into `touches`. We dispatch
    /// async to `touchQueue` so the framework thread is never blocked.
    func enqueueTouches(_ touches: [MTTouch], timestamp: Double) {
        touchQueue.async { [weak self] in
            self?.processTouchesOnTouchQueue(touches, numTouches: touches.count, timestamp: timestamp)
        }
    }

    private func processTouchesOnTouchQueue(_ touches: [MTTouch], numTouches: Int, timestamp: Double) {
        guard isEnabled else { return }

        // Only fetch cursor position when needed (touch start, end, or drag)
        // For touch move without drag, we can skip this expensive call
        func getCursorLocation() -> CGPoint {
            if let event = CGEvent(source: nil) {
                lastCursorLocation = event.location
            }
            return lastCursorLocation
        }

        if numTouches == 0 {
            if activeTouch != -1 {
                // Touch ended - need cursor position
                let cgLocation = getCursorLocation()

                // 如果触摸已被取消（表面移动检测触发），不处理点击
                if !isCancelled {
                    let isRightSide = touchStartX > rightClickThreshold
                    let result = tapDetector.touchEnded(at: cgLocation, isRightSide: isRightSide)

                    // Handle click
                    if result.shouldClick, let clickLocation = result.clickLocation {
                        onClickSynthesized?(clickLocation, result.isRightClick, result.clickCount)
                    }

                    // Handle drag end
                    if isDraggingActive {
                        onDragEnded?(cgLocation)
                        isDraggingActive = false
                    }
                } else {
                    #if DEBUG
                    print("🚫 Touch ended but was cancelled - no click")
                    #endif
                    // 如果已取消且在拖拽，也要结束拖拽
                    if isDraggingActive {
                        onDragEnded?(cgLocation)
                        isDraggingActive = false
                    }
                }

                activeTouch = -1
                touchStartX = 0.0
                touchStartY = 0.0
                touchStartTime = 0
                touchStartCursorLocation = .zero
                isCancelled = false
                resetSurfaceTrackingOnTouchQueue()
            }
            return
        }

        if numTouches == 1 {
            let touch = touches[0]

            if touch.state == 4 || touch.state == 7 {
                if activeTouch == -1 {
                    // New touch started - need cursor position
                    let cgLocation = getCursorLocation()

                    activeTouch = touch.identifier
                    touchStartX = touch.normalized.position.x
                    touchStartY = touch.normalized.position.y
                    touchStartTime = CFAbsoluteTimeGetCurrent()
                    touchStartCursorLocation = cgLocation
                    isCancelled = false
                    lastSurfaceX = touchStartX
                    lastSurfaceY = touchStartY
                    surfacePathLength = 0.0

                    let isRightSide = touchStartX > rightClickThreshold
                    _ = tapDetector.touchBegan(at: cgLocation, isRightSide: isRightSide)

                } else if activeTouch == touch.identifier {
                    // Same touch continuing

                    // 仅在非拖拽状态下检查表面移动（拖拽时手指滑动是正常的）
                    if !isDraggingActive {
                        let positionX = touch.normalized.position.x
                        let positionY = touch.normalized.position.y

                        // 累积路程 + 速度：滚动意图的两个硬信号。
                        // 位移检测可以被"滑出去又滑回来"绕过，路程和速度不会。
                        surfacePathLength += hypotf(positionX - lastSurfaceX, positionY - lastSurfaceY)
                        lastSurfaceX = positionX
                        lastSurfaceY = positionY
                        let surfaceSpeed = hypotf(touch.normalized.velocity.x, touch.normalized.velocity.y)

                        if surfaceSpeed > scrollVelocityThreshold {
                            #if DEBUG
                            print("🚫 Scroll velocity detected: \(String(format: "%.3f", surfaceSpeed)) > \(String(format: "%.3f", scrollVelocityThreshold))")
                            #endif
                            cancelActiveTouchAsScrollOnTouchQueue()
                            return
                        }

                        if surfacePathLength > surfacePathThreshold {
                            #if DEBUG
                            print("🚫 Surface path exceeded: \(String(format: "%.3f", surfacePathLength)) > \(String(format: "%.3f", surfacePathThreshold))")
                            #endif
                            cancelActiveTouchAsScrollOnTouchQueue()
                            return
                        }

                        let deltaX = abs(positionX - touchStartX)
                        let deltaY = abs(positionY - touchStartY)
                        let surfaceMovement = max(deltaX, deltaY)

                        // 智能表面移动检测：
                        // - 快速触控（<0.15s）：允许更大的表面移动（防止快速点击被误判）
                        // - 慢速触控：严格检测表面移动（防止滚动误触）
                        let touchDuration = CFAbsoluteTimeGetCurrent() - touchStartTime
                        let isQuickTouch = touchDuration < quickTouchTimeThreshold
                        let effectiveThreshold = isQuickTouch ? surfaceMovementThreshold * 2.0 : surfaceMovementThreshold

                        if surfaceMovement > effectiveThreshold {
                            // Finger moved too much on surface - likely scrolling, cancel tap
                            #if DEBUG
                            print("🚫 Surface movement detected: \(String(format: "%.3f", surfaceMovement)) > \(String(format: "%.3f", effectiveThreshold)) (quick: \(isQuickTouch))")
                            #endif
                            cancelActiveTouchAsScrollOnTouchQueue()
                            return
                        }

                        // Cursor displacement is part of tap validation. Passing the
                        // cached start location here would make the movement threshold
                        // ineffective until the touch ends.
                        let cgLocation = getCursorLocation()
                        let result = tapDetector.touchMoved(to: cgLocation)

                        // A second tap becomes a drag only after cursor movement
                        // crosses the tap movement threshold.
                        if result.isDragging {
                            isDraggingActive = true
                            onDragStarted?(touchStartCursorLocation)
                            if let dragLocation = result.dragLocation {
                                onDragMoved?(dragLocation)
                            }
                        }
                    } else {
                        // Dragging - need fresh cursor position
                        let cgLocation = getCursorLocation()
                        let result = tapDetector.touchMoved(to: cgLocation)

                        // Handle drag movement
                        if result.isDragging, let dragLocation = result.dragLocation {
                            onDragMoved?(dragLocation)
                        }
                    }
                }
            }
        } else if numTouches > 1 {
            // Multiple touches - cancel current gesture (no cursor needed)
            // Reset even when no single touch is active so a previous click cannot
            // survive a multi-touch gesture as a stale double-click candidate.
            tapDetector.reset()
            if activeTouch != -1 {
                if isDraggingActive {
                    let cgLocation = getCursorLocation()
                    onDragEnded?(cgLocation)
                    isDraggingActive = false
                }
                activeTouch = -1
                touchStartX = 0.0
                touchStartY = 0.0
                touchStartTime = 0
                touchStartCursorLocation = .zero
                isCancelled = false
                resetSurfaceTrackingOnTouchQueue()
            }
        }
    }

    private func isSupportedMagicMouse(_ device: MTDeviceRef) -> Bool {
        let descriptor = deviceDescriptor(for: device)
        let isSupported = MultitouchDeviceClassifier.isMagicMouse(descriptor)

        #if DEBUG
        print("🖱️ Multitouch device: builtIn=\(descriptor.isBuiltIn), opaque=\(descriptor.isOpaqueSurface), product=\(descriptor.productName ?? "unknown"), preferenceKeys=\(descriptor.preferenceKeys.sorted()), supported=\(isSupported)")
        #endif

        return isSupported
    }

    private func deviceDescriptor(for device: MTDeviceRef) -> MultitouchDeviceDescriptor {
        let isBuiltIn = MTDeviceIsBuiltIn(device)
        let isOpaqueSurface = MTDeviceIsOpaqueSurface(device)
        let service = MTDeviceGetService(device)

        guard service != IO_OBJECT_NULL else {
            return MultitouchDeviceDescriptor(
                isBuiltIn: isBuiltIn,
                isOpaqueSurface: isOpaqueSurface,
                preferenceKeys: [],
                productName: nil
            )
        }

        var unmanagedProperties: Unmanaged<CFMutableDictionary>?
        let result = IORegistryEntryCreateCFProperties(
            service,
            &unmanagedProperties,
            kCFAllocatorDefault,
            0
        )

        guard result == KERN_SUCCESS,
              let properties = unmanagedProperties?.takeRetainedValue() as? [String: Any] else {
            return MultitouchDeviceDescriptor(
                isBuiltIn: isBuiltIn,
                isOpaqueSurface: isOpaqueSurface,
                preferenceKeys: [],
                productName: nil
            )
        }

        let preferences = properties["MultitouchPreferences"] as? [String: Any]
        return MultitouchDeviceDescriptor(
            isBuiltIn: isBuiltIn,
            isOpaqueSurface: isOpaqueSurface,
            preferenceKeys: Set(preferences?.keys.map { $0 } ?? []),
            productName: properties["Product"] as? String
        )
    }

    private func stableDeviceID(for device: MTDeviceRef) -> UInt64? {
        var deviceID: UInt64 = 0
        return MTDeviceGetDeviceID(device, &deviceID) == 0 ? deviceID : nil
    }

    private func cancelActiveGestureOnTouchQueue() {
        if isDraggingActive {
            let location: CGPoint
            if let event = CGEvent(source: nil) {
                lastCursorLocation = event.location
                location = event.location
            } else {
                location = lastCursorLocation
            }
            onDragEnded?(location)
        }

        tapDetector.reset()
        activeTouch = -1
        touchStartX = 0.0
        touchStartY = 0.0
        touchStartTime = 0
        touchStartCursorLocation = .zero
        isCancelled = false
        isDraggingActive = false
        resetSurfaceTrackingOnTouchQueue()
    }

    /// Marks the in-flight touch as a scroll/slide so lifting the finger
    /// cannot synthesize a click. The touch itself keeps being tracked so the
    /// same finger cannot restart a gesture mid-contact.
    private func cancelActiveTouchAsScrollOnTouchQueue() {
        tapDetector.reset()
        isCancelled = true
    }

    private func resetSurfaceTrackingOnTouchQueue() {
        lastSurfaceX = 0.0
        lastSurfaceY = 0.0
        surfacePathLength = 0.0
    }

    deinit {
        stop()
        NotificationCenter.default.removeObserver(self)
        MultitouchManager.clearSharedInstanceIfMatching(self)
    }

    private func performOnTouchQueue<T>(_ work: () -> T) -> T {
        if DispatchQueue.getSpecific(key: touchQueueKey) != nil {
            return work()
        }

        return touchQueue.sync(execute: work)
    }
}

private func touchCallback(device: Int32, touches: UnsafeMutablePointer<MTTouch>?, numTouches: Int32, timestamp: Double, frame: Int32) -> Int32 {
    guard let manager = MultitouchManager.sharedInstance, let touches = touches else {
        return 0
    }

    // Copy the touch data out of the transient C pointer under the manager's
    // callback lock. stop() takes the same lock while releasing devices, so
    // either we copy before stop() releases (safe) or we observe isStopped and
    // bail out without dereferencing the pointer (safe).
    let count = Int(numTouches)
    let buffer: [MTTouch]
    manager.callbackLock.lock()
    if manager.isStopped {
        manager.callbackLock.unlock()
        return 0
    }
    buffer = count > 0 ? Array(UnsafeBufferPointer(start: touches, count: count)) : []
    manager.callbackLock.unlock()

    manager.enqueueTouches(buffer, timestamp: timestamp)
    return 0
}
