import Foundation
import IOKit
import IOKit.pwr_mgt

/// Manages multitouch device restart with retry logic and health monitoring
class MultitouchRestartManager {

    // MARK: - Types

    struct RetryConfig {
        let maxAttempts: Int
        let initialDelay: TimeInterval
        let maxDelay: TimeInterval
        let backoffMultiplier: Double

        static let `default` = RetryConfig(
            maxAttempts: Constants.Retry.maxAttempts,
            initialDelay: Constants.Retry.initialDelay,
            maxDelay: Constants.Retry.maxDelay,
            backoffMultiplier: Constants.Retry.backoffMultiplier
        )

        /// Calculate delay for a given attempt (exponential backoff with cap)
        func delay(forAttempt attempt: Int) -> TimeInterval {
            let delay = initialDelay * pow(backoffMultiplier, Double(attempt - 1))
            return min(delay, maxDelay)
        }
    }

    enum RestartReason: String {
        case systemWake = "system_wake"
        case bluetoothReconnect = "bluetooth_reconnect"
        case healthCheck = "health_check"
        case manual = "manual"
    }

    // MARK: - Properties

    private weak var appDelegate: AppDelegate?
    private var retryConfig: RetryConfig
    private var currentAttempt = 0
    private var isRestarting = false
    private var pendingRestartWorkItem: DispatchWorkItem?

    // Health check timer with adaptive interval
    private var healthCheckTimer: Timer?
    private var currentHealthCheckInterval: TimeInterval = Constants.HealthCheck.defaultInterval
    private var consecutiveSuccessfulChecks = 0

    // Track last successful device detection
    private var lastSuccessfulStart: Date?
    private var consecutiveFailures = 0

    // MARK: - Callbacks

    var onRestartCompleted: ((Bool, Int) -> Void)?  // (success, deviceCount)
    var onRestartFailed: ((Int) -> Void)?  // (attempts)

    // MARK: - Initialization

    init(appDelegate: AppDelegate, config: RetryConfig = .default) {
        self.appDelegate = appDelegate
        self.retryConfig = config
    }

    deinit {
        stopHealthCheck()
        cancelPendingRestart()
    }

    // MARK: - Public Methods

    /// Restart multitouch manager with retry logic
    func restart(reason: RestartReason, afterDelay initialDelay: TimeInterval = 0) {
        // Cancel any pending restart
        cancelPendingRestart()

        // Reset state for new restart sequence
        currentAttempt = 0
        isRestarting = true

        #if DEBUG
        print("🔄 MultitouchRestartManager: Starting restart sequence (reason: \(reason.rawValue))")
        #endif

        if initialDelay > 0 {
            let workItem = DispatchWorkItem { [weak self] in
                self?.performRestart(reason: reason)
            }
            pendingRestartWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + initialDelay, execute: workItem)
        } else {
            performRestart(reason: reason)
        }
    }

    /// Cancel any pending restart operation
    func cancelPendingRestart() {
        pendingRestartWorkItem?.cancel()
        pendingRestartWorkItem = nil
        isRestarting = false
        currentAttempt = 0
    }

    /// Start periodic health check with adaptive interval
    func startHealthCheck() {
        scheduleNextHealthCheck()

        #if DEBUG
        print("💓 Health check started (interval: \(currentHealthCheckInterval)s)")
        #endif
    }

    /// Stop periodic health check
    func stopHealthCheck() {
        healthCheckTimer?.invalidate()
        healthCheckTimer = nil
    }

    /// Reset health check interval to minimum (called after issues detected)
    func resetHealthCheckInterval() {
        currentHealthCheckInterval = Constants.HealthCheck.minInterval
        consecutiveSuccessfulChecks = 0

        // Reschedule with new interval if timer is running
        if healthCheckTimer != nil {
            scheduleNextHealthCheck()
            #if DEBUG
            print("💓 Health check interval reset to minimum: \(currentHealthCheckInterval)s")
            #endif
        }
    }

    private func scheduleNextHealthCheck() {
        healthCheckTimer?.invalidate()

        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: currentHealthCheckInterval, repeats: false) { [weak self] _ in
            self?.performHealthCheck()
        }
    }

    private func increaseHealthCheckIntervalIfStable() {
        consecutiveSuccessfulChecks += 1

        if consecutiveSuccessfulChecks >= Constants.HealthCheck.successThresholdForIncrease {
            let newInterval = min(
                currentHealthCheckInterval * Constants.HealthCheck.intervalIncreaseMultiplier,
                Constants.HealthCheck.maxInterval
            )

            if newInterval > currentHealthCheckInterval {
                currentHealthCheckInterval = newInterval
                consecutiveSuccessfulChecks = 0

                #if DEBUG
                print("💓 Health check interval increased to: \(currentHealthCheckInterval)s")
                #endif
            }
        }
    }

    /// Mark successful device start
    func markSuccessfulStart(deviceCount: Int) {
        lastSuccessfulStart = Date()
        consecutiveFailures = 0

        #if DEBUG
        print("✅ Marked successful start with \(deviceCount) device(s)")
        #endif
    }

    // MARK: - Private Methods

    private func performRestart(reason: RestartReason) {
        guard let appDelegate = appDelegate else {
            isRestarting = false
            return
        }

        currentAttempt += 1

        #if DEBUG
        print("🔄 Restart attempt \(currentAttempt)/\(retryConfig.maxAttempts) (reason: \(reason.rawValue))")
        #endif

        // Stop existing manager
        appDelegate.multitouchManager?.stop()

        // Create new manager and setup callbacks
        appDelegate.multitouchManager = MultitouchManager()
        appDelegate.setupMultitouchCallbacks()

        // Try to start
        let deviceCount = appDelegate.multitouchManager?.start() ?? 0

        if deviceCount > 0 {
            // Success
            isRestarting = false
            markSuccessfulStart(deviceCount: deviceCount)
            onRestartCompleted?(true, deviceCount)

            #if DEBUG
            print("✅ Restart successful - found \(deviceCount) device(s)")
            #endif
        } else {
            // Failed - retry if attempts remaining
            consecutiveFailures += 1

            if currentAttempt < retryConfig.maxAttempts {
                let delay = retryConfig.delay(forAttempt: currentAttempt)

                #if DEBUG
                print("⚠️ No devices found, retrying in \(String(format: "%.1f", delay))s...")
                #endif

                let workItem = DispatchWorkItem { [weak self] in
                    guard let self = self, self.isRestarting else { return }
                    self.performRestart(reason: reason)
                }
                pendingRestartWorkItem = workItem
                DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
            } else {
                // All attempts exhausted
                isRestarting = false
                onRestartFailed?(currentAttempt)

                #if DEBUG
                print("❌ Restart failed after \(currentAttempt) attempts")
                #endif
            }
        }
    }

    private func performHealthCheck() {
        guard let appDelegate = appDelegate,
              appDelegate.isEnabled else {
            // Still schedule next check even if disabled
            scheduleNextHealthCheck()
            return
        }

        // Check if multitouch manager exists and has devices
        guard let manager = appDelegate.multitouchManager else {
            #if DEBUG
            print("💓 Health check: No manager, triggering restart")
            #endif
            resetHealthCheckInterval()
            restart(reason: .healthCheck)
            return
        }

        let deviceCount = manager.getDeviceCount()

        if deviceCount == 0 {
            #if DEBUG
            print("💓 Health check: No devices detected, triggering restart")
            #endif
            resetHealthCheckInterval()
            restart(reason: .healthCheck, afterDelay: Constants.Timing.accessibilityCheckInterval)
        } else {
            #if DEBUG
            print("💓 Health check: OK (\(deviceCount) device(s)) - next check in \(currentHealthCheckInterval)s")
            #endif
            increaseHealthCheckIntervalIfStable()
            scheduleNextHealthCheck()
        }
    }
}
