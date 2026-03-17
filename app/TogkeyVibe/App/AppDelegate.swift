// AppDelegate.swift
// Togkey Vibe - Application delegate and main controller

import AppKit
import Combine
import UserNotifications

/// Main application delegate that coordinates all services
final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    // MARK: - Services

    let deviceState = DeviceState()
    let hidManager = HIDManager()
    let claudeCodeBridge = ClaudeCodeBridge()
    let voiceModeService = VoiceModeService()
    let displayRenderer = DisplayRenderer()
    let ledController = LEDController()

    // MARK: - Properties

    private var cancellables = Set<AnyCancellable>()
    private var displayUpdateTimer: Timer?
    private var lastDisplayContent: DisplayContent?

    // MARK: - Application Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupServices()
        setupBindings()
        startHIDManager()
        requestNotificationPermission()

        // Hide dock icon by default (menu bar app)
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationWillTerminate(_ notification: Notification) {
        displayUpdateTimer?.invalidate()
        displayUpdateTimer = nil
        hidManager.stop()
        claudeCodeBridge.stop()
        voiceModeService.stop()
    }

    // MARK: - Setup

    private func setupServices() {
        // Configure LED controller with HID manager
        ledController.setHIDManager(hidManager)

        // Set HID manager delegate
        hidManager.delegate = self
    }

    private func setupBindings() {
        // Update LED when device state changes
        deviceState.$currentMode
            .sink { [weak self] mode in
                guard let self = self, self.deviceState.connectionState.isConnected else { return }
                self.ledController.setModeColor(mode)
                self.sendDisplayUpdate()
            }
            .store(in: &cancellables)

        deviceState.$sttEnabled
            .sink { [weak self] enabled in
                guard let self = self, self.deviceState.connectionState.isConnected else { return }
                self.ledController.setSTTState(enabled: enabled)
                self.sendDisplayUpdate()
            }
            .store(in: &cancellables)

        deviceState.$thinkLevel
            .sink { [weak self] level in
                guard let self = self else { return }
                self.ledController.animateThinkChange(level: level)
                self.sendDisplayUpdate()
            }
            .store(in: &cancellables)

        deviceState.$isProcessing
            .sink { [weak self] processing in
                guard let self = self else { return }
                self.ledController.setProcessing(processing)
                self.sendDisplayUpdate()
            }
            .store(in: &cancellables)

        // Start display update timer
        displayUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.sendDisplayUpdate()
        }
    }

    private func startHIDManager() {
        deviceState.setConnecting()
        hidManager.start()
    }

    // MARK: - Display Updates

    private func sendDisplayUpdate() {
        let content = displayRenderer.renderDisplay(state: deviceState)

        // Skip HID commands if nothing changed
        if let last = lastDisplayContent, !content.hasChanged(from: last) {
            return
        }

        // Only send lines that actually changed
        if lastDisplayContent?.header != content.header {
            hidManager.sendDisplayHeader(content.header)
        }
        if lastDisplayContent?.line1 != content.line1 {
            hidManager.sendDisplayLine1(content.line1)
        }
        if lastDisplayContent?.line2 != content.line2 {
            hidManager.sendDisplayLine2(content.line2)
        }
        if lastDisplayContent?.footer != content.footer {
            hidManager.sendDisplayFooter(content.footer)
        }

        lastDisplayContent = content

        // Update local state for preview
        deviceState.displayHeader = content.header
        deviceState.displayLine1 = content.line1
        deviceState.displayLine2 = content.line2
        deviceState.displayFooter = content.footer
    }

    // MARK: - Key Actions

    private func handleKeyPress(_ keyIndex: KeyIndex, isLongPress: Bool) {
        switch keyIndex {
        case .thinkCycle:
            handleThinkCycle()

        case .clearChat:
            handleClearChat()

        case .undoChange:
            handleUndoChange()

        case .resumeTask:
            handleResumeTask()

        case .commitPR:
            handleCommitPR(isLongPress: isLongPress)

        case .escapeStop:
            handleEscapeStop(isLongPress: isLongPress)

        case .encoderPush:
            handleSTTToggle()
        }
    }

    private func handleThinkCycle() {
        deviceState.cycleThinkLevel()
        deviceState.recordAction("Think: \(deviceState.thinkLevel.shortDisplay)")

        // Visual feedback
        ledController.animateThinkChange(level: deviceState.thinkLevel)
    }

    private func handleClearChat() {
        claudeCodeBridge.clearChat()
        deviceState.recordAction("/clear")
        ledController.flash(color: .blue)
    }

    private func handleUndoChange() {
        claudeCodeBridge.undoChange()
        deviceState.recordAction("/undo")
        ledController.flash(color: .orange)
    }

    private func handleResumeTask() {
        claudeCodeBridge.resumeTask()
        deviceState.recordAction("/resume")
        ledController.flash(color: .green)
    }

    private func handleCommitPR(isLongPress: Bool) {
        if isLongPress {
            claudeCodeBridge.createPR()
            deviceState.recordAction("/pr")
            ledController.pulse(color: .purple)
        } else {
            claudeCodeBridge.commit()
            deviceState.recordAction("/commit")
            ledController.flash(color: .green)
        }
    }

    private func handleEscapeStop(isLongPress: Bool) {
        if isLongPress {
            claudeCodeBridge.interruptOperation()
            deviceState.recordAction("Ctrl+C")
        } else {
            claudeCodeBridge.stopOperation()
            deviceState.recordAction("Escape")
        }
        ledController.flash(color: .red)
    }

    private func handleSTTToggle() {
        toggleSTT()
    }

    // MARK: - Public Methods for Menu Bar Actions

    func setMode(_ mode: VibeMode) {
        deviceState.currentMode = mode
        deviceState.recordAction(mode.shortName)
        ledController.animateModeChange(to: mode) { [weak self] in
            self?.sendDisplayUpdate()
        }
    }

    func setThinkLevel(_ level: ThinkLevel) {
        deviceState.thinkLevel = level
        deviceState.recordAction("Think: \(level.shortDisplay)")
        ledController.animateThinkChange(level: level)
    }

    func toggleSTT() {
        deviceState.toggleSTT()

        if deviceState.sttEnabled {
            voiceModeService.startListening()
            deviceState.recordAction("STT On")
        } else {
            voiceModeService.stopListening()
            deviceState.recordAction("STT Off")
        }
    }

    private func handleEncoderRotation(_ direction: EncoderDirection) {
        switch direction {
        case .clockwise:
            deviceState.nextMode()
            deviceState.recordAction(deviceState.currentMode.shortName)

        case .counterClockwise:
            deviceState.previousMode()
            deviceState.recordAction(deviceState.currentMode.shortName)
        }

        // Animate mode change
        ledController.animateModeChange(to: deviceState.currentMode) { [weak self] in
            self?.sendDisplayUpdate()
        }
    }
}

// MARK: - HIDManagerDelegate

extension AppDelegate: HIDManagerDelegate {
    func hidManagerDidConnect(firmwareVersion: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.deviceState.setConnected(firmwareVersion: firmwareVersion)
            self.ledController.updateFromState(self.deviceState)
            self.sendDisplayUpdate()

            // Show notification
            self.showNotification(
                title: "Togkey Vibe Connected",
                body: "Firmware v\(firmwareVersion)"
            )
        }
    }

    func hidManagerDidDisconnect() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.deviceState.setDisconnected()

            // Show notification
            self.showNotification(
                title: "Togkey Vibe Disconnected",
                body: "Device was unplugged"
            )
        }
    }

    func hidManagerDidReceiveKeyEvent(keyIndex: KeyIndex, eventType: KeyEventType) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            switch eventType {
            case .pressed:
                // Short press - handle immediately for most keys
                // (except those that distinguish short/long press)
                if keyIndex != .commitPR && keyIndex != .escapeStop {
                    self.handleKeyPress(keyIndex, isLongPress: false)
                }

            case .longPressStarted:
                // Long press started
                self.handleKeyPress(keyIndex, isLongPress: true)

            case .released:
                // Released after short press (for keys with long press support)
                if keyIndex == .commitPR || keyIndex == .escapeStop {
                    // Only handle as short press if not already handled as long press
                    self.handleKeyPress(keyIndex, isLongPress: false)
                }

            case .longPressReleased:
                // Long press ended - action already taken on longPressStarted
                break
            }
        }
    }

    func hidManagerDidReceiveEncoderEvent(direction: EncoderDirection, steps: UInt8) {
        DispatchQueue.main.async { [weak self] in
            self?.handleEncoderRotation(direction)
        }
    }

    func hidManagerDidReceiveHeartbeat() {
        // Connection is alive - no action needed
    }

    // MARK: - Notifications

    private func showNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
}
