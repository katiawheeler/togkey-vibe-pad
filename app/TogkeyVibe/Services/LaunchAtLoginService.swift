// LaunchAtLoginService.swift
// Togkey Vibe - Launch at login functionality

import Foundation
import ServiceManagement

/// Manages launch at login functionality using SMAppService (macOS 13+)
final class LaunchAtLoginService: ObservableObject {
    @Published private(set) var isEnabled: Bool = false

    init() {
        updateStatus()
    }

    /// Check current launch at login status
    func updateStatus() {
        if #available(macOS 13.0, *) {
            isEnabled = SMAppService.mainApp.status == .enabled
        } else {
            isEnabled = false
        }
    }

    /// Enable launch at login
    func enable() -> Bool {
        if #available(macOS 13.0, *) {
            do {
                try SMAppService.mainApp.register()
                updateStatus()
                return true
            } catch {
                print("Failed to enable launch at login: \(error)")
                return false
            }
        }
        return false
    }

    /// Disable launch at login
    func disable() -> Bool {
        if #available(macOS 13.0, *) {
            do {
                try SMAppService.mainApp.unregister()
                updateStatus()
                return true
            } catch {
                print("Failed to disable launch at login: \(error)")
                return false
            }
        }
        return false
    }

    /// Toggle launch at login state
    func toggle() -> Bool {
        if isEnabled {
            return disable()
        } else {
            return enable()
        }
    }

    /// Set launch at login to a specific state
    func setEnabled(_ enabled: Bool) -> Bool {
        if enabled {
            return enable()
        } else {
            return disable()
        }
    }
}
