import Foundation
import CoreGraphics

/// Configuration for tap detection and gesture recognition
/// All values can be persisted via UserDefaults through ConfigurationManager
struct TapConfiguration: Codable, Equatable {

    // MARK: - TapDetector Parameters

    /// Maximum duration for a tap to be recognized as a click (seconds)
    var tapTimeThreshold: TimeInterval

    /// Maximum cursor movement allowed during a tap (pixels)
    var tapMovementThreshold: CGFloat

    /// Minimum hold duration to trigger right-click (seconds)
    var rightClickTimeThreshold: TimeInterval

    /// Time window for double-tap detection (seconds)
    var doubleTapTimeWindow: TimeInterval

    /// Minimum tap duration to filter out noise (seconds)
    var minTapDuration: TimeInterval

    /// Movement threshold for drag debouncing (pixels)
    var dragThreshold: CGFloat

    /// Time threshold for quick tap detection (seconds)
    var quickTapThreshold: TimeInterval

    // MARK: - MultitouchManager Parameters

    /// X position threshold for right-click area (0.0-1.0, normalized)
    var rightClickAreaThreshold: Float

    /// Surface movement threshold to cancel tap (0.0-1.0, normalized)
    var surfaceMovementThreshold: Float

    /// Time threshold for quick touch detection (seconds)
    var quickTouchTimeThreshold: TimeInterval

    // MARK: - Default Configuration

    /// Default configuration with optimized values
    static let `default` = TapConfiguration(
        // TapDetector defaults (current optimized values)
        tapTimeThreshold: 0.35,
        tapMovementThreshold: 8.0,
        rightClickTimeThreshold: 0.1,
        doubleTapTimeWindow: 0.3,
        minTapDuration: 0.03,
        dragThreshold: 2.0,
        quickTapThreshold: 0.15,
        // MultitouchManager defaults
        rightClickAreaThreshold: 0.6,
        surfaceMovementThreshold: 0.04,
        quickTouchTimeThreshold: 0.15
    )

    // MARK: - Initialization

    init(
        tapTimeThreshold: TimeInterval = 0.35,
        tapMovementThreshold: CGFloat = 8.0,
        rightClickTimeThreshold: TimeInterval = 0.1,
        doubleTapTimeWindow: TimeInterval = 0.3,
        minTapDuration: TimeInterval = 0.03,
        dragThreshold: CGFloat = 2.0,
        quickTapThreshold: TimeInterval = 0.15,
        rightClickAreaThreshold: Float = 0.6,
        surfaceMovementThreshold: Float = 0.04,
        quickTouchTimeThreshold: TimeInterval = 0.15
    ) {
        self.tapTimeThreshold = tapTimeThreshold
        self.tapMovementThreshold = tapMovementThreshold
        self.rightClickTimeThreshold = rightClickTimeThreshold
        self.doubleTapTimeWindow = doubleTapTimeWindow
        self.minTapDuration = minTapDuration
        self.dragThreshold = dragThreshold
        self.quickTapThreshold = quickTapThreshold
        self.rightClickAreaThreshold = rightClickAreaThreshold
        self.surfaceMovementThreshold = surfaceMovementThreshold
        self.quickTouchTimeThreshold = quickTouchTimeThreshold
    }
}

/// Manages tap configuration persistence and access
class ConfigurationManager {

    // MARK: - Singleton

    static let shared = ConfigurationManager()

    // MARK: - Constants

    private let userDefaultsKey = "com.magictapper.tapConfiguration"

    // MARK: - Properties

    /// Current configuration (cached for performance)
    private(set) var current: TapConfiguration

    /// Notification posted when configuration changes
    static let configurationDidChangeNotification = Notification.Name("ConfigurationDidChange")

    // MARK: - Initialization

    private init() {
        // Load saved configuration or use defaults
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let saved = try? JSONDecoder().decode(TapConfiguration.self, from: data) {
            self.current = saved
            #if DEBUG
            print("📋 Loaded saved configuration")
            #endif
        } else {
            self.current = .default
            #if DEBUG
            print("📋 Using default configuration")
            #endif
        }
    }

    // MARK: - Public Methods

    /// Updates the configuration and persists to UserDefaults
    func update(_ configuration: TapConfiguration) {
        guard configuration != current else { return }

        current = configuration
        save()

        // Post notification for observers
        NotificationCenter.default.post(
            name: Self.configurationDidChangeNotification,
            object: self,
            userInfo: ["configuration": configuration]
        )

        #if DEBUG
        print("📋 Configuration updated and saved")
        #endif
    }

    /// Updates a single value in the configuration
    func update<T>(_ keyPath: WritableKeyPath<TapConfiguration, T>, to value: T) {
        var newConfig = current
        newConfig[keyPath: keyPath] = value
        update(newConfig)
    }

    /// Resets configuration to default values
    func resetToDefaults() {
        update(.default)
        #if DEBUG
        print("📋 Configuration reset to defaults")
        #endif
    }

    /// Checks if current configuration differs from defaults
    var hasCustomConfiguration: Bool {
        return current != .default
    }

    // MARK: - Private Methods

    private func save() {
        if let data = try? JSONEncoder().encode(current) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }
}
