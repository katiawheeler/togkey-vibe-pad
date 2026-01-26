// DeviceState.swift
// Togkey Vibe - Device state and HID protocol types

import Foundation
import Combine

/// Overall device connection state
enum ConnectionState: Equatable {
    case disconnected
    case connecting
    case connected(firmwareVersion: String)

    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }

    var displayText: String {
        switch self {
        case .disconnected: return "Disconnected"
        case .connecting: return "Connecting..."
        case .connected(let version): return "Connected (v\(version))"
        }
    }
}

/// Key indices matching the HID protocol
enum KeyIndex: UInt8, CaseIterable {
    case thinkCycle = 0
    case clearChat = 1
    case undoChange = 2
    case resumeTask = 3
    case commitPR = 4
    case escapeStop = 5
    case encoderPush = 6

    var displayName: String {
        switch self {
        case .thinkCycle: return "Think Cycle"
        case .clearChat: return "Clear Chat"
        case .undoChange: return "Undo Change"
        case .resumeTask: return "Resume Task"
        case .commitPR: return "Commit/PR"
        case .escapeStop: return "Escape/Stop"
        case .encoderPush: return "STT Toggle"
        }
    }

    var shortName: String {
        switch self {
        case .thinkCycle: return "Think"
        case .clearChat: return "Clear"
        case .undoChange: return "Undo"
        case .resumeTask: return "Resume"
        case .commitPR: return "Commit"
        case .escapeStop: return "Stop"
        case .encoderPush: return "STT"
        }
    }
}

/// Key event types from HID protocol
enum KeyEventType: UInt8 {
    case released = 0x00
    case pressed = 0x01
    case longPressStarted = 0x02
    case longPressReleased = 0x03

    var isPress: Bool {
        self == .pressed || self == .longPressStarted
    }

    var isLongPress: Bool {
        self == .longPressStarted || self == .longPressReleased
    }
}

/// Encoder direction
enum EncoderDirection: UInt8 {
    case counterClockwise = 0x00
    case clockwise = 0x01
}

/// HID command identifiers
enum HIDCommand: UInt8 {
    // Device → Host
    case keyEvent = 0x01
    case encoderEvent = 0x02
    case deviceReady = 0x03
    case heartbeat = 0x04

    // Host → Device
    case setLEDColor = 0x10
    case setLEDPattern = 0x11
    case displayHeader = 0x12
    case displayLine1 = 0x13
    case displayLine2 = 0x14
    case displayFooter = 0x15
    case displayFullRefresh = 0x16
    case displayIcon = 0x17
    case pingResponse = 0x1F
}

/// Display icons available
enum DisplayIcon: UInt8 {
    case microphoneOn = 0x00
    case microphoneOff = 0x01
    case brain = 0x02
    case checkMark = 0x03
    case xMark = 0x04
    case lightning = 0x05
    case clock = 0x06
}

/// Complete device state
final class DeviceState: ObservableObject {
    // Connection
    @Published var connectionState: ConnectionState = .disconnected

    // Current mode and settings
    @Published var currentMode: VibeMode = .ask
    @Published var thinkLevel: ThinkLevel = .off
    @Published var sttEnabled: Bool = false
    @Published var isProcessing: Bool = false

    // Last action tracking
    @Published var lastAction: String = ""
    @Published var lastActionTime: Date? = nil

    // LED state (mirrors what's sent to device)
    @Published var currentLEDColor: LEDColor = .dimWhite
    @Published var currentLEDPattern: LEDPattern = .solid

    // Display content
    @Published var displayHeader: String = ""
    @Published var displayLine1: String = ""
    @Published var displayLine2: String = ""
    @Published var displayFooter: String = ""

    // Error state
    @Published var lastError: String? = nil

    /// Update display based on current state
    func updateDisplay() {
        let micIcon = sttEnabled ? "[MIC]" : "[---]"
        displayHeader = "MODE: \(currentMode.shortName)  \(micIcon)"

        if thinkLevel != .off {
            displayLine1 = "THINK: \(thinkLevel.shortDisplay)"
        } else {
            displayLine1 = ""
        }

        if isProcessing {
            displayLine2 = "Processing..."
        } else if !lastAction.isEmpty {
            displayLine2 = "Last: \(lastAction)"
        } else {
            displayLine2 = ""
        }

        displayFooter = connectionState.displayText
    }

    /// Update LED based on current state
    func updateLED() {
        if !connectionState.isConnected {
            currentLEDColor = .dimWhite
            currentLEDPattern = .solid
        } else if isProcessing {
            currentLEDColor = .white
            currentLEDPattern = .breathe
        } else if sttEnabled {
            currentLEDColor = .purple
            currentLEDPattern = .pulse
        } else if lastError != nil {
            currentLEDColor = .red
            currentLEDPattern = .flash
        } else {
            currentLEDColor = currentMode.ledColor
            currentLEDPattern = .solid
        }
    }

    /// Record an action
    func recordAction(_ action: String) {
        lastAction = action
        lastActionTime = Date()
        lastError = nil
        updateDisplay()
    }

    /// Record an error
    func recordError(_ error: String) {
        lastError = error
        updateLED()
    }

    /// Clear error state
    func clearError() {
        lastError = nil
        updateLED()
    }

    /// Cycle to next mode (clockwise)
    func nextMode() {
        currentMode = currentMode.next
        updateDisplay()
        updateLED()
    }

    /// Cycle to previous mode (counter-clockwise)
    func previousMode() {
        currentMode = currentMode.previous
        updateDisplay()
        updateLED()
    }

    /// Cycle think level
    func cycleThinkLevel() {
        thinkLevel = thinkLevel.next
        updateDisplay()
    }

    /// Toggle STT
    func toggleSTT() {
        sttEnabled.toggle()
        updateDisplay()
        updateLED()
    }

    /// Set processing state
    func setProcessing(_ processing: Bool) {
        isProcessing = processing
        updateDisplay()
        updateLED()
    }

    /// Update connection state
    func setConnected(firmwareVersion: String) {
        connectionState = .connected(firmwareVersion: firmwareVersion)
        updateDisplay()
        updateLED()
    }

    func setDisconnected() {
        connectionState = .disconnected
        updateDisplay()
        updateLED()
    }

    func setConnecting() {
        connectionState = .connecting
        updateDisplay()
    }
}
