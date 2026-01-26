// LEDController.swift
// Togkey Vibe - LED state management and animation

import Foundation
import Combine

/// Controls LED color and pattern based on device state
final class LEDController: ObservableObject {
    // MARK: - Properties

    @Published private(set) var currentColor: LEDColor = .dimWhite
    @Published private(set) var currentPattern: LEDPattern = .solid
    @Published private(set) var currentSpeed: UInt8 = 128

    private weak var hidManager: HIDManager?
    private var animationTimer: Timer?
    private var temporaryStateTimer: Timer?

    // Temporary state for feedback animations
    private var baseColor: LEDColor = .dimWhite
    private var basePattern: LEDPattern = .solid

    // MARK: - Initialization

    init(hidManager: HIDManager? = nil) {
        self.hidManager = hidManager
    }

    /// Set the HID manager for sending commands
    func setHIDManager(_ manager: HIDManager) {
        self.hidManager = manager
    }

    // MARK: - Public Methods

    /// Update LED based on device state
    func updateFromState(_ state: DeviceState) {
        let color: LEDColor
        let pattern: LEDPattern
        let speed: UInt8

        // Determine color and pattern based on state
        if !state.connectionState.isConnected {
            // Disconnected - dim white solid
            color = .dimWhite
            pattern = .solid
            speed = 128
        } else if state.lastError != nil {
            // Error state - red flash
            color = .red
            pattern = .flash
            speed = 200
        } else if state.isProcessing {
            // Processing - white breathe
            color = .white
            pattern = .breathe
            speed = 100
        } else if state.sttEnabled {
            // STT active - purple pulse
            color = .purple
            pattern = .pulse
            speed = 150
        } else {
            // Normal - mode color solid
            color = state.currentMode.ledColor
            pattern = .solid
            speed = 128
        }

        setLED(color: color, pattern: pattern, speed: speed)
    }

    /// Set LED to specific color and pattern
    func setLED(color: LEDColor, pattern: LEDPattern, speed: UInt8 = 128) {
        guard color != currentColor || pattern != currentPattern || speed != currentSpeed else {
            return // No change needed
        }

        currentColor = color
        currentPattern = pattern
        currentSpeed = speed
        baseColor = color
        basePattern = pattern

        // Send to device
        sendToDevice()
    }

    /// Flash LED temporarily (for feedback)
    func flash(color: LEDColor, duration: TimeInterval = 0.3) {
        let originalColor = currentColor
        let originalPattern = currentPattern

        // Set flash color
        currentColor = color
        currentPattern = .solid
        sendToDevice()

        // Restore after duration
        temporaryStateTimer?.invalidate()
        temporaryStateTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            self?.currentColor = originalColor
            self?.currentPattern = originalPattern
            self?.sendToDevice()
        }
    }

    /// Pulse LED temporarily (for acknowledgment)
    func pulse(color: LEDColor, duration: TimeInterval = 1.0) {
        let originalColor = currentColor
        let originalPattern = currentPattern
        let originalSpeed = currentSpeed

        // Set pulse
        currentColor = color
        currentPattern = .pulse
        currentSpeed = 200
        sendToDevice()

        // Restore after duration
        temporaryStateTimer?.invalidate()
        temporaryStateTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            self?.currentColor = originalColor
            self?.currentPattern = originalPattern
            self?.currentSpeed = originalSpeed
            self?.sendToDevice()
        }
    }

    // MARK: - Convenience Methods

    /// Set LED for specific mode
    func setModeColor(_ mode: VibeMode) {
        setLED(color: mode.ledColor, pattern: .solid)
    }

    /// Set LED for STT state
    func setSTTState(enabled: Bool) {
        if enabled {
            setLED(color: .purple, pattern: .pulse, speed: 150)
        } else {
            // Will be overridden by mode color in normal flow
            setLED(color: baseColor, pattern: .solid)
        }
    }

    /// Set LED for processing state
    func setProcessing(_ processing: Bool) {
        if processing {
            setLED(color: .white, pattern: .breathe, speed: 100)
        } else {
            setLED(color: baseColor, pattern: basePattern)
        }
    }

    /// Set LED for error state
    func setError() {
        setLED(color: .red, pattern: .flash, speed: 200)
    }

    /// Clear error and restore normal state
    func clearError(_ mode: VibeMode) {
        setModeColor(mode)
    }

    // MARK: - Mode Change Animation

    /// Animate mode change
    func animateModeChange(to mode: VibeMode, completion: @escaping () -> Void) {
        // Quick flash sequence through colors
        let colors: [LEDColor] = [.dimWhite, mode.ledColor, .white, mode.ledColor]
        var index = 0

        animationTimer?.invalidate()
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }

            if index < colors.count {
                self.currentColor = colors[index]
                self.currentPattern = .solid
                self.sendToDevice()
                index += 1
            } else {
                timer.invalidate()
                self.setModeColor(mode)
                completion()
            }
        }
    }

    /// Animate think level change
    func animateThinkChange(level: ThinkLevel) {
        // Brief color flash based on think level
        let flashColor: LEDColor
        switch level {
        case .off: flashColor = .dimWhite
        case .lite: flashColor = .blue
        case .medium: flashColor = .purple
        case .hard: flashColor = .orange
        }

        flash(color: flashColor, duration: 0.2)
    }

    // MARK: - Private Methods

    private func sendToDevice() {
        hidManager?.sendLEDColor(currentColor)
        hidManager?.sendLEDPattern(currentPattern, speed: currentSpeed)
    }
}

// MARK: - LED Presets

extension LEDController {
    /// Predefined LED states
    enum Preset {
        case idle
        case connected(VibeMode)
        case processing
        case listening
        case error
        case success

        var color: LEDColor {
            switch self {
            case .idle: return .dimWhite
            case .connected(let mode): return mode.ledColor
            case .processing: return .white
            case .listening: return .purple
            case .error: return .red
            case .success: return .green
            }
        }

        var pattern: LEDPattern {
            switch self {
            case .idle: return .solid
            case .connected: return .solid
            case .processing: return .breathe
            case .listening: return .pulse
            case .error: return .flash
            case .success: return .solid
            }
        }

        var speed: UInt8 {
            switch self {
            case .processing: return 100
            case .listening: return 150
            case .error: return 200
            default: return 128
            }
        }
    }

    /// Apply a preset
    func applyPreset(_ preset: Preset) {
        setLED(color: preset.color, pattern: preset.pattern, speed: preset.speed)
    }
}
