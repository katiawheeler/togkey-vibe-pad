// HIDManager.swift
// Togkey Vibe - HID device communication manager

import Foundation
import IOKit
import IOKit.hid
import Combine

/// Protocol for handling HID events
protocol HIDManagerDelegate: AnyObject {
    func hidManagerDidConnect(firmwareVersion: String)
    func hidManagerDidDisconnect()
    func hidManagerDidReceiveKeyEvent(keyIndex: KeyIndex, eventType: KeyEventType)
    func hidManagerDidReceiveEncoderEvent(direction: EncoderDirection, steps: UInt8)
    func hidManagerDidReceiveHeartbeat()
}

/// Manages HID communication with the Togkey Pad Plus
final class HIDManager: ObservableObject {
    // MARK: - Properties

    weak var delegate: HIDManagerDelegate?

    @Published private(set) var isConnected: Bool = false
    @Published private(set) var firmwareVersion: String = ""

    private var hidManager: IOHIDManager?
    private var connectedDevice: IOHIDDevice?
    private var heartbeatTimer: Timer?
    private var lastHeartbeatTime: Date?

    // Togkey Pad Plus identifiers
    // The actual VID/PID depends on your specific device
    // Common QMK VID/PID combinations:
    // - QMK default: VID=0xFEED
    // - Via enabled: varies by keyboard
    // - Togkey specific: check device info
    //
    // To find your device's VID/PID on macOS:
    // 1. Open System Information > USB
    // 2. Find your keyboard and note Vendor ID and Product ID
    // 3. Or run: ioreg -p IOUSB -l | grep -E "(Vendor|Product)"
    private var vendorID: Int = 0xFEED  // QMK default VID (update for your device)
    private var productID: Int = 0x0000 // Update with actual PID

    // Raw HID configuration (must match QMK config.h)
    private let reportSize: Int = 32
    private let usagePage: Int = 0xFF60  // Vendor-defined usage page
    private let usage: Int = 0x61        // Custom usage ID

    // Heartbeat timeout (10 seconds)
    private let heartbeatTimeout: TimeInterval = 10.0

    // MARK: - Initialization

    init() {
        loadDeviceSettings()
        setupHIDManager()
    }

    deinit {
        stop()
    }

    // MARK: - Configuration

    /// Configure the device VID/PID (call before start())
    func configure(vendorID: Int, productID: Int) {
        self.vendorID = vendorID
        self.productID = productID
        saveDeviceSettings()
    }

    private func loadDeviceSettings() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "deviceVendorID") != nil {
            vendorID = defaults.integer(forKey: "deviceVendorID")
        }
        if defaults.object(forKey: "deviceProductID") != nil {
            productID = defaults.integer(forKey: "deviceProductID")
        }
    }

    private func saveDeviceSettings() {
        let defaults = UserDefaults.standard
        defaults.set(vendorID, forKey: "deviceVendorID")
        defaults.set(productID, forKey: "deviceProductID")
    }

    // MARK: - Public Methods

    /// Start scanning for devices
    func start() {
        guard let manager = hidManager else { return }

        // Set up device matching criteria
        // Always match on usage page and usage ID for raw HID
        var matchingDict: [String: Any] = [
            kIOHIDDeviceUsagePageKey: usagePage,
            kIOHIDDeviceUsageKey: usage
        ]

        // Add VID/PID filtering if configured (non-zero values)
        if vendorID != 0 {
            matchingDict[kIOHIDVendorIDKey] = vendorID
        }
        if productID != 0 {
            matchingDict[kIOHIDProductIDKey] = productID
        }

        IOHIDManagerSetDeviceMatching(manager, matchingDict as CFDictionary)

        // Open the HID manager
        let result = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        if result != kIOReturnSuccess {
            print("Failed to open HID manager: \(result)")
            return
        }

        // Schedule with run loop
        IOHIDManagerScheduleWithRunLoop(
            manager,
            CFRunLoopGetMain(),
            CFRunLoopMode.defaultMode.rawValue
        )

        // Start heartbeat monitoring
        startHeartbeatMonitor()
    }

    /// Stop scanning and disconnect
    func stop() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil

        if let manager = hidManager {
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
            IOHIDManagerUnscheduleFromRunLoop(
                manager,
                CFRunLoopGetMain(),
                CFRunLoopMode.defaultMode.rawValue
            )
        }

        connectedDevice = nil
        isConnected = false
    }

    // MARK: - Send Commands

    /// Send LED color command
    func sendLEDColor(_ color: LEDColor) {
        var report = createReport(command: .setLEDColor, payloadLength: 3)
        report[2] = color.r
        report[3] = color.g
        report[4] = color.b
        sendReport(report)
    }

    /// Send LED pattern command
    func sendLEDPattern(_ pattern: LEDPattern, speed: UInt8 = 128) {
        var report = createReport(command: .setLEDPattern, payloadLength: 2)
        report[2] = pattern.rawValue
        report[3] = speed
        sendReport(report)
    }

    /// Send display header update
    func sendDisplayHeader(_ text: String) {
        sendDisplayLine(command: .displayHeader, text: text)
    }

    /// Send display line 1 update
    func sendDisplayLine1(_ text: String) {
        sendDisplayLine(command: .displayLine1, text: text)
    }

    /// Send display line 2 update
    func sendDisplayLine2(_ text: String) {
        sendDisplayLine(command: .displayLine2, text: text)
    }

    /// Send display footer update
    func sendDisplayFooter(_ text: String) {
        sendDisplayLine(command: .displayFooter, text: text)
    }

    /// Send display icon
    func sendDisplayIcon(_ icon: DisplayIcon, x: UInt8, y: UInt8) {
        var report = createReport(command: .displayIcon, payloadLength: 3)
        report[2] = icon.rawValue
        report[3] = x
        report[4] = y
        sendReport(report)
    }

    /// Send heartbeat response
    func sendHeartbeatResponse() {
        let report = createReport(command: .pingResponse, payloadLength: 0)
        sendReport(report)
    }

    // MARK: - Private Methods

    private func setupHIDManager() {
        hidManager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))

        guard let manager = hidManager else {
            print("Failed to create HID manager")
            return
        }

        // Set up callbacks
        let context = Unmanaged.passUnretained(self).toOpaque()

        IOHIDManagerRegisterDeviceMatchingCallback(manager, { context, result, sender, device in
            guard let context = context else { return }
            let manager = Unmanaged<HIDManager>.fromOpaque(context).takeUnretainedValue()
            manager.deviceConnected(device)
        }, context)

        IOHIDManagerRegisterDeviceRemovalCallback(manager, { context, result, sender, device in
            guard let context = context else { return }
            let manager = Unmanaged<HIDManager>.fromOpaque(context).takeUnretainedValue()
            manager.deviceDisconnected(device)
        }, context)

        IOHIDManagerRegisterInputReportCallback(manager, { context, result, sender, type, reportID, report, reportLength in
            guard let context = context else { return }
            let manager = Unmanaged<HIDManager>.fromOpaque(context).takeUnretainedValue()
            let data = Data(bytes: report, count: reportLength)
            manager.handleInputReport(data)
        }, context)
    }

    private func deviceConnected(_ device: IOHIDDevice) {
        // Extract device info for logging and validation
        let deviceInfo = extractDeviceInfo(device)
        print("HID device connected: \(deviceInfo.productName ?? "Unknown") (VID:\(String(format: "0x%04X", deviceInfo.vendorID)), PID:\(String(format: "0x%04X", deviceInfo.productID)))")

        // If VID/PID filtering is enabled, validate the device
        if vendorID != 0 && deviceInfo.vendorID != vendorID {
            print("Device VID mismatch, ignoring device")
            return
        }
        if productID != 0 && deviceInfo.productID != productID {
            print("Device PID mismatch, ignoring device")
            return
        }

        connectedDevice = device
        isConnected = true

        // The firmware will send a device ready message with version
    }

    /// Device info structure
    struct DeviceInfo {
        let vendorID: Int
        let productID: Int
        let productName: String?
        let manufacturerName: String?
        let serialNumber: String?
    }

    /// Extract device information from IOHIDDevice
    private func extractDeviceInfo(_ device: IOHIDDevice) -> DeviceInfo {
        let vendorID = IOHIDDeviceGetProperty(device, kIOHIDVendorIDKey as CFString) as? Int ?? 0
        let productID = IOHIDDeviceGetProperty(device, kIOHIDProductIDKey as CFString) as? Int ?? 0
        let productName = IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String
        let manufacturerName = IOHIDDeviceGetProperty(device, kIOHIDManufacturerKey as CFString) as? String
        let serialNumber = IOHIDDeviceGetProperty(device, kIOHIDSerialNumberKey as CFString) as? String

        return DeviceInfo(
            vendorID: vendorID,
            productID: productID,
            productName: productName,
            manufacturerName: manufacturerName,
            serialNumber: serialNumber
        )
    }

    /// Get connected device info (if connected)
    func getConnectedDeviceInfo() -> DeviceInfo? {
        guard let device = connectedDevice else { return nil }
        return extractDeviceInfo(device)
    }

    private func deviceDisconnected(_ device: IOHIDDevice) {
        if connectedDevice === device {
            connectedDevice = nil
            isConnected = false
            firmwareVersion = ""
            print("HID device disconnected")

            DispatchQueue.main.async { [weak self] in
                self?.delegate?.hidManagerDidDisconnect()
            }
        }
    }

    private func handleInputReport(_ data: Data) {
        guard data.count >= 2 else { return }

        let command = data[0]
        _ = data[1]  // payloadLength - used for validation if needed

        guard let cmd = HIDCommand(rawValue: command) else {
            print("Unknown HID command: \(command)")
            return
        }

        switch cmd {
        case .keyEvent:
            handleKeyEvent(data)
        case .encoderEvent:
            handleEncoderEvent(data)
        case .deviceReady:
            handleDeviceReady(data)
        case .heartbeat:
            handleHeartbeat()
        default:
            break
        }
    }

    private func handleKeyEvent(_ data: Data) {
        guard data.count >= 4 else { return }

        let keyIndexRaw = data[2]
        let eventTypeRaw = data[3]

        guard let keyIndex = KeyIndex(rawValue: keyIndexRaw),
              let eventType = KeyEventType(rawValue: eventTypeRaw) else {
            return
        }

        DispatchQueue.main.async { [weak self] in
            self?.delegate?.hidManagerDidReceiveKeyEvent(keyIndex: keyIndex, eventType: eventType)
        }
    }

    private func handleEncoderEvent(_ data: Data) {
        guard data.count >= 4 else { return }

        let directionRaw = data[2]
        let steps = data[3]

        guard let direction = EncoderDirection(rawValue: directionRaw) else {
            return
        }

        DispatchQueue.main.async { [weak self] in
            self?.delegate?.hidManagerDidReceiveEncoderEvent(direction: direction, steps: steps)
        }
    }

    private func handleDeviceReady(_ data: Data) {
        guard data.count >= 5 else { return }

        let major = data[2]
        let minor = data[3]
        let patch = data[4]

        let version = "\(major).\(minor).\(patch)"

        DispatchQueue.main.async { [weak self] in
            self?.firmwareVersion = version
            self?.delegate?.hidManagerDidConnect(firmwareVersion: version)
        }
    }

    private func handleHeartbeat() {
        lastHeartbeatTime = Date()
        sendHeartbeatResponse()

        DispatchQueue.main.async { [weak self] in
            self?.delegate?.hidManagerDidReceiveHeartbeat()
        }
    }

    private func createReport(command: HIDCommand, payloadLength: UInt8) -> [UInt8] {
        var report = [UInt8](repeating: 0, count: reportSize)
        report[0] = command.rawValue
        report[1] = payloadLength
        return report
    }

    private func sendDisplayLine(command: HIDCommand, text: String) {
        var report = createReport(command: command, payloadLength: UInt8(min(text.count, 29)))

        let textData = text.prefix(29).data(using: .ascii) ?? Data()
        for (index, byte) in textData.enumerated() {
            report[2 + index] = byte
        }

        sendReport(report)
    }

    /// Error tracking for retry logic
    private var consecutiveErrors: Int = 0
    private let maxRetries: Int = 3
    private let retryDelay: TimeInterval = 0.1

    /// Send HID report with retry logic
    private func sendReport(_ report: [UInt8]) {
        guard let device = connectedDevice else {
            print("Cannot send report: no device connected")
            return
        }

        sendReportWithRetry(report, device: device, attempt: 1)
    }

    /// Send report with retry on failure
    private func sendReportWithRetry(_ report: [UInt8], device: IOHIDDevice, attempt: Int) {
        var reportCopy = report
        let result = IOHIDDeviceSetReport(
            device,
            kIOHIDReportTypeOutput,
            0, // Report ID
            &reportCopy,
            reportCopy.count
        )

        if result == kIOReturnSuccess {
            // Reset error counter on success
            consecutiveErrors = 0
            return
        }

        // Log the error
        let errorDescription = describeIOKitError(result)
        print("Failed to send HID report (attempt \(attempt)/\(maxRetries)): \(errorDescription)")

        consecutiveErrors += 1

        // Check if we should retry
        if attempt < maxRetries {
            // Retry after a short delay
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + retryDelay) { [weak self] in
                guard let self = self, self.connectedDevice === device else { return }
                self.sendReportWithRetry(report, device: device, attempt: attempt + 1)
            }
        } else {
            // Max retries exceeded
            print("HID report failed after \(maxRetries) attempts")

            // If we've had too many consecutive errors, the device may be in a bad state
            if consecutiveErrors > 10 {
                print("Too many consecutive errors, attempting to reconnect...")
                attemptReconnect()
            }
        }
    }

    /// Attempt to reconnect to the device
    private func attemptReconnect() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Mark as disconnected
            self.connectedDevice = nil
            self.isConnected = false
            self.delegate?.hidManagerDidDisconnect()

            // Reset error counter
            self.consecutiveErrors = 0

            // Restart scanning - the device matching callback will reconnect
            print("Restarting HID scanning...")
            self.stop()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.start()
            }
        }
    }

    /// Describe IOKit error codes
    private func describeIOKitError(_ result: IOReturn) -> String {
        switch result {
        case kIOReturnSuccess:
            return "Success"
        case kIOReturnError:
            return "General error"
        case kIOReturnNoMemory:
            return "No memory"
        case kIOReturnNoResources:
            return "No resources"
        case kIOReturnIPCError:
            return "IPC error"
        case kIOReturnNoDevice:
            return "No device"
        case kIOReturnNotPrivileged:
            return "Not privileged"
        case kIOReturnBadArgument:
            return "Bad argument"
        case kIOReturnLockedRead:
            return "Locked for read"
        case kIOReturnLockedWrite:
            return "Locked for write"
        case kIOReturnExclusiveAccess:
            return "Exclusive access"
        case kIOReturnBadMessageID:
            return "Bad message ID"
        case kIOReturnUnsupported:
            return "Unsupported"
        case kIOReturnNotOpen:
            return "Not open"
        case kIOReturnNotReadable:
            return "Not readable"
        case kIOReturnNotWritable:
            return "Not writable"
        case kIOReturnNotPermitted:
            return "Not permitted"
        case kIOReturnTimeout:
            return "Timeout"
        case kIOReturnAborted:
            return "Aborted"
        default:
            return "Unknown error (\(String(format: "0x%08X", result)))"
        }
    }

    private func startHeartbeatMonitor() {
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.checkHeartbeat()
        }
    }

    /// Missed heartbeat counter for detecting stale connections
    private var missedHeartbeats: Int = 0
    private let maxMissedHeartbeats: Int = 3

    private func checkHeartbeat() {
        guard isConnected else {
            missedHeartbeats = 0
            return
        }

        if let lastHeartbeat = lastHeartbeatTime {
            let elapsed = Date().timeIntervalSince(lastHeartbeat)
            if elapsed > heartbeatTimeout {
                missedHeartbeats += 1
                print("Heartbeat timeout (\(missedHeartbeats)/\(maxMissedHeartbeats)) - device may be disconnected")

                if missedHeartbeats >= maxMissedHeartbeats {
                    print("Too many missed heartbeats, forcing disconnect and reconnect")
                    missedHeartbeats = 0
                    attemptReconnect()
                }
            }
        } else {
            // No heartbeat received yet - this is OK for newly connected devices
            // but if it persists, something may be wrong
            if connectedDevice != nil {
                // Send a ping to prompt a heartbeat response
                sendHeartbeatResponse()
            }
        }
    }

    /// Reset connection state
    func resetConnection() {
        consecutiveErrors = 0
        missedHeartbeats = 0
        lastHeartbeatTime = nil
        attemptReconnect()
    }
}
