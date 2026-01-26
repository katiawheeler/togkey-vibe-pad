// ThinkLevel.swift
// Togkey Vibe - Claude Code thinking level definitions

import SwiftUI

/// Claude Code thinking depth levels
enum ThinkLevel: Int, CaseIterable, Identifiable {
    case off = 0
    case lite = 1
    case medium = 2
    case hard = 3

    var id: Int { rawValue }

    /// Display name
    var displayName: String {
        switch self {
        case .off: return "Off"
        case .lite: return "Lite"
        case .medium: return "Medium"
        case .hard: return "Hard"
        }
    }

    /// Short display for header
    var shortDisplay: String {
        switch self {
        case .off: return "OFF"
        case .lite: return "LITE"
        case .medium: return "MED"
        case .hard: return "HARD"
        }
    }

    /// Description of thinking level
    var description: String {
        switch self {
        case .off: return "Normal prompts, no thinking prefix"
        case .lite: return "Light analysis, quick thinking"
        case .medium: return "Step-by-step reasoning"
        case .hard: return "Deep analysis, ultrathink mode"
        }
    }

    /// Icon for display
    var icon: String {
        switch self {
        case .off: return "brain"
        case .lite: return "brain"
        case .medium: return "brain.head.profile"
        case .hard: return "brain.fill"
        }
    }

    /// Color for UI
    var color: Color {
        switch self {
        case .off: return .gray
        case .lite: return .blue
        case .medium: return .purple
        case .hard: return .orange
        }
    }

    /// Prefix to add to prompts
    var promptPrefix: String? {
        switch self {
        case .off: return nil
        case .lite: return "think about"
        case .medium: return "think step by step"
        case .hard: return "ultrathink"
        }
    }

    /// Next level in cycle
    var next: ThinkLevel {
        let nextIndex = (rawValue + 1) % ThinkLevel.allCases.count
        return ThinkLevel(rawValue: nextIndex) ?? .off
    }

    /// Number of brain icons to show (0-3)
    var brainCount: Int {
        return rawValue
    }
}
