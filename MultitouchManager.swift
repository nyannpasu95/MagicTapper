import Foundation
import CoreGraphics
import AppKit

// Swift wrapper for Multitouch framework
class MultitouchManager {
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

    // Configuration-driven thresholds
    private var rightClickThreshold: Float      // X > threshold = right side
    private var surfaceMovementThreshold: Float // 表面移动阈值（用于检测滚动意图）
    private var quickTouchTimeThreshold: TimeInterval // 快速触控时间阈值

    // Singleton access guarded by a lock: the C touch callback fires on an
    // arbitrary framework thread while init/deinit run on the main thread.
    private static let sharedInstanceLock = NSLock()
    private static var _sharedInstance: MultitouchManager?
    fileprivate static var sharedInstance: MultitouchManager? {
        sharedInstanceLock.lock()
        defer { sharedInstanceLock.unlock() }
        return _sharedInstance
    }
    fileprivate static func setSharedInstance(_ manager: MultitouchManager?) {
        sharedInstanceLock.lock()
        defer { sharedInstanceLock.unlock() }
        _sharedInstance = manager
    }
    fileprivate static func clearSharedInstanceIfMatching(_ candidate: MultitouchManager) {
        sharedInstanceLock.lock()
        defer { sharedInstanceLock.unlock() }
        if _sharedInstance === candidate {
            _sharedInstance = nil
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

    var onClickSynthesized: ((CGPoint, Bool) -> Void)?
    var onDragStarted: ((CGPoint) -> Void)?
    var onDragMoved: ((CGPoint) -> Void)?
    var onDragEnded: ((CGPoint) -> Void)?

    init() {
        // Load configuration
        let config = ConfigurationManager.shared.current

        // Initialize TapDetector with configuration
        self.tapDetector = TapDetector(configuration: config)

        // Set MultitouchManager-specific thresholds
        self.rightClickThreshold = config.rightClickAreaThreshold
        self.surfaceMovementThreshold = config.surfaceMovementThreshold
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

            // Only monitor external devices (Magic Mouse), skip built-in trackpads
            let isBuiltIn = MTDeviceIsBuiltIn(device)

            if !isBuiltIn {
                devices.append(device)
                MTRegisterContactFrameCallback(device, touchCallback)
                MTDeviceStart(device, 0)
            }
        }

        return devices.count
    }

    func stop() {
        performOnTouchQueue {
            callbackLock.lock()
            defer { callbackLock.unlock() }

            // Mark stopped first so any in-flight callback bails out before
            // touching the (soon-to-be-released) device pointer.
            isStopped = true

            for device in devices {
                MTUnregisterContactFrameCallback(device, touchCallback)
                MTDeviceStop(device)
                MTDeviceRelease(device)
            }
            devices.removeAll()

            // Reset transient gesture state so a stale touch can't carry over
            // into the next start cycle after a restart.
            activeTouch = -1
            touchStartX = 0.0
            touchStartY = 0.0
            touchStartTime = 0
            isCancelled = false
            isDraggingActive = false
        }
    }

    func setEnabled(_ enabled: Bool) {
        performOnTouchQueue {
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

        var externalDeviceCount = 0
        for i in 0..<count {
            let device = unsafeBitCast(CFArrayGetValueAtIndex(deviceArray, i), to: MTDeviceRef.self)
            if !MTDeviceIsBuiltIn(device) {
                externalDeviceCount += 1
            }
        }

        return externalDeviceCount > 0 && devices.count > 0
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
                        onClickSynthesized?(clickLocation, result.isRightClick)
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
                isCancelled = false
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
                    isCancelled = false

                    let isRightSide = touchStartX > rightClickThreshold
                    let result = tapDetector.touchBegan(at: cgLocation, isRightSide: isRightSide)

                    // Check if entering drag mode
                    if result.isDragging {
                        isDraggingActive = true
                        onDragStarted?(cgLocation)
                    }

                } else if activeTouch == touch.identifier {
                    // Same touch continuing

                    // 仅在非拖拽状态下检查表面移动（拖拽时手指滑动是正常的）
                    if !isDraggingActive {
                        let deltaX = abs(touch.normalized.position.x - touchStartX)
                        let deltaY = abs(touch.normalized.position.y - touchStartY)
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
                            tapDetector.reset()
                            isCancelled = true  // 标记为已取消，防止抬起时触发点击
                            return
                        }

                        // For non-drag touch move, use cached location to avoid CGEvent creation
                        let result = tapDetector.touchMoved(to: lastCursorLocation)
                        // No action needed for non-drag moves
                        _ = result
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
            if activeTouch != -1 {
                tapDetector.reset()
                if isDraggingActive {
                    let cgLocation = getCursorLocation()
                    onDragEnded?(cgLocation)
                    isDraggingActive = false
                }
                activeTouch = -1
                touchStartX = 0.0
                touchStartY = 0.0
                touchStartTime = 0
                isCancelled = false
            }
        }
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
