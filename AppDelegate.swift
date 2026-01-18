import Cocoa
import ApplicationServices
import ServiceManagement

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var multitouchManager: MultitouchManager?
    var isEnabled = true
    private var hasStartedMultitouch = false
    private var hasRequestedAccessibilityPrompt = false
    private var hasShownAccessibilityInstructions = false
    private var accessibilityCheckAttempts = 0
    private let maxAccessibilityCheckAttempts = Int(Constants.Timing.accessibilityTimeout / Constants.Timing.accessibilityCheckInterval)

    // Restart manager for handling device reconnection
    private var restartManager: MultitouchRestartManager?

    // Drag state
    private var dragEventSource: CGEventSource?
    private var isDragging = false

    // Track sleep state for enhanced recovery
    private var lastSleepTime: Date?
    private var isRecoveringFromSleep = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        registerForSleepWakeNotifications()
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
        multitouchManager?.stop()
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

    private func setupRestartManager() {
        restartManager = MultitouchRestartManager(appDelegate: self)

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
        let statusText = isEnabled ? "Status: Running" : "Status: Disabled"
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

    @objc func toggleEnabled() {
        isEnabled.toggle()
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
        • Double-tap and hold to drag and drop
        • Launch at login support

        Version \(Constants.App.version)

        Uses private MultitouchSupport framework
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc func quit() {
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

        // Create event source for drag events
        dragEventSource = CGEventSource(stateID: .hidSystemState)

        // Setup restart manager first
        setupRestartManager()

        // Create and start multitouch manager
        multitouchManager = MultitouchManager()
        setupMultitouchCallbacks()
        let deviceCount = multitouchManager?.start() ?? 0

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
        // Handle clicks
        multitouchManager?.onClickSynthesized = { [weak self] location, isRightClick in
            self?.synthesizeClick(at: location, isRightClick: isRightClick)
        }

        // Handle drag start
        multitouchManager?.onDragStarted = { [weak self] location in
            self?.startDrag(at: location)
        }

        // Handle drag movement
        multitouchManager?.onDragMoved = { [weak self] location in
            self?.moveDrag(to: location)
        }

        // Handle drag end
        multitouchManager?.onDragEnded = { [weak self] location in
            self?.endDrag(at: location)
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

    func synthesizeClick(at location: CGPoint, isRightClick: Bool) {
        if isRightClick {
            if let mouseDown = CGEvent(mouseEventSource: nil, mouseType: .rightMouseDown, mouseCursorPosition: location, mouseButton: .right) {
                mouseDown.post(tap: .cghidEventTap)
            }
            if let mouseUp = CGEvent(mouseEventSource: nil, mouseType: .rightMouseUp, mouseCursorPosition: location, mouseButton: .right) {
                mouseUp.post(tap: .cghidEventTap)
            }
        } else {
            if let mouseDown = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: location, mouseButton: .left) {
                mouseDown.post(tap: .cghidEventTap)
            }
            if let mouseUp = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: location, mouseButton: .left) {
                mouseUp.post(tap: .cghidEventTap)
            }
        }
    }

    // MARK: - Drag & Drop Support

    func startDrag(at location: CGPoint) {
        guard !isDragging else { return }
        isDragging = true

        // Synthesize mouse down event to start drag
        if let mouseDown = CGEvent(mouseEventSource: dragEventSource, mouseType: .leftMouseDown, mouseCursorPosition: location, mouseButton: .left) {
            mouseDown.post(tap: .cghidEventTap)
        }
    }

    func moveDrag(to location: CGPoint) {
        guard isDragging else { return }

        // Synthesize mouse dragged event
        if let mouseDrag = CGEvent(mouseEventSource: dragEventSource, mouseType: .leftMouseDragged, mouseCursorPosition: location, mouseButton: .left) {
            mouseDrag.post(tap: .cghidEventTap)
        }
    }

    func endDrag(at location: CGPoint) {
        guard isDragging else { return }
        isDragging = false

        // Synthesize mouse up event to end drag
        if let mouseUp = CGEvent(mouseEventSource: dragEventSource, mouseType: .leftMouseUp, mouseCursorPosition: location, mouseButton: .left) {
            mouseUp.post(tap: .cghidEventTap)
        }
    }
}
