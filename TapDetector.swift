import Foundation
import CoreGraphics

/// Mouse gesture state machine
enum MouseState: Equatable {
    case idle                    // 空闲状态
    case touching                // 接触中（单击）
    case dragging                // 拖拽中
    case waitingForDoubleTap     // 等待双击
}

/// Result of processing a touch event
struct TouchProcessResult {
    let shouldClick: Bool           // 是否应该触发点击
    let clickLocation: CGPoint?     // 点击位置
    let isRightClick: Bool          // 是否为右键点击
    let isDragging: Bool            // 是否处于拖拽状态
    let dragLocation: CGPoint?      // 拖拽位置（用于移动光标）
}

/// Handles advanced gesture detection with state machine - separated for testability
class TapDetector {
    // Thresholds (can be updated via updateConfiguration)
    private(set) var tapTimeThreshold: TimeInterval          // 最大点击时长
    private(set) var tapMovementThreshold: CGFloat           // 最大点击移动距离（光标）
    private(set) var rightClickTimeThreshold: TimeInterval   // 右键最小按住时长
    private(set) var doubleTapTimeWindow: TimeInterval       // 双击时间窗口
    private(set) var minTapDuration: TimeInterval            // 最小点击时长（防误触）
    private(set) var dragThreshold: CGFloat                  // 拖拽抖动阈值
    private(set) var quickTapThreshold: TimeInterval         // 快速点击时间阈值

    // State
    private var currentState: MouseState = .idle
    private var touchStartTime: Date?
    private var touchStartLocation: CGPoint?
    private var lastClickTime: Date?
    private var lastClickLocation: CGPoint?
    private var dragStartLocation: CGPoint?
    private var previousLocation: CGPoint?
    private var hasMovedSignificantly: Bool = false  // 是否有明显移动（用于区分点击和滚动）
    private let nowProvider: () -> Date

    /// Initialize with explicit values (for testing)
    init(
        tapTimeThreshold: TimeInterval = 0.3,
        tapMovementThreshold: CGFloat = 5.0,
        rightClickTimeThreshold: TimeInterval = 0.1,
        doubleTapTimeWindow: TimeInterval = 0.3,
        dragThreshold: CGFloat = 2.0,
        minTapDuration: TimeInterval = 0.03,
        quickTapThreshold: TimeInterval = 0.15,
        nowProvider: @escaping () -> Date = Date.init
    ) {
        self.tapTimeThreshold = tapTimeThreshold
        self.tapMovementThreshold = tapMovementThreshold
        self.rightClickTimeThreshold = rightClickTimeThreshold
        self.doubleTapTimeWindow = doubleTapTimeWindow
        self.minTapDuration = minTapDuration
        self.dragThreshold = dragThreshold
        self.quickTapThreshold = quickTapThreshold
        self.nowProvider = nowProvider
    }

    /// Initialize from TapConfiguration
    convenience init(configuration: TapConfiguration) {
        self.init(
            tapTimeThreshold: configuration.tapTimeThreshold,
            tapMovementThreshold: configuration.tapMovementThreshold,
            rightClickTimeThreshold: configuration.rightClickTimeThreshold,
            doubleTapTimeWindow: configuration.doubleTapTimeWindow,
            dragThreshold: configuration.dragThreshold,
            minTapDuration: configuration.minTapDuration,
            quickTapThreshold: configuration.quickTapThreshold
        )
    }

    /// Update thresholds from configuration (called when config changes)
    func updateConfiguration(_ config: TapConfiguration) {
        tapTimeThreshold = config.tapTimeThreshold
        tapMovementThreshold = config.tapMovementThreshold
        rightClickTimeThreshold = config.rightClickTimeThreshold
        doubleTapTimeWindow = config.doubleTapTimeWindow
        minTapDuration = config.minTapDuration
        dragThreshold = config.dragThreshold
        quickTapThreshold = config.quickTapThreshold
    }

    /// Process touch began event
    func touchBegan(at location: CGPoint, isRightSide: Bool) -> TouchProcessResult {
        let now = nowProvider()

        // 检查是否在双击时间窗口内
        if let lastTime = lastClickTime,
           now.timeIntervalSince(lastTime) < doubleTapTimeWindow,
           currentState == .idle {
            // 进入拖拽模式
            currentState = .dragging
            touchStartTime = now
            touchStartLocation = location
            dragStartLocation = location
            previousLocation = location

            return TouchProcessResult(
                shouldClick: false,
                clickLocation: nil,
                isRightClick: false,
                isDragging: true,
                dragLocation: location
            )
        }

        // 正常触摸开始
        currentState = .touching
        touchStartTime = now
        touchStartLocation = location
        previousLocation = location
        hasMovedSignificantly = false

        return TouchProcessResult(
            shouldClick: false,
            clickLocation: nil,
            isRightClick: false,
            isDragging: false,
            dragLocation: nil
        )
    }

    /// Process touch moved event
    func touchMoved(to location: CGPoint) -> TouchProcessResult {
        guard let startLocation = touchStartLocation else {
            return TouchProcessResult(
                shouldClick: false,
                clickLocation: nil,
                isRightClick: false,
                isDragging: false,
                dragLocation: nil
            )
        }

        previousLocation = location

        switch currentState {
        case .touching:
            // 使用直线距离检测是否有明显移动
            let distance = hypot(location.x - startLocation.x, location.y - startLocation.y)

            // 标记是否有明显移动（用于后续判断）
            if distance > tapMovementThreshold {
                hasMovedSignificantly = true
                #if DEBUG
                print("📍 Significant movement detected: \(String(format: "%.2f", distance)) px")
                #endif
            }

        case .dragging:
            // 在拖拽状态下，使用更小的防抖阈值，并且总是返回拖拽状态
            if let dragStart = dragStartLocation {
                let dragDistance = hypot(location.x - dragStart.x, location.y - dragStart.y)
                if dragDistance > dragThreshold {
                    // 超过阈值，更新拖拽起点，返回拖拽位置
                    dragStartLocation = location
                    return TouchProcessResult(
                        shouldClick: false,
                        clickLocation: nil,
                        isRightClick: false,
                        isDragging: true,
                        dragLocation: location
                    )
                } else {
                    // 即使在阈值内，也保持拖拽状态（防止中断）
                    return TouchProcessResult(
                        shouldClick: false,
                        clickLocation: nil,
                        isRightClick: false,
                        isDragging: true,
                        dragLocation: nil  // 小幅移动不更新位置，但保持拖拽状态
                    )
                }
            }

        default:
            break
        }

        return TouchProcessResult(
            shouldClick: false,
            clickLocation: nil,
            isRightClick: false,
            isDragging: currentState == .dragging,
            dragLocation: nil
        )
    }

    /// Process touch ended event
    func touchEnded(at location: CGPoint, isRightSide: Bool) -> TouchProcessResult {
        guard let startTime = touchStartTime,
              let startLocation = touchStartLocation else {
            reset()
            return TouchProcessResult(
                shouldClick: false,
                clickLocation: nil,
                isRightClick: false,
                isDragging: false,
                dragLocation: nil
            )
        }

        let now = nowProvider()
        let duration = now.timeIntervalSince(startTime)
        let distance = hypot(location.x - startLocation.x, location.y - startLocation.y)

        var result = TouchProcessResult(
            shouldClick: false,
            clickLocation: nil,
            isRightClick: false,
            isDragging: false,
            dragLocation: nil
        )

        switch currentState {
        case .touching:
            // 智能点击检测：区分快速点击和滚动
            #if DEBUG
            print("✋ Touch ended. Dist: \(String(format: "%.2f", distance)), Dur: \(String(format: "%.3f", duration)), Moved: \(hasMovedSignificantly)")
            #endif

            // 智能判定逻辑：
            // 1. 快速点击（<0.15s）：即使有轻微移动也算点击（防止手抖影响）
            // 2. 慢速触控：必须移动距离小才算点击（防止滚动误触）
            let isQuickTap = duration < quickTapThreshold
            let isValidTap = (isQuickTap || !hasMovedSignificantly) &&
                             duration < tapTimeThreshold &&
                             duration > minTapDuration

            if isValidTap {
                // 右键检测：按住时间较长且在右侧
                if duration >= rightClickTimeThreshold && isRightSide {
                    #if DEBUG
                    print("✅ Right Click Triggered")
                    #endif
                    result = TouchProcessResult(
                        shouldClick: true,
                        clickLocation: location,
                        isRightClick: true,
                        isDragging: false,
                        dragLocation: nil
                    )
                } else {
                    // 普通左键点击（快速点击或左侧点击）
                    #if DEBUG
                    print("✅ Left Click Triggered")
                    #endif
                    result = TouchProcessResult(
                        shouldClick: true,
                        clickLocation: location,
                        isRightClick: false,
                        isDragging: false,
                        dragLocation: nil
                    )

                    // 记录点击时间和位置，用于双击检测
                    lastClickTime = now
                    lastClickLocation = location
                }
            } else {
                #if DEBUG
                print("⚠️ Tap ignored. Too far, too long, or moving fast.")
                #endif
            }

        case .dragging:
            // 拖拽结束
            result = TouchProcessResult(
                shouldClick: false,
                clickLocation: nil,
                isRightClick: false,
                isDragging: false,
                dragLocation: nil
            )

        default:
            break
        }

        reset()
        return result
    }

    /// Resets tap detection state
    func reset() {
        currentState = .idle
        touchStartTime = nil
        touchStartLocation = nil
        dragStartLocation = nil
        previousLocation = nil
        hasMovedSignificantly = false
    }

    /// Returns current mouse state
    var state: MouseState {
        return currentState
    }

    /// Returns true if a touch is currently being tracked
    var isTracking: Bool {
        return currentState != .idle
    }

    /// Returns true if currently dragging
    var isDragging: Bool {
        return currentState == .dragging
    }
}
