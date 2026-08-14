import Cocoa
@preconcurrency import ApplicationServices
import ServiceManagement
import IOKit.pwr_mgt

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var multitouchManager: MultitouchManager?
    private let mouseSpeedManager = MouseSpeedManager(backend: MouseSpeedIOKitBackend())
    var isEnabled = true
    private var hasStartedMultitouch = false
    private var hasRequestedAccessibilityPrompt = false
    private var hasShownAccessibilityInstructions = false
    private var accessibilityCheckAttempts = 0
    private let maxAccessibilityCheckAttempts = Int(Constants.Timing.accessibilityTimeout / Constants.Timing.accessibilityCheckInterval)

    // Restart manager for handling device reconnection
    private var restartManager: MultitouchRestartManager?

    // Posts tap/drag mouse events directly from the multitouch queue
    private let eventSynthesizer = EventSynthesizer()

    // Event-driven Magic Mouse connect/disconnect detection via IOKit
    // notifications; reacts immediately instead of waiting for health-check polls
    private var deviceMonitor: MultitouchDeviceMonitor?

    // Settings window for the tap-detection thresholds
    private var settingsWindowController: SettingsWindowController?

    // Track sleep state for enhanced recovery
    private var lastSleepTime: Date?
    private var isRecoveringFromSleep = false

    // Prevent system sleep (keep running with lid closed)
    private var sleepAssertionID: IOPMAssertionID = 0
    private var preventSleepEnabled = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        prepareMouseSpeed()
        setupMenuBar()
        registerForSleepWakeNotifications()
        loadPreventSleepPreference()
        if preventSleepEnabled {
            enableSleepPrevention()
        }
        ensureAccessibilityAndStart()
    }

    @objc func showAccessibilityInstructions() {
        guard !hasShownAccessibilityInstructions else { return }
        hasShownAccessibilityInstructions = true
        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Required"
        alert.informativeText = "\(Constants.App.name) needs accessibility permissions to simulate clicks.\n\nPlease grant permission in:\nSystem Settings > Privacy & Security > Accessibility\n\nAfter enabling, return to \(Constants.App.name). The app will begin working as soon as permission is granted."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Quit")

        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: Constants.URLs.accessibilitySettings)!)
        } else if response == .alertSecondButtonReturn {
            NSApplication.shared.terminate(nil)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        restartManager?.stopHealthCheck()
        restartManager?.cancelPendingRestart()
        deviceMonitor?.stop()
        cancelActiveDrag()
        multitouchManager?.stop()
        disableSleepPrevention()
        unregisterForSleepWakeNotifications()
    }

    // MARK: - Sleep/Wake Monitoring

    private func registerForSleepWakeNotifications() {
        // 监听系统睡眠通知
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(systemWillSleep),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )

        // 监听系统唤醒通知
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(systemDidWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )

        // 监听屏幕锁定/解锁（用于检测短暂休眠）
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(screenDidUnlock),
            name: NSNotification.Name(Constants.Notifications.screenUnlocked),
            object: nil
        )
    }

    private func unregisterForSleepWakeNotifications() {
        NSWorkspace.shared.notificationCenter.removeObserver(
            self,
            name: NSWorkspace.willSleepNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.removeObserver(
            self,
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
        DistributedNotificationCenter.default().removeObserver(
            self,
            name: NSNotification.Name(Constants.Notifications.screenUnlocked),
            object: nil
        )
    }

    @objc private func systemWillSleep() {
        #if DEBUG
        print("💤 System going to sleep - stopping multitouch manager")
        #endif

        lastSleepTime = Date()
        restartManager?.stopHealthCheck()
        restartManager?.cancelPendingRestart()
        deviceMonitor?.stop()
        cancelActiveDrag()
        multitouchManager?.stop()
    }

    @objc private func systemDidWake() {
        #if DEBUG
        print("👀 System woke up - scheduling restart")
        #endif

        guard isEnabled else { return }

        isRecoveringFromSleep = true

        // Calculate sleep duration to determine recovery strategy
        let sleepDuration = lastSleepTime.map { Date().timeIntervalSince($0) } ?? 0

        // Longer sleep = longer initial delay (Bluetooth takes more time to reconnect)
        let initialDelay: TimeInterval
        if sleepDuration > Constants.SleepRecovery.longSleepThreshold {
            initialDelay = Constants.SleepRecovery.longSleepDelay
            #if DEBUG
            print("⏰ Long sleep detected (\(String(format: "%.0f", sleepDuration))s), using extended delay")
            #endif
        } else if sleepDuration > Constants.SleepRecovery.mediumSleepThreshold {
            initialDelay = Constants.SleepRecovery.mediumSleepDelay
        } else {
            initialDelay = Constants.SleepRecovery.shortSleepDelay
        }

        restartManager?.restart(reason: .systemWake, afterDelay: initialDelay)
        startDeviceMonitor()
    }

    @objc private func screenDidUnlock() {
        #if DEBUG
        print("🔓 Screen unlocked")
        #endif

        // If we're not recovering from sleep, this might be just a screen lock
        // Still check if devices are valid
        guard isEnabled, !isRecoveringFromSleep else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + Constants.Timing.screenUnlockCheckDelay) { [weak self] in
            guard let self = self else { return }

            if let manager = self.multitouchManager, !manager.validateDevices() {
                #if DEBUG
                print("🔓 Devices invalid after unlock, restarting...")
                #endif
                self.restartManager?.restart(reason: .bluetoothReconnect, afterDelay: Constants.SleepRecovery.bluetoothReconnectDelay)
            }
        }
    }

    // MARK: - Sleep Prevention

    private func loadPreventSleepPreference() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: Constants.SleepPrevention.userDefaultsKey) == nil {
            // A background input utility should not change the Mac's normal
            // energy behavior unless the user explicitly opts in.
            preventSleepEnabled = false
        } else {
            preventSleepEnabled = defaults.bool(forKey: Constants.SleepPrevention.userDefaultsKey)
        }
    }

    private func enableSleepPrevention() {
        guard sleepAssertionID == 0 else { return }

        var assertionID: IOPMAssertionID = 0
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            Constants.SleepPrevention.assertionReason as CFString,
            &assertionID
        )

        if result == kIOReturnSuccess {
            sleepAssertionID = assertionID
            #if DEBUG
            print("☕ Sleep prevention enabled (PreventSystemSleep assertion active)")
            #endif
        } else {
            #if DEBUG
            print("⚠️ Failed to enable sleep prevention: 0x\(String(result, radix: 16))")
            #endif
        }
    }

    private func disableSleepPrevention() {
        guard sleepAssertionID != 0 else { return }

        let result = IOPMAssertionRelease(sleepAssertionID)
        if result != kIOReturnSuccess {
            #if DEBUG
            print("⚠️ Failed to release sleep assertion: 0x\(String(result, radix: 16))")
            #endif
        }
        sleepAssertionID = 0
    }

    @objc func togglePreventSleep() {
        preventSleepEnabled.toggle()
        UserDefaults.standard.set(preventSleepEnabled, forKey: Constants.SleepPrevention.userDefaultsKey)

        if preventSleepEnabled {
            enableSleepPrevention()
        } else {
            disableSleepPrevention()
        }
        updateMenu()
    }

    private func setupRestartManager() {
        restartManager = MultitouchRestartManager(controller: self)

        restartManager?.onRestartCompleted = { [weak self] success, deviceCount in
            guard let self = self else { return }

            self.isRecoveringFromSleep = false

            if success {
                // Start health check after successful restart
                self.restartManager?.startHealthCheck()
            }
        }

        restartManager?.onRestartFailed = { [weak self] attempts in
            guard let self = self else { return }

            self.isRecoveringFromSleep = false

            #if DEBUG
            print("❌ Restart failed after \(attempts) attempts, health check will retry later")
            #endif

            // Even if restart failed, start health check to keep trying
            self.restartManager?.startHealthCheck()
        }
    }

    // MARK: - Device Monitor

    private func startDeviceMonitor() {
        deviceMonitor = MultitouchDeviceMonitor()
        deviceMonitor?.onEvent = { [weak self] event in
            DispatchQueue.main.async {
                self?.handleDeviceMonitorEvent(event)
            }
        }
        deviceMonitor?.start()
    }

    private func handleDeviceMonitorEvent(_ event: MultitouchDeviceMonitor.Event) {
        guard isEnabled else { return }

        switch event {
        case .connected:
            // Bluetooth needs a moment before the multitouch stack lists the
            // new device; the restart manager retries until it appears.
            if multitouchManager?.getDeviceCount() == 0 || !(multitouchManager?.validateDevices() ?? false) {
                restartManager?.restart(reason: .bluetoothReconnect, afterDelay: Constants.SleepRecovery.bluetoothReconnectDelay)
            }
        case .disconnected:
            // If our registered devices no longer match reality, re-enter the
            // retry loop so a returning mouse is picked up promptly (also via
            // the .connected event above).
            if let manager = multitouchManager, !manager.validateDevices() {
                restartManager?.restart(reason: .bluetoothReconnect)
            }
        }
    }

    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "computermouse.fill", accessibilityDescription: "MagicTapper")
        }

        updateMenu()
    }

    func updateMenu() {
        let menu = NSMenu()

        // Status indicator
        let deviceCount = multitouchManager?.getDeviceCount() ?? 0
        let statusText: String
        if !isEnabled {
            statusText = "Status: Disabled"
        } else if deviceCount > 0 {
            statusText = "Status: Running (\(deviceCount) Magic Mouse)"
        } else {
            statusText = "Status: Waiting for Magic Mouse"
        }
        let statusMenuItem = NSMenuItem(title: statusText, action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)

        menu.addItem(NSMenuItem.separator())

        // Enable/Disable toggle
        let enabledItem = NSMenuItem(title: "Tap to Click: Enabled", action: #selector(toggleEnabled), keyEquivalent: "")
        enabledItem.state = isEnabled ? .on : .off
        enabledItem.target = self
        menu.addItem(enabledItem)

        menu.addItem(NSMenuItem.separator())

        // Launch at Login toggle
        let launchAtLoginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchAtLoginItem.state = isLaunchAtLoginEnabled() ? .on : .off
        launchAtLoginItem.target = self
        menu.addItem(launchAtLoginItem)

        // Prevent Sleep toggle (keep running with lid closed)
        let preventSleepItem = NSMenuItem(title: "Prevent Sleep (Keep Running)", action: #selector(togglePreventSleep), keyEquivalent: "")
        preventSleepItem.state = preventSleepEnabled ? .on : .off
        preventSleepItem.target = self
        menu.addItem(preventSleepItem)

        menu.addItem(NSMenuItem.separator())

        // Pointer speed slider
        let pointerSpeedItem = NSMenuItem()
        pointerSpeedItem.view = makePointerSpeedMenuView()
        menu.addItem(pointerSpeedItem)

        menu.addItem(NSMenuItem.separator())

        // Sensitivity settings window
        let settingsItem = NSMenuItem(title: "Sensitivity Settings…", action: #selector(showSettings), keyEquivalent: "")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        // Accessibility instructions
        let accessibilityItem = NSMenuItem(title: "Accessibility Instructions…", action: #selector(showAccessibilityInstructions), keyEquivalent: "")
        accessibilityItem.target = self
        menu.addItem(accessibilityItem)

        menu.addItem(NSMenuItem.separator())

        // About
        let aboutItem = NSMenuItem(title: "About MagicTapper", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(title: "Quit MagicTapper", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    private func prepareMouseSpeed() {
        do {
            _ = try mouseSpeedManager.prepare()
        } catch {
            #if DEBUG
            print("⚠️ Pointer speed setup failed: \(error.localizedDescription)")
            #endif
        }
    }

    private func makePointerSpeedMenuView() -> PointerSpeedMenuView {
        let speedView = PointerSpeedMenuView(currentSpeed: mouseSpeedManager.currentSpeed)

        speedView.onSpeedChanged = { [weak self, weak speedView] speed in
            guard let self = self else { return false }

            do {
                let appliedSpeed = try self.mouseSpeedManager.setSpeed(speed)
                speedView?.setSpeed(appliedSpeed)
                return true
            } catch {
                self.showMouseSpeedError(error)
                return false
            }
        }

        speedView.onRestoreDefault = { [weak self] in
            guard let self = self else { return nil }

            do {
                return try self.mouseSpeedManager.restoreSystemDefault()
            } catch {
                self.showMouseSpeedError(error)
                return nil
            }
        }

        return speedView
    }

    private func showMouseSpeedError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "Pointer Speed Error"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc func toggleEnabled() {
        isEnabled.toggle()
        if !isEnabled {
            cancelActiveDrag()
        }
        multitouchManager?.setEnabled(isEnabled)
        updateMenu()
    }

    @objc func toggleLaunchAtLogin() {
        do {
            if isLaunchAtLoginEnabled() {
                // Disable launch at login
                try SMAppService.mainApp.unregister()
            } else {
                // Enable launch at login
                try SMAppService.mainApp.register()
            }
            updateMenu()
        } catch {
            let alert = NSAlert()
            alert.messageText = "Launch at Login Error"
            alert.informativeText = "Failed to toggle Launch at Login: \(error.localizedDescription)"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    func isLaunchAtLoginEnabled() -> Bool {
        return SMAppService.mainApp.status == .enabled
    }

    @objc func showAbout() {
        let alert = NSAlert()
        alert.messageText = Constants.App.name
        alert.informativeText = """
        Advanced tap-to-click for Magic Mouse

        Features:
        • Tap left side for left click
        • Hold tap on right side (>0.1s) for right click
        • Double-tap and release for a double-click
        • Keep the second tap held and move to drag and drop
        • Adjust global pointer speed beyond the system slider
        • Adjustable tap sensitivity (Sensitivity Settings)
        • Launch at login support

        Version \(Constants.App.version)

        Uses private MultitouchSupport framework
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc func showSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController()
        }
        settingsWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func quit() {
        cancelActiveDrag()
        multitouchManager?.stop()
        NSApplication.shared.terminate(nil)
    }

    private func ensureAccessibilityAndStart() {
        if AXIsProcessTrusted() {
            startMultitouchManager()
            return
        }

        requestAccessibilityPermissionIfNeeded()
        waitForAccessibilityPermission()
    }

    private func startMultitouchManager() {
        guard !hasStartedMultitouch else { return }
        hasStartedMultitouch = true

        // Setup restart manager first
        setupRestartManager()

        // Create and start multitouch manager
        multitouchManager = MultitouchManager()
        setupMultitouchCallbacks()
        let deviceCount = multitouchManager?.start() ?? 0
        startDeviceMonitor()
        updateMenu()

        if deviceCount > 0 {
            restartManager?.markSuccessfulStart(deviceCount: deviceCount)
            // Start health check for ongoing monitoring
            restartManager?.startHealthCheck()
        } else {
            // No devices found on initial start, trigger restart sequence
            #if DEBUG
            print("⚠️ No devices found on initial start, triggering restart sequence")
            #endif
            restartManager?.restart(reason: .manual, afterDelay: Constants.Timing.initialRestartDelay)
        }
    }

    func setupMultitouchCallbacks() {
        // Events are posted straight from the multitouch touch queue. Hopping
        // through the main thread would tie tap/drag latency to UI work such
        // as menu tracking or modal alerts.
        multitouchManager?.onClickSynthesized = { [weak eventSynthesizer] location, isRightClick, clickCount in
            eventSynthesizer?.synthesizeClick(at: location, isRightClick: isRightClick, clickCount: clickCount)
        }

        multitouchManager?.onDragStarted = { [weak eventSynthesizer] location in
            eventSynthesizer?.startDrag(at: location)
        }

        multitouchManager?.onDragMoved = { [weak eventSynthesizer] location in
            eventSynthesizer?.moveDrag(to: location)
        }

        multitouchManager?.onDragEnded = { [weak eventSynthesizer] location in
            eventSynthesizer?.endDrag(at: location)
        }
    }

    private func requestAccessibilityPermissionIfNeeded() {
        guard !hasRequestedAccessibilityPrompt else { return }
        hasRequestedAccessibilityPrompt = true

        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [promptKey: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    private func waitForAccessibilityPermission() {
        DispatchQueue.main.asyncAfter(deadline: .now() + Constants.Timing.accessibilityCheckInterval) { [weak self] in
            guard let self = self else { return }

            if AXIsProcessTrusted() {
                self.accessibilityCheckAttempts = 0
                self.startMultitouchManager()
            } else {
                self.accessibilityCheckAttempts += 1

                if self.accessibilityCheckAttempts >= self.maxAccessibilityCheckAttempts {
                    // Timeout reached, show instructions dialog
                    #if DEBUG
                    print("⚠️ Accessibility permission wait timeout after \(self.maxAccessibilityCheckAttempts) seconds")
                    #endif
                    self.showAccessibilityTimeoutAlert()
                } else {
                    // Continue waiting
                    self.waitForAccessibilityPermission()
                }
            }
        }
    }

    private func showAccessibilityTimeoutAlert() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Required"
        alert.informativeText = "\(Constants.App.name) has been waiting for accessibility permission for \(Int(Constants.Timing.accessibilityTimeout)) seconds.\n\nPlease grant permission in:\nSystem Settings > Privacy & Security > Accessibility\n\nYou can:\n• Open System Settings and grant permission, then click \"Retry\"\n• Or quit the app if you don't want to grant permission"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Retry")
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Quit")

        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()

        switch response {
        case .alertFirstButtonReturn:
            // Retry - check immediately, then continue waiting loop
            if AXIsProcessTrusted() {
                accessibilityCheckAttempts = 0
                startMultitouchManager()
            } else {
                // Reset counter and continue waiting
                accessibilityCheckAttempts = 0
                waitForAccessibilityPermission()
            }
        case .alertSecondButtonReturn:
            // Open System Settings
            NSWorkspace.shared.open(URL(string: Constants.URLs.accessibilitySettings)!)
            // Reset counter and continue waiting
            accessibilityCheckAttempts = 0
            waitForAccessibilityPermission()
        default:
            // Quit
            NSApplication.shared.terminate(nil)
        }
    }

    // MARK: - Drag & Drop Support

    private func cancelActiveDrag() {
        eventSynthesizer.cancelActiveDrag()
    }
}

// MARK: - MultitouchController

extension AppDelegate: MultitouchController {
    var isAppEnabled: Bool { isEnabled }

    var currentDeviceCount: Int {
        multitouchManager?.getDeviceCount() ?? 0
    }

    var areCurrentDevicesValid: Bool {
        multitouchManager?.validateDevices() ?? false
    }

    /// Single controlled entry point used by `MultitouchRestartManager` to
    /// rebuild the multitouch stack. Keeps the restart manager from reaching
    /// into AppDelegate internals.
    @discardableResult
    func stopAndRecreateMultitouch() -> Int {
        cancelActiveDrag()
        multitouchManager?.stop()
        multitouchManager = MultitouchManager()
        setupMultitouchCallbacks()
        return multitouchManager?.start() ?? 0
    }
}
