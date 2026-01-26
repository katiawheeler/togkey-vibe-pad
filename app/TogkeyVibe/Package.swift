// swift-tools-version:5.9
// Package.swift
// Togkey Vibe - Swift Package Manager configuration

import PackageDescription

let package = Package(
    name: "TogkeyVibe",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "TogkeyVibe", targets: ["TogkeyVibe"])
    ],
    targets: [
        .executableTarget(
            name: "TogkeyVibe",
            path: ".",
            exclude: [
                "Package.swift",
                "project.yml",
                "Resources/Info.plist",
                "Resources/TogkeyVibe.entitlements",
                "Resources/Assets.xcassets"
            ],
            sources: [
                "App/TogkeyVibeApp.swift",
                "App/AppDelegate.swift",
                "Models/VibeMode.swift",
                "Models/ThinkLevel.swift",
                "Models/DeviceState.swift",
                "Services/HIDManager.swift",
                "Services/ClaudeCodeBridge.swift",
                "Services/VoiceModeService.swift",
                "Services/DisplayRenderer.swift",
                "Services/LEDController.swift",
                "Services/LaunchAtLoginService.swift",
                "Views/MenuBarView.swift",
                "Views/SettingsView.swift"
            ],
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("ServiceManagement")
            ]
        )
    ]
)
