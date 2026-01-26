// SettingsView.swift
// Togkey Vibe - Settings and configuration view

import SwiftUI

/// Settings window view
struct SettingsView: View {
    @ObservedObject var deviceState: DeviceState
    @AppStorage("launchAtLogin") private var launchAtLogin: Bool = false
    @AppStorage("showInDock") private var showInDock: Bool = false

    @State private var selectedTab: SettingsTab = .general

    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsView(
                launchAtLogin: $launchAtLogin,
                showInDock: $showInDock
            )
            .tabItem {
                Label("General", systemImage: "gear")
            }
            .tag(SettingsTab.general)

            KeyMappingView()
                .tabItem {
                    Label("Keys", systemImage: "keyboard")
                }
                .tag(SettingsTab.keys)

            VoiceSettingsView()
                .tabItem {
                    Label("Voice", systemImage: "mic")
                }
                .tag(SettingsTab.voice)

            DeviceSettingsView(deviceState: deviceState)
                .tabItem {
                    Label("Device", systemImage: "cpu")
                }
                .tag(SettingsTab.device)

            AboutView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
                .tag(SettingsTab.about)
        }
        .frame(width: 520, height: 450)
    }

    enum SettingsTab {
        case general
        case keys
        case voice
        case device
        case about
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @Binding var launchAtLogin: Bool
    @Binding var showInDock: Bool
    @StateObject private var launchService = LaunchAtLoginService()
    @AppStorage("defaultMode") private var defaultMode: Int = 0
    @AppStorage("claudeCliPath") private var claudeCliPath: String = "/usr/local/bin/claude"
    @AppStorage("longPressDuration") private var longPressDuration: Double = 500
    @AppStorage("ledBrightness") private var ledBrightness: Double = 0.8

    var body: some View {
        Form {
            Section {
                Toggle("Launch at Login", isOn: Binding(
                    get: { launchService.isEnabled },
                    set: { _ = launchService.setEnabled($0) }
                ))
                Toggle("Show in Dock", isOn: $showInDock)
                    .onChange(of: showInDock) { newValue in
                        NSApp.setActivationPolicy(newValue ? .regular : .accessory)
                    }
            } header: {
                Text("Startup")
            }

            Section {
                HStack {
                    Text("Claude CLI Path")
                    Spacer()
                    TextField("/usr/local/bin/claude", text: $claudeCliPath)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 200)
                }

                HStack {
                    Text("Default Mode")
                    Spacer()
                    Picker("", selection: $defaultMode) {
                        ForEach(VibeMode.allCases) { mode in
                            Text(mode.displayName).tag(mode.rawValue)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 150)
                }
            } header: {
                Text("Claude Code")
            }

            Section {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Long Press Duration")
                        Spacer()
                        Text("\(Int(longPressDuration))ms")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $longPressDuration, in: 200...1000, step: 50)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("LED Brightness")
                        Spacer()
                        Text("\(Int(ledBrightness * 100))%")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $ledBrightness, in: 0.1...1.0, step: 0.1)
                }
            } header: {
                Text("Hardware")
            }

            Section {
                HStack {
                    Text("Accessibility")
                    Spacer()
                    if AXIsProcessTrusted() {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Granted")
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Button("Request Access") {
                            requestAccessibilityPermission()
                        }
                    }
                }

                Text("Accessibility permission is required for keyboard simulation (sending commands to Claude Code).")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("Permissions")
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func requestAccessibilityPermission() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options)
    }
}

// MARK: - Key Mapping

struct KeyMappingView: View {
    var body: some View {
        Form {
            Section {
                KeyMappingRow(
                    keyName: "Key 1",
                    action: "Think Cycle",
                    description: "Cycle through thinking levels"
                )
                KeyMappingRow(
                    keyName: "Key 2",
                    action: "/clear",
                    description: "Clear conversation context"
                )
                KeyMappingRow(
                    keyName: "Key 3",
                    action: "/undo",
                    description: "Undo last file change"
                )
            } header: {
                Text("Top Row")
            }

            Section {
                KeyMappingRow(
                    keyName: "Key 4",
                    action: "/resume",
                    description: "Resume interrupted task"
                )
                KeyMappingRow(
                    keyName: "Key 5",
                    action: "/commit (long: /pr)",
                    description: "Git commit or pull request"
                )
                KeyMappingRow(
                    keyName: "Key 6",
                    action: "Escape / Ctrl+C",
                    description: "Stop current operation"
                )
            } header: {
                Text("Bottom Row")
            }

            Section {
                KeyMappingRow(
                    keyName: "Encoder Push",
                    action: "Toggle STT",
                    description: "Toggle voice mode"
                )
                KeyMappingRow(
                    keyName: "Encoder CW",
                    action: "Next Mode",
                    description: "Cycle to next Claude mode"
                )
                KeyMappingRow(
                    keyName: "Encoder CCW",
                    action: "Previous Mode",
                    description: "Cycle to previous mode"
                )
            } header: {
                Text("Encoder")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct KeyMappingRow: View {
    let keyName: String
    let action: String
    let description: String

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(keyName)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(action)
                .font(.system(.body, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.2))
                .cornerRadius(4)
        }
    }
}

// MARK: - Device Settings

struct DeviceSettingsView: View {
    @ObservedObject var deviceState: DeviceState
    @AppStorage("deviceVendorID") private var vendorID: Int = 0xFEED
    @AppStorage("deviceProductID") private var productID: Int = 0x0000
    @State private var vendorIDText: String = ""
    @State private var productIDText: String = ""

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Status")
                    Spacer()
                    HStack {
                        Circle()
                            .fill(deviceState.connectionState.isConnected ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        Text(deviceState.connectionState.displayText)
                    }
                }

                if case .connected(let version) = deviceState.connectionState {
                    HStack {
                        Text("Firmware Version")
                        Spacer()
                        Text(version)
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("Connection")
            }

            Section {
                HStack {
                    Text("Vendor ID (VID)")
                    Spacer()
                    TextField("0xFEED", text: $vendorIDText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                        .onAppear {
                            vendorIDText = String(format: "0x%04X", vendorID)
                        }
                        .onChange(of: vendorIDText) { newValue in
                            if let value = parseHexOrDecimal(newValue) {
                                vendorID = value
                            }
                        }
                }

                HStack {
                    Text("Product ID (PID)")
                    Spacer()
                    TextField("0x0000", text: $productIDText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                        .onAppear {
                            productIDText = String(format: "0x%04X", productID)
                        }
                        .onChange(of: productIDText) { newValue in
                            if let value = parseHexOrDecimal(newValue) {
                                productID = value
                            }
                        }
                }

                Text("Find your device's VID/PID in System Information > USB\nor run: ioreg -p IOUSB -l | grep -E \"(Vendor|Product)\"")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("Device Identification")
            }

            Section {
                HStack {
                    Text("Current Color")
                    Spacer()
                    Circle()
                        .fill(deviceState.currentLEDColor.swiftUIColor)
                        .frame(width: 20, height: 20)
                        .overlay(
                            Circle()
                                .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                        )
                }

                HStack {
                    Text("Pattern")
                    Spacer()
                    Text(deviceState.currentLEDPattern.description)
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("LED Status")
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Display Preview")
                    DisplayPreviewBox(state: deviceState)
                }
            } header: {
                Text("Display")
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func parseHexOrDecimal(_ string: String) -> Int? {
        let trimmed = string.trimmingCharacters(in: .whitespaces)
        if trimmed.lowercased().hasPrefix("0x") {
            let hexPart = String(trimmed.dropFirst(2))
            return Int(hexPart, radix: 16)
        } else {
            return Int(trimmed)
        }
    }
}

struct DisplayPreviewBox: View {
    @ObservedObject var state: DeviceState

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(state.displayHeader.isEmpty ? "MODE: ASK      [ ]" : state.displayHeader)
            Text(state.displayLine1.isEmpty ? " " : state.displayLine1)
            Text(state.displayLine2.isEmpty ? " " : state.displayLine2)
            Text(state.displayFooter.isEmpty ? "Ready" : state.displayFooter)
        }
        .font(.system(size: 11, design: .monospaced))
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black)
        .foregroundColor(Color.green)
        .cornerRadius(4)
    }
}

// MARK: - Voice Settings

struct VoiceSettingsView: View {
    @AppStorage("voicemode.vadAggressiveness") private var vadAggressiveness: Int = 2
    @AppStorage("voicemode.listenDurationMax") private var listenDurationMax: Double = 120
    @AppStorage("voicemode.listenDurationMin") private var listenDurationMin: Double = 2.0
    @AppStorage("voicemode.chimeEnabled") private var chimeEnabled: Bool = true
    @AppStorage("voicemode.host") private var voicemodeHost: String = "localhost"
    @AppStorage("voicemode.port") private var voicemodePort: Int = 8766

    @State private var serverStatus: VoiceModeService.ServerStatus = .unknown
    @State private var isCheckingStatus: Bool = false

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Server Status")
                    Spacer()
                    HStack(spacing: 6) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 8, height: 8)
                        Text(serverStatus.rawValue.capitalized)
                            .foregroundColor(.secondary)
                    }
                }

                HStack {
                    Text("Host")
                    Spacer()
                    TextField("localhost", text: $voicemodeHost)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 150)
                }

                HStack {
                    Text("Port")
                    Spacer()
                    TextField("8766", value: $voicemodePort, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                }

                HStack {
                    Button("Check Status") {
                        checkServerStatus()
                    }
                    .disabled(isCheckingStatus)

                    if serverStatus == .stopped {
                        Button("Start Server") {
                            startServer()
                        }
                    }
                }
            } header: {
                Text("Voicemode Server")
            }

            Section {
                HStack {
                    Text("VAD Aggressiveness")
                    Spacer()
                    Picker("", selection: $vadAggressiveness) {
                        Text("0 - Permissive").tag(0)
                        Text("1 - Low").tag(1)
                        Text("2 - Medium").tag(2)
                        Text("3 - Strict").tag(3)
                    }
                    .labelsHidden()
                    .frame(width: 140)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Max Listen Duration")
                        Spacer()
                        Text("\(Int(listenDurationMax))s")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $listenDurationMax, in: 10...300, step: 10)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Min Listen Duration")
                        Spacer()
                        Text("\(String(format: "%.1f", listenDurationMin))s")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $listenDurationMin, in: 0.5...10, step: 0.5)
                }

                Toggle("Audio Chimes", isOn: $chimeEnabled)
            } header: {
                Text("Voice Detection")
            }

            Section {
                Text("Press the encoder button or Key 6 (with STT configured) to toggle voice input. The LED will pulse purple when listening.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Link("Voicemode Documentation", destination: URL(string: "https://github.com/anthropics/claude-code")!)
                    .font(.caption)
            } header: {
                Text("Usage")
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            checkServerStatus()
        }
    }

    private var statusColor: Color {
        switch serverStatus {
        case .running: return .green
        case .stopped: return .red
        case .starting: return .yellow
        case .error: return .orange
        case .unknown: return .gray
        }
    }

    private func checkServerStatus() {
        isCheckingStatus = true
        Task {
            let service = VoiceModeService(host: voicemodeHost, port: voicemodePort)
            service.checkServerStatus()
            try? await Task.sleep(nanoseconds: 500_000_000)
            await MainActor.run {
                serverStatus = service.serverStatus
                isCheckingStatus = false
            }
        }
    }

    private func startServer() {
        let service = VoiceModeService(host: voicemodeHost, port: voicemodePort)
        service.startServer()
        serverStatus = .starting
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            checkServerStatus()
        }
    }
}

// MARK: - About

struct AboutView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "keyboard.badge.ellipsis")
                .font(.system(size: 64))
                .foregroundColor(.accentColor)

            VStack(spacing: 4) {
                Text("Togkey Vibe")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Version 1.0.0")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Text("The ultimate vibe coding companion for Claude Code CLI")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            Divider()
                .padding(.horizontal, 40)

            VStack(spacing: 8) {
                Link("Togkey Pad Plus", destination: URL(string: "https://togkey.com/products/togkey-pad-plus-custom-qmk-macropad")!)

                Link("Claude Code Documentation", destination: URL(string: "https://docs.anthropic.com/en/docs/claude-code")!)

                Link("QMK Firmware", destination: URL(string: "https://docs.qmk.fm/")!)
            }
            .font(.subheadline)

            Spacer()

            Text("Made with vibes")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(40)
    }
}

// MARK: - Preview

#Preview {
    SettingsView(deviceState: DeviceState())
}
