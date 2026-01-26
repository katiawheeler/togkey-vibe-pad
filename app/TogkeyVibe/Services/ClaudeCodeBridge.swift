// ClaudeCodeBridge.swift
// Togkey Vibe - Interface to Claude Code CLI

import Foundation
import Combine
import AppKit

/// Bridge to Claude Code CLI for sending commands and monitoring status
final class ClaudeCodeBridge: ObservableObject {
    // MARK: - Properties

    @Published private(set) var isClaudeRunning: Bool = false
    @Published private(set) var lastCommand: String = ""
    @Published private(set) var lastError: String? = nil
    @Published private(set) var hasAccessibilityPermission: Bool = false

    private var claudeProcess: Process?
    private var outputPipe: Pipe?
    private var processMonitorTimer: Timer?

    // Claude Code CLI path
    private let claudeCliPath: String

    // MARK: - Initialization

    init(claudeCliPath: String = "/usr/local/bin/claude") {
        self.claudeCliPath = claudeCliPath
        checkAccessibilityPermission()
        startProcessMonitor()
    }

    // MARK: - Accessibility Permission

    /// Check if the app has accessibility permission (required for keyboard simulation)
    func checkAccessibilityPermission() {
        hasAccessibilityPermission = AXIsProcessTrusted()
    }

    /// Request accessibility permission
    func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        // Re-check after a delay (user may grant permission)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.checkAccessibilityPermission()
        }
    }

    deinit {
        processMonitorTimer?.invalidate()
    }

    // MARK: - Public Methods

    /// Send a slash command to Claude Code
    func sendCommand(_ command: String) {
        lastCommand = command
        lastError = nil

        // Commands are sent by simulating keyboard input to the focused terminal
        // This works with Claude Code running in any terminal emulator
        simulateKeyboardInput(command + "\n")
    }

    /// Clear the current chat context
    func clearChat() {
        sendCommand("/clear")
    }

    /// Undo the last file change
    func undoChange() {
        sendCommand("/undo")
    }

    /// Resume an interrupted task
    func resumeTask() {
        sendCommand("/resume")
    }

    /// Trigger git commit workflow
    func commit() {
        sendCommand("/commit")
    }

    /// Trigger pull request workflow
    func createPR() {
        sendCommand("/pr")
    }

    /// Send Escape key to stop current operation
    func stopOperation() {
        simulateEscapeKey()
    }

    /// Send Ctrl+C to interrupt current operation
    func interruptOperation() {
        simulateCtrlC()
    }

    /// Apply think level prefix to a prompt
    func applyThinkPrefix(_ prompt: String, level: ThinkLevel) -> String {
        guard let prefix = level.promptPrefix else {
            return prompt
        }
        return "\(prefix): \(prompt)"
    }

    // MARK: - Voice Mode Integration

    /// Toggle STT via voicemode MCP
    func toggleSTT(enable: Bool, completion: @escaping (Bool) -> Void) {
        // The voicemode MCP is controlled through Claude Code
        // We send a special command that Claude interprets
        if enable {
            // Start listening
            sendCommand("@voicemode start listening")
        } else {
            // Stop listening
            sendCommand("@voicemode stop listening")
        }

        // For now, assume success - in a full implementation,
        // we'd monitor the response
        completion(true)
    }

    // MARK: - Private Methods

    /// Simulate keyboard input using Accessibility APIs
    private func simulateKeyboardInput(_ text: String) {
        guard let source = CGEventSource(stateID: .hidSystemState) else {
            lastError = "Failed to create event source"
            return
        }

        for character in text {
            guard let keyCode = keyCodeForCharacter(character) else { continue }

            // Key down
            if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true) {
                if character.isUppercase || needsShift(character) {
                    keyDown.flags = .maskShift
                }
                keyDown.post(tap: .cghidEventTap)
            }

            // Key up
            if let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) {
                keyUp.post(tap: .cghidEventTap)
            }

            // Small delay between keystrokes
            usleep(1000)
        }
    }

    /// Simulate Escape key press
    private func simulateEscapeKey() {
        guard let source = CGEventSource(stateID: .hidSystemState) else { return }

        let escapeKeyCode: CGKeyCode = 0x35

        if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: escapeKeyCode, keyDown: true) {
            keyDown.post(tap: .cghidEventTap)
        }

        if let keyUp = CGEvent(keyboardEventSource: source, virtualKey: escapeKeyCode, keyDown: false) {
            keyUp.post(tap: .cghidEventTap)
        }
    }

    /// Simulate Ctrl+C
    private func simulateCtrlC() {
        guard let source = CGEventSource(stateID: .hidSystemState) else { return }

        let cKeyCode: CGKeyCode = 0x08

        // Ctrl+C key down
        if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: cKeyCode, keyDown: true) {
            keyDown.flags = .maskControl
            keyDown.post(tap: .cghidEventTap)
        }

        // Ctrl+C key up
        if let keyUp = CGEvent(keyboardEventSource: source, virtualKey: cKeyCode, keyDown: false) {
            keyUp.flags = .maskControl
            keyUp.post(tap: .cghidEventTap)
        }
    }

    /// Get virtual key code for a character
    private func keyCodeForCharacter(_ char: Character) -> CGKeyCode? {
        // Standard US keyboard layout key codes
        // Base characters (no shift required)
        let baseKeyMap: [Character: CGKeyCode] = [
            // Letters
            "a": 0x00, "s": 0x01, "d": 0x02, "f": 0x03, "h": 0x04,
            "g": 0x05, "z": 0x06, "x": 0x07, "c": 0x08, "v": 0x09,
            "b": 0x0B, "q": 0x0C, "w": 0x0D, "e": 0x0E, "r": 0x0F,
            "y": 0x10, "t": 0x11, "o": 0x1F, "u": 0x20, "i": 0x22,
            "p": 0x23, "l": 0x25, "j": 0x26, "k": 0x28, "n": 0x2D,
            "m": 0x2E,

            // Numbers
            "1": 0x12, "2": 0x13, "3": 0x14, "4": 0x15, "5": 0x17,
            "6": 0x16, "7": 0x1A, "8": 0x1C, "9": 0x19, "0": 0x1D,

            // Special characters (unshifted)
            "-": 0x1B, "=": 0x18, "[": 0x21, "]": 0x1E, "\\": 0x2A,
            ";": 0x29, "'": 0x27, "`": 0x32, ",": 0x2B, ".": 0x2F,
            "/": 0x2C,

            // Whitespace
            " ": 0x31,
            "\t": 0x30, // Tab
            "\n": 0x24, // Return
        ]

        // Shifted characters map to their base key
        let shiftedKeyMap: [Character: CGKeyCode] = [
            // Shifted numbers -> symbols
            "!": 0x12, "@": 0x13, "#": 0x14, "$": 0x15, "%": 0x17,
            "^": 0x16, "&": 0x1A, "*": 0x1C, "(": 0x19, ")": 0x1D,

            // Shifted special characters
            "_": 0x1B, "+": 0x18, "{": 0x21, "}": 0x1E, "|": 0x2A,
            ":": 0x29, "\"": 0x27, "~": 0x32, "<": 0x2B, ">": 0x2F,
            "?": 0x2C,
        ]

        // Check lowercase letter first
        if char.isLetter {
            let lowerChar = char.lowercased().first ?? char
            return baseKeyMap[lowerChar]
        }

        // Check base key map
        if let keyCode = baseKeyMap[char] {
            return keyCode
        }

        // Check shifted key map
        if let keyCode = shiftedKeyMap[char] {
            return keyCode
        }

        return nil
    }

    /// Check if character needs shift modifier
    private func needsShift(_ char: Character) -> Bool {
        // Uppercase letters need shift
        if char.isLetter && char.isUppercase {
            return true
        }

        // Shifted symbol characters
        let shiftChars: Set<Character> = [
            "!", "@", "#", "$", "%", "^", "&", "*", "(", ")",
            "_", "+", "{", "}", "|", ":", "\"", "<", ">", "?", "~"
        ]
        return shiftChars.contains(char)
    }

    /// Simulate a specific key combination with modifiers
    func simulateKeyCombo(keyCode: CGKeyCode, modifiers: CGEventFlags = []) {
        guard let source = CGEventSource(stateID: .hidSystemState) else {
            lastError = "Failed to create event source"
            return
        }

        if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true) {
            if !modifiers.isEmpty {
                keyDown.flags = modifiers
            }
            keyDown.post(tap: .cghidEventTap)
        }

        if let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) {
            if !modifiers.isEmpty {
                keyUp.flags = modifiers
            }
            keyUp.post(tap: .cghidEventTap)
        }
    }

    /// Common key codes for special keys
    enum SpecialKey: CGKeyCode {
        case escape = 0x35
        case returnKey = 0x24
        case tab = 0x30
        case space = 0x31
        case delete = 0x33
        case forwardDelete = 0x75
        case upArrow = 0x7E
        case downArrow = 0x7D
        case leftArrow = 0x7B
        case rightArrow = 0x7C
        case home = 0x73
        case end = 0x77
        case pageUp = 0x74
        case pageDown = 0x79
        case f1 = 0x7A
        case f2 = 0x78
        case f3 = 0x63
        case f4 = 0x76
        case f5 = 0x60
        case f6 = 0x61
        case f7 = 0x62
        case f8 = 0x64
        case f9 = 0x65
        case f10 = 0x6D
        case f11 = 0x67
        case f12 = 0x6F
    }

    /// Start monitoring for Claude process
    private func startProcessMonitor() {
        processMonitorTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkClaudeProcess()
        }
    }

    /// Check if Claude Code is running
    private func checkClaudeProcess() {
        let task = Process()
        task.launchPath = "/usr/bin/pgrep"
        task.arguments = ["-f", "claude"]

        let pipe = Pipe()
        task.standardOutput = pipe

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""

            DispatchQueue.main.async { [weak self] in
                self?.isClaudeRunning = !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.isClaudeRunning = false
            }
        }
    }
}

// MARK: - Mode-specific Commands

extension ClaudeCodeBridge {
    /// Get environment variables for a specific mode
    func environmentForMode(_ mode: VibeMode) -> [String: String] {
        let env = ProcessInfo.processInfo.environment

        // Mode-specific environment variables could be added here
        // Currently, Claude Code modes are controlled via CLI flags at launch time
        // rather than environment variables

        return env
    }

    /// Format mode change notification for display
    func modeChangeMessage(_ mode: VibeMode) -> String {
        switch mode {
        case .ask:
            return "Mode: Ask - Requesting permission for actions"
        case .plan:
            return "Mode: Plan - Architecture and design mode"
        case .acceptEdits:
            return "Mode: Accept Edits - Auto-accepting file changes"
        case .acceptAll:
            return "Mode: Accept All - Full vibe mode activated"
        }
    }
}
