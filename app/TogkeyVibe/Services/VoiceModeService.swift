// VoiceModeService.swift
// Togkey Vibe - Voice mode (STT) control service

import Foundation
import Combine

/// Service for controlling voice mode / speech-to-text functionality
/// Integrates with the voicemode MCP server for actual STT processing
final class VoiceModeService: ObservableObject {
    // MARK: - Properties

    @Published private(set) var isListening: Bool = false
    @Published private(set) var isAvailable: Bool = false
    @Published private(set) var lastTranscription: String = ""
    @Published private(set) var lastError: String? = nil
    @Published private(set) var serverStatus: ServerStatus = .unknown

    enum ServerStatus: String {
        case unknown = "unknown"
        case running = "running"
        case stopped = "stopped"
        case starting = "starting"
        case error = "error"
    }

    private var statusCheckTimer: Timer?
    private var urlSession: URLSession
    private let mcpServerHost: String
    private let mcpServerPort: Int

    // Configuration
    private(set) var configuration: Configuration

    // MARK: - Initialization

    init(
        host: String = "localhost",
        port: Int = 8766,
        configuration: Configuration = .default
    ) {
        self.mcpServerHost = host
        self.mcpServerPort = port
        self.configuration = configuration

        // Configure URL session with timeout
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5.0
        config.timeoutIntervalForResource = 10.0
        self.urlSession = URLSession(configuration: config)

        checkServerStatus()
        startStatusMonitor()
    }

    deinit {
        stop()
    }

    /// Stop monitoring and clean up resources
    func stop() {
        statusCheckTimer?.invalidate()
        statusCheckTimer = nil
        urlSession.invalidateAndCancel()
    }

    // MARK: - Public Methods

    /// Toggle voice listening on/off
    func toggle() {
        if isListening {
            stopListening()
        } else {
            startListening()
        }
    }

    /// Start voice listening via voicemode MCP
    func startListening() {
        guard isAvailable else {
            lastError = "Voice mode is not available. Ensure voicemode server is running."
            return
        }

        lastError = nil

        Task {
            do {
                let success = try await sendListenCommand(listen: true)
                await MainActor.run {
                    if success {
                        self.isListening = true
                        self.notifyVoiceModeStart()
                    } else {
                        self.lastError = "Failed to start voice listening"
                    }
                }
            } catch {
                await MainActor.run {
                    self.lastError = "Error starting voice mode: \(error.localizedDescription)"
                }
            }
        }
    }

    /// Stop voice listening
    func stopListening() {
        Task {
            do {
                _ = try await sendListenCommand(listen: false)
                await MainActor.run {
                    self.isListening = false
                    self.notifyVoiceModeStop()
                }
            } catch {
                await MainActor.run {
                    self.isListening = false // Stop locally even if server fails
                    self.lastError = "Error stopping voice mode: \(error.localizedDescription)"
                }
            }
        }
    }

    /// Update configuration
    func updateConfiguration(_ newConfig: Configuration) {
        configuration = newConfig
        // Persist to UserDefaults
        saveConfiguration()
    }

    /// Check and update server status
    func checkServerStatus() {
        Task {
            let status = await checkVoiceModeServerStatus()
            await MainActor.run {
                self.serverStatus = status
                self.isAvailable = (status == .running)
            }
        }
    }

    /// Start the voicemode server if not running
    func startServer() {
        Task {
            await MainActor.run {
                self.serverStatus = .starting
            }

            let success = await launchVoiceModeServer()

            await MainActor.run { [weak self] in
                guard let self = self else { return }
                if success {
                    // Give server time to start, then check status
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                        self?.checkServerStatus()
                    }
                } else {
                    self.serverStatus = .error
                    self.lastError = "Failed to start voicemode server"
                }
            }
        }
    }

    // MARK: - Private Methods - Server Communication

    private var mcpBaseURL: URL {
        URL(string: "http://\(mcpServerHost):\(mcpServerPort)")!
    }

    /// Send listen command to voicemode MCP server
    private func sendListenCommand(listen: Bool) async throws -> Bool {
        // The voicemode MCP server uses JSON-RPC over HTTP
        // We need to call the 'converse' tool with appropriate parameters

        let arguments: [String: AnyCodable] = [
            "message": AnyCodable(listen ? "Starting voice input mode" : "Stopping voice input"),
            "wait_for_response": AnyCodable(listen),
            "listen_duration_max": AnyCodable(configuration.listenDurationMax),
            "listen_duration_min": AnyCodable(configuration.listenDurationMin),
            "vad_aggressiveness": AnyCodable(configuration.vadAggressiveness),
            "chime_enabled": AnyCodable(configuration.chimeEnabled),
            "skip_tts": AnyCodable(!listen)
        ]

        let request = MCPRequest(
            jsonrpc: "2.0",
            id: UUID().uuidString,
            method: "tools/call",
            params: MCPToolCallParams(
                name: "converse",
                arguments: arguments
            )
        )

        var urlRequest = URLRequest(url: mcpBaseURL.appendingPathComponent("mcp"))
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)

        let (data, response) = try await urlSession.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            return false
        }

        if httpResponse.statusCode == 200 {
            // Parse response for transcription if listening
            if listen, let mcpResponse = try? JSONDecoder().decode(MCPResponse.self, from: data) {
                if let transcription = mcpResponse.result?.content?.first?.text {
                    await MainActor.run {
                        self.handleTranscription(transcription)
                    }
                }
            }
            return true
        }

        return false
    }

    /// Check if voicemode server is responding
    private func checkVoiceModeServerStatus() async -> ServerStatus {
        // First check if the process is running
        let processRunning = await isVoiceModeProcessRunning()

        if !processRunning {
            return .stopped
        }

        // Then try to ping the HTTP endpoint
        do {
            var request = URLRequest(url: mcpBaseURL.appendingPathComponent("health"))
            request.httpMethod = "GET"
            request.timeoutInterval = 2.0

            let (_, response) = try await urlSession.data(for: request)

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                return .running
            }

            // Process running but not responding - might still be starting
            return .starting
        } catch {
            // Process running but HTTP not responding
            return processRunning ? .starting : .stopped
        }
    }

    /// Check if voicemode process is running
    private func isVoiceModeProcessRunning() async -> Bool {
        return await withCheckedContinuation { continuation in
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
            task.arguments = ["-f", "voicemode"]

            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = FileHandle.nullDevice

            do {
                try task.run()
                task.waitUntilExit()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""

                continuation.resume(returning: !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } catch {
                continuation.resume(returning: false)
            }
        }
    }

    /// Launch the voicemode MCP server
    private func launchVoiceModeServer() async -> Bool {
        return await withCheckedContinuation { continuation in
            let task = Process()

            // Try multiple possible locations for voicemode
            let possiblePaths = [
                "/usr/local/bin/voicemode",
                "/opt/homebrew/bin/voicemode",
                "\(NSHomeDirectory())/.local/bin/voicemode",
                "\(NSHomeDirectory())/bin/voicemode"
            ]

            var foundPath: String?
            for path in possiblePaths {
                if FileManager.default.fileExists(atPath: path) {
                    foundPath = path
                    break
                }
            }

            guard let voicemodePath = foundPath else {
                // Try using shell to find it
                task.executableURL = URL(fileURLWithPath: "/bin/zsh")
                task.arguments = ["-lc", "which voicemode && voicemode serve --port \(mcpServerPort) &"]

                do {
                    try task.run()
                    continuation.resume(returning: true)
                } catch {
                    continuation.resume(returning: false)
                }
                return
            }

            task.executableURL = URL(fileURLWithPath: voicemodePath)
            task.arguments = ["serve", "--port", String(mcpServerPort)]

            // Run in background
            task.standardOutput = FileHandle.nullDevice
            task.standardError = FileHandle.nullDevice

            do {
                try task.run()
                continuation.resume(returning: true)
            } catch {
                continuation.resume(returning: false)
            }
        }
    }

    private func notifyVoiceModeStart() {
        NotificationCenter.default.post(
            name: .voiceModeDidStart,
            object: nil,
            userInfo: ["configuration": configuration]
        )
    }

    private func notifyVoiceModeStop() {
        NotificationCenter.default.post(
            name: .voiceModeDidStop,
            object: nil
        )
    }

    private func startStatusMonitor() {
        statusCheckTimer?.invalidate()
        statusCheckTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.checkServerStatus()
        }
    }

    /// Handle transcription received from voicemode
    func handleTranscription(_ text: String) {
        lastTranscription = text

        NotificationCenter.default.post(
            name: .voiceModeDidReceiveTranscription,
            object: nil,
            userInfo: ["transcription": text]
        )
    }

    // MARK: - Configuration Persistence

    private func saveConfiguration() {
        let defaults = UserDefaults.standard
        defaults.set(configuration.vadAggressiveness, forKey: "voicemode.vadAggressiveness")
        defaults.set(configuration.listenDurationMax, forKey: "voicemode.listenDurationMax")
        defaults.set(configuration.listenDurationMin, forKey: "voicemode.listenDurationMin")
        defaults.set(configuration.chimeEnabled, forKey: "voicemode.chimeEnabled")
    }

    private func loadConfiguration() -> Configuration {
        let defaults = UserDefaults.standard
        return Configuration(
            vadAggressiveness: defaults.object(forKey: "voicemode.vadAggressiveness") as? Int ?? 2,
            listenDurationMax: defaults.object(forKey: "voicemode.listenDurationMax") as? TimeInterval ?? 120,
            listenDurationMin: defaults.object(forKey: "voicemode.listenDurationMin") as? TimeInterval ?? 2.0,
            chimeEnabled: defaults.object(forKey: "voicemode.chimeEnabled") as? Bool ?? true
        )
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let voiceModeDidStart = Notification.Name("voiceModeDidStart")
    static let voiceModeDidStop = Notification.Name("voiceModeDidStop")
    static let voiceModeDidReceiveTranscription = Notification.Name("voiceModeDidReceiveTranscription")
}

// MARK: - Voice Mode Configuration

extension VoiceModeService {
    /// Voice mode settings
    struct Configuration: Codable {
        var vadAggressiveness: Int
        var listenDurationMax: TimeInterval
        var listenDurationMin: TimeInterval
        var chimeEnabled: Bool

        static let `default` = Configuration(
            vadAggressiveness: 2,
            listenDurationMax: 120,
            listenDurationMin: 2.0,
            chimeEnabled: true
        )
    }
}

// MARK: - MCP Protocol Types

private struct MCPRequest: Codable {
    let jsonrpc: String
    let id: String
    let method: String
    let params: MCPToolCallParams
}

private struct MCPToolCallParams: Codable {
    let name: String
    let arguments: [String: AnyCodable]
}

private struct MCPResponse: Codable {
    let jsonrpc: String
    let id: String
    let result: MCPResult?
    let error: MCPError?
}

private struct MCPResult: Codable {
    let content: [MCPContent]?
}

private struct MCPContent: Codable {
    let type: String
    let text: String?
}

private struct MCPError: Codable {
    let code: Int
    let message: String
}

// Helper for encoding heterogeneous dictionaries
private struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intValue = try? container.decode(Int.self) {
            value = intValue
        } else if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
        } else if let boolValue = try? container.decode(Bool.self) {
            value = boolValue
        } else if let stringValue = try? container.decode(String.self) {
            value = stringValue
        } else {
            value = ""
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let intValue as Int:
            try container.encode(intValue)
        case let doubleValue as Double:
            try container.encode(doubleValue)
        case let boolValue as Bool:
            try container.encode(boolValue)
        case let stringValue as String:
            try container.encode(stringValue)
        default:
            try container.encode("")
        }
    }
}

