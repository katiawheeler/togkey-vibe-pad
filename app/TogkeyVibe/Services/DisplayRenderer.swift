// DisplayRenderer.swift
// Togkey Vibe - Display content renderer for macropad screen

import Foundation

/// Renders display content for the Togkey Pad Plus screen
final class DisplayRenderer {
    // Display dimensions
    private let maxLineLength: Int = 21
    private let lineCount: Int = 4

    // MARK: - Public Methods

    /// Render the full display content based on device state
    func renderDisplay(state: DeviceState) -> DisplayContent {
        let header = renderHeader(state: state)
        let line1 = renderLine1(state: state)
        let line2 = renderLine2(state: state)
        let footer = renderFooter(state: state)

        return DisplayContent(
            header: header,
            line1: line1,
            line2: line2,
            footer: footer
        )
    }

    /// Render just the header line
    func renderHeader(state: DeviceState) -> String {
        let modeText = "MODE: \(state.currentMode.shortName)"
        let sttIcon = state.sttEnabled ? "[*]" : "[ ]"

        // Pad to fit the line
        let padding = maxLineLength - modeText.count - sttIcon.count
        let spacer = String(repeating: " ", count: max(1, padding))

        return truncate("\(modeText)\(spacer)\(sttIcon)")
    }

    /// Render the first content line
    func renderLine1(state: DeviceState) -> String {
        if state.thinkLevel != .off {
            return centerText("THINK: \(state.thinkLevel.shortDisplay)")
        } else if state.isProcessing {
            return centerText("Processing...")
        }
        return ""
    }

    /// Render the second content line
    func renderLine2(state: DeviceState) -> String {
        if !state.lastAction.isEmpty {
            return truncate("Last: \(state.lastAction)")
        } else if let error = state.lastError {
            return truncate("ERR: \(error)")
        }
        return ""
    }

    /// Render the footer line
    func renderFooter(state: DeviceState) -> String {
        switch state.connectionState {
        case .disconnected:
            return centerText("Disconnected")
        case .connecting:
            return centerText("Connecting...")
        case .connected(let version):
            return truncate("v\(version) Ready")
        }
    }

    // MARK: - Special Renderers

    /// Render a mode change animation frame
    func renderModeChange(mode: VibeMode, frame: Int) -> DisplayContent {
        let frames = ["[    ]", "[ *  ]", "[  * ]", "[   *]", "[  * ]", "[ *  ]"]
        let animFrame = frames[frame % frames.count]

        return DisplayContent(
            header: centerText("MODE CHANGE"),
            line1: centerText(mode.displayName),
            line2: centerText(animFrame),
            footer: ""
        )
    }

    /// Render a think level change
    func renderThinkChange(level: ThinkLevel) -> DisplayContent {
        let brainIcons = String(repeating: "O", count: level.brainCount)
        let emptyIcons = String(repeating: ".", count: 3 - level.brainCount)

        return DisplayContent(
            header: centerText("THINK LEVEL"),
            line1: centerText(level.displayName.uppercased()),
            line2: centerText("[\(brainIcons)\(emptyIcons)]"),
            footer: ""
        )
    }

    /// Render STT status change
    func renderSTTChange(enabled: Bool) -> DisplayContent {
        let icon = enabled ? "(( * ))" : "(( - ))"
        let status = enabled ? "LISTENING" : "MUTED"

        return DisplayContent(
            header: centerText("VOICE MODE"),
            line1: centerText(icon),
            line2: centerText(status),
            footer: ""
        )
    }

    /// Render an action confirmation
    func renderAction(action: String, success: Bool) -> DisplayContent {
        let icon = success ? "[OK]" : "[!!]"

        return DisplayContent(
            header: centerText(icon),
            line1: centerText(action),
            line2: "",
            footer: ""
        )
    }

    /// Render an error state
    func renderError(message: String) -> DisplayContent {
        return DisplayContent(
            header: centerText("! ERROR !"),
            line1: truncate(message),
            line2: "",
            footer: ""
        )
    }

    // MARK: - Helper Methods

    /// Truncate text to fit line length
    private func truncate(_ text: String) -> String {
        if text.count <= maxLineLength {
            return text
        }
        return String(text.prefix(maxLineLength - 2)) + ".."
    }

    /// Center text on the line
    private func centerText(_ text: String) -> String {
        let truncated = truncate(text)
        let padding = (maxLineLength - truncated.count) / 2
        let leftPad = String(repeating: " ", count: max(0, padding))
        return leftPad + truncated
    }

    /// Pad text to fill line
    private func padRight(_ text: String) -> String {
        let truncated = truncate(text)
        let padding = maxLineLength - truncated.count
        return truncated + String(repeating: " ", count: max(0, padding))
    }
}

// MARK: - Display Content

/// Complete display content for all lines
struct DisplayContent {
    let header: String
    let line1: String
    let line2: String
    let footer: String

    /// Check if content has changed from another
    func hasChanged(from other: DisplayContent) -> Bool {
        return header != other.header ||
               line1 != other.line1 ||
               line2 != other.line2 ||
               footer != other.footer
    }

    /// Get changed lines compared to another content
    func changedLines(from other: DisplayContent) -> [DisplayLine] {
        var changes: [DisplayLine] = []

        if header != other.header {
            changes.append(.header(header))
        }
        if line1 != other.line1 {
            changes.append(.line1(line1))
        }
        if line2 != other.line2 {
            changes.append(.line2(line2))
        }
        if footer != other.footer {
            changes.append(.footer(footer))
        }

        return changes
    }
}

/// Individual display line identifier
enum DisplayLine {
    case header(String)
    case line1(String)
    case line2(String)
    case footer(String)

    var text: String {
        switch self {
        case .header(let text), .line1(let text), .line2(let text), .footer(let text):
            return text
        }
    }
}

// MARK: - Animation Support

extension DisplayRenderer {
    /// Animated text scroll for long messages
    func scrollText(_ text: String, offset: Int) -> String {
        guard text.count > maxLineLength else { return text }

        let paddedText = text + "   " // Add spacing between scroll cycles
        let startIndex = offset % paddedText.count
        let endIndex = min(startIndex + maxLineLength, paddedText.count)

        var result = String(paddedText[paddedText.index(paddedText.startIndex, offsetBy: startIndex)..<paddedText.index(paddedText.startIndex, offsetBy: endIndex)])

        // Wrap around if needed
        if result.count < maxLineLength {
            let remaining = maxLineLength - result.count
            result += String(paddedText.prefix(remaining))
        }

        return result
    }

    /// Loading animation frames
    func loadingFrame(_ frame: Int) -> String {
        let frames = ["|", "/", "-", "\\"]
        return frames[frame % frames.count]
    }

    /// Progress bar rendering
    func progressBar(progress: Double) -> String {
        let barLength = maxLineLength - 4 // "[" + "]" + padding
        let filled = Int(Double(barLength) * min(1.0, max(0.0, progress)))
        let empty = barLength - filled

        let filledBar = String(repeating: "#", count: filled)
        let emptyBar = String(repeating: "-", count: empty)

        return "[\(filledBar)\(emptyBar)]"
    }
}
