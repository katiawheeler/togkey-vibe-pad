// VibeMode.swift
// Togkey Vibe - Claude Code mode definitions

import SwiftUI

/// Claude Code CLI autoaccept modes
enum VibeMode: Int, CaseIterable, Identifiable {
    case ask = 0
    case plan = 1
    case acceptEdits = 2
    case acceptAll = 3

    var id: Int { rawValue }

    /// Display name for the mode
    var displayName: String {
        switch self {
        case .ask: return "Ask"
        case .plan: return "Plan"
        case .acceptEdits: return "Accept Edits"
        case .acceptAll: return "Accept All"
        }
    }

    /// Short name for display header
    var shortName: String {
        switch self {
        case .ask: return "ASK"
        case .plan: return "PLAN"
        case .acceptEdits: return "EDITS"
        case .acceptAll: return "VIBE"
        }
    }

    /// Description of the mode
    var description: String {
        switch self {
        case .ask: return "Ask for permission before each action"
        case .plan: return "Plan mode for architecture/design"
        case .acceptEdits: return "Auto-accept file edits only"
        case .acceptAll: return "Auto-accept all actions (full vibe)"
        }
    }

    /// LED color for this mode
    var ledColor: LEDColor {
        switch self {
        case .ask: return LEDColor(r: 66, g: 135, b: 245)      // Blue
        case .plan: return LEDColor(r: 245, g: 208, b: 66)    // Yellow
        case .acceptEdits: return LEDColor(r: 245, g: 152, b: 66) // Orange
        case .acceptAll: return LEDColor(r: 82, g: 196, b: 82)  // Green
        }
    }

    /// SwiftUI Color for UI display
    var color: Color {
        switch self {
        case .ask: return Color(red: 66/255, green: 135/255, blue: 245/255)
        case .plan: return Color(red: 245/255, green: 208/255, blue: 66/255)
        case .acceptEdits: return Color(red: 245/255, green: 152/255, blue: 66/255)
        case .acceptAll: return Color(red: 82/255, green: 196/255, blue: 82/255)
        }
    }

    /// Menu bar icon name
    var iconName: String {
        switch self {
        case .ask: return "questionmark.circle"
        case .plan: return "map"
        case .acceptEdits: return "pencil.circle"
        case .acceptAll: return "checkmark.circle.fill"
        }
    }

    /// Claude CLI flag for this mode
    var cliFlag: String? {
        switch self {
        case .ask: return nil  // Default, no flag needed
        case .plan: return "--plan"
        case .acceptEdits: return "--dangerously-skip-permissions"
        case .acceptAll: return "--dangerously-skip-permissions"
        }
    }

    /// Next mode in cycle (clockwise)
    var next: VibeMode {
        let nextIndex = (rawValue + 1) % VibeMode.allCases.count
        return VibeMode(rawValue: nextIndex) ?? .ask
    }

    /// Previous mode in cycle (counter-clockwise)
    var previous: VibeMode {
        let prevIndex = (rawValue - 1 + VibeMode.allCases.count) % VibeMode.allCases.count
        return VibeMode(rawValue: prevIndex) ?? .ask
    }
}

/// LED color representation for HID protocol
struct LEDColor: Equatable {
    let r: UInt8
    let g: UInt8
    let b: UInt8

    /// Predefined colors
    static let blue = LEDColor(r: 66, g: 135, b: 245)
    static let yellow = LEDColor(r: 245, g: 208, b: 66)
    static let orange = LEDColor(r: 245, g: 152, b: 66)
    static let green = LEDColor(r: 82, g: 196, b: 82)
    static let purple = LEDColor(r: 167, g: 66, b: 245)
    static let white = LEDColor(r: 255, g: 255, b: 255)
    static let red = LEDColor(r: 245, g: 66, b: 66)
    static let dimWhite = LEDColor(r: 64, g: 64, b: 64)

    /// Convert to SwiftUI Color
    var swiftUIColor: Color {
        Color(red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
    }
}

/// LED animation patterns
enum LEDPattern: UInt8 {
    case solid = 0
    case pulse = 1
    case breathe = 2
    case flash = 3

    var description: String {
        switch self {
        case .solid: return "Solid"
        case .pulse: return "Pulse"
        case .breathe: return "Breathe"
        case .flash: return "Flash"
        }
    }
}
