// TogkeyVibeApp.swift
// Togkey Vibe - Main application entry point

import SwiftUI

@main
struct TogkeyVibeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView(deviceState: appDelegate.deviceState)
        }

        MenuBarExtra {
            MenuBarView(
                deviceState: appDelegate.deviceState,
                hidManager: appDelegate.hidManager,
                onOpenSettings: {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                },
                onQuit: {
                    NSApplication.shared.terminate(nil)
                },
                onModeChange: { mode in
                    appDelegate.setMode(mode)
                },
                onThinkLevelChange: { level in
                    appDelegate.setThinkLevel(level)
                },
                onSTTToggle: {
                    appDelegate.toggleSTT()
                }
            )
        } label: {
            menuBarIcon
        }
        .menuBarExtraStyle(.window)
    }

    private var menuBarIcon: some View {
        HStack(spacing: 4) {
            Image(systemName: appDelegate.deviceState.connectionState.isConnected ?
                  appDelegate.deviceState.currentMode.iconName : "keyboard")
                .symbolRenderingMode(.hierarchical)
                .foregroundColor(appDelegate.deviceState.connectionState.isConnected ?
                               appDelegate.deviceState.currentMode.color : .gray)

            if appDelegate.deviceState.sttEnabled {
                Image(systemName: "mic.fill")
                    .font(.system(size: 8))
                    .foregroundColor(.purple)
            }
        }
    }
}
