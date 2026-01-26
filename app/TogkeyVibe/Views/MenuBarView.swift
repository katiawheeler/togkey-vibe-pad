// MenuBarView.swift
// Togkey Vibe - Menu bar popover view

import SwiftUI

/// Main menu bar popover view
struct MenuBarView: View {
    @ObservedObject var deviceState: DeviceState
    @ObservedObject var hidManager: HIDManager

    var onOpenSettings: () -> Void
    var onQuit: () -> Void
    var onModeChange: ((VibeMode) -> Void)?
    var onThinkLevelChange: ((ThinkLevel) -> Void)?
    var onSTTToggle: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            headerSection

            Divider()

            connectionSection

            if deviceState.connectionState.isConnected {
                Divider()

                modeSection

                Divider()

                thinkSection

                Divider()

                sttSection

                if !deviceState.lastAction.isEmpty {
                    Divider()
                    lastActionSection
                }

                Divider()

                quickActionsSection
            }

            Divider()

            actionsSection
        }
        .padding(12)
        .frame(width: 300)
    }

    // MARK: - Sections

    private var headerSection: some View {
        HStack {
            Image(systemName: "keyboard")
                .font(.title2)
                .foregroundColor(.accentColor)

            VStack(alignment: .leading) {
                Text("Togkey Vibe")
                    .font(.headline)
                Text("Claude Code Controller")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }

    private var connectionSection: some View {
        HStack {
            Circle()
                .fill(connectionColor)
                .frame(width: 8, height: 8)

            Text(deviceState.connectionState.displayText)
                .font(.subheadline)

            Spacer()

            if case .connected = deviceState.connectionState {
                Text("v\(hidManager.firmwareVersion)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var connectionColor: Color {
        switch deviceState.connectionState {
        case .disconnected:
            return .red
        case .connecting:
            return .yellow
        case .connected:
            return .green
        }
    }

    private var modeSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Mode")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                if onModeChange != nil {
                    Text("Click to change")
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.7))
                }
            }

            HStack(spacing: 8) {
                ForEach(VibeMode.allCases) { mode in
                    ModeButton(
                        mode: mode,
                        isSelected: deviceState.currentMode == mode,
                        onSelect: {
                            onModeChange?(mode)
                        }
                    )
                }
            }
        }
    }

    private var thinkSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Think Level")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 8) {
                ForEach(ThinkLevel.allCases) { level in
                    ThinkLevelButton(
                        level: level,
                        isSelected: deviceState.thinkLevel == level,
                        onSelect: {
                            onThinkLevelChange?(level)
                        }
                    )
                }
            }
        }
    }

    private var sttSection: some View {
        Button(action: {
            onSTTToggle?()
        }) {
            HStack {
                Image(systemName: deviceState.sttEnabled ? "mic.fill" : "mic.slash")
                    .foregroundColor(deviceState.sttEnabled ? .purple : .gray)
                    .frame(width: 20)

                Text(deviceState.sttEnabled ? "Voice Active" : "Voice Off")
                    .font(.subheadline)

                Spacer()

                if deviceState.sttEnabled {
                    HStack(spacing: 2) {
                        ForEach(0..<3) { i in
                            RoundedRectangle(cornerRadius: 1)
                                .fill(Color.purple)
                                .frame(width: 3, height: CGFloat(4 + i * 3))
                                .opacity(pulseOpacity)
                        }
                    }
                } else {
                    Text("Click to toggle")
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.7))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onAppear {
            startPulseAnimation()
        }
    }

    @State private var pulseOpacity: Double = 1.0

    private func startPulseAnimation() {
        guard deviceState.sttEnabled else { return }
        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
            pulseOpacity = 0.4
        }
    }

    private var lastActionSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Last Action")
                .font(.caption)
                .foregroundColor(.secondary)

            Text(deviceState.lastAction)
                .font(.subheadline)

            if let time = deviceState.lastActionTime {
                Text(timeAgo(time))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Quick Actions")
                .font(.caption)
                .foregroundColor(.secondary)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                QuickActionButton(
                    icon: "arrow.counterclockwise",
                    label: "Undo",
                    action: {}
                )
                QuickActionButton(
                    icon: "arrow.clockwise",
                    label: "Resume",
                    action: {}
                )
                QuickActionButton(
                    icon: "xmark.circle",
                    label: "Clear",
                    action: {}
                )
            }
        }
    }

    private var actionsSection: some View {
        VStack(spacing: 6) {
            Button(action: onOpenSettings) {
                HStack {
                    Image(systemName: "gear")
                        .frame(width: 16)
                    Text("Settings...")
                    Spacer()
                    Text("⌘,")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)

            Button(action: onQuit) {
                HStack {
                    Image(systemName: "power")
                        .frame(width: 16)
                    Text("Quit Togkey Vibe")
                    Spacer()
                    Text("⌘Q")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Helpers

    private func timeAgo(_ date: Date) -> String {
        let seconds = Int(-date.timeIntervalSinceNow)

        if seconds < 60 {
            return "just now"
        } else if seconds < 3600 {
            let minutes = seconds / 60
            return "\(minutes)m ago"
        } else {
            let hours = seconds / 3600
            return "\(hours)h ago"
        }
    }
}

// MARK: - Display Preview

struct DisplayPreview: View {
    let content: DisplayContent

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(content.header)
                .font(.system(.caption, design: .monospaced))
            Text(content.line1)
                .font(.system(.caption, design: .monospaced))
            Text(content.line2)
                .font(.system(.caption, design: .monospaced))
            Text(content.footer)
                .font(.system(.caption, design: .monospaced))
        }
        .padding(8)
        .background(Color.black)
        .foregroundColor(.green)
        .cornerRadius(4)
    }
}

// MARK: - LED Preview

struct LEDPreview: View {
    let color: LEDColor
    let pattern: LEDPattern

    @State private var animationPhase: CGFloat = 0

    var body: some View {
        Circle()
            .fill(color.swiftUIColor)
            .frame(width: 20, height: 20)
            .opacity(ledOpacity)
            .shadow(color: color.swiftUIColor.opacity(0.5), radius: 4)
            .onAppear {
                startAnimation()
            }
    }

    private var ledOpacity: Double {
        switch pattern {
        case .solid:
            return 1.0
        case .pulse:
            return 0.5 + 0.5 * sin(animationPhase * .pi * 2)
        case .breathe:
            return 0.3 + 0.7 * sin(animationPhase * .pi * 2)
        case .flash:
            return animationPhase > 0.5 ? 1.0 : 0.2
        }
    }

    private func startAnimation() {
        guard pattern != .solid else { return }

        let duration: TimeInterval
        switch pattern {
        case .pulse: duration = 1.0
        case .breathe: duration = 3.0
        case .flash: duration = 0.2
        default: duration = 1.0
        }

        withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
            animationPhase = 1.0
        }
    }
}

// MARK: - Mode Button

struct ModeButton: View {
    let mode: VibeMode
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 4) {
                Image(systemName: mode.iconName)
                    .font(.system(size: 16))
                    .foregroundColor(isSelected ? mode.color : .gray)

                Text(mode.shortName)
                    .font(.caption2)
                    .foregroundColor(isSelected ? .primary : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(isSelected ? mode.color.opacity(0.15) : Color.clear)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? mode.color : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Think Level Button

struct ThinkLevelButton: View {
    let level: ThinkLevel
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 2) {
                HStack(spacing: 1) {
                    ForEach(0..<3) { i in
                        Image(systemName: i < level.brainCount ? "brain.fill" : "brain")
                            .font(.system(size: 8))
                            .foregroundColor(i < level.brainCount ? level.color : .gray.opacity(0.4))
                    }
                }

                Text(level.shortDisplay)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(isSelected ? .primary : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 5)
            .background(isSelected ? level.color.opacity(0.15) : Color.clear)
            .cornerRadius(5)
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(isSelected ? level.color : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Quick Action Button

struct QuickActionButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text(label)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    MenuBarView(
        deviceState: {
            let state = DeviceState()
            state.connectionState = .connected(firmwareVersion: "1.0.0")
            state.currentMode = .acceptAll
            state.thinkLevel = .medium
            state.sttEnabled = true
            state.lastAction = "/commit"
            state.lastActionTime = Date()
            return state
        }(),
        hidManager: HIDManager(),
        onOpenSettings: {},
        onQuit: {},
        onModeChange: { _ in },
        onThinkLevelChange: { _ in },
        onSTTToggle: {}
    )
}
