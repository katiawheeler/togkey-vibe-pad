# Togkey Vibe Setup Guide

Complete setup instructions for the Togkey Vibe macropad companion app and QMK firmware.

## Prerequisites

### Hardware
- Togkey Pad Plus macropad ([Purchase](https://togkey.com/products/togkey-pad-plus-custom-qmk-macropad))
- USB cable

### Software
- macOS 13.0 (Ventura) or later
- Xcode 15.0 or later (for building the app)
- QMK Firmware toolchain (for building firmware)
- Claude Code CLI installed

## Part 1: QMK Firmware Setup

### 1.1 Install QMK Environment

```bash
# Install QMK CLI
brew install qmk/qmk/qmk

# Setup QMK
qmk setup
```

### 1.2 Add Togkey Vibe Keymap

Copy the firmware files to your QMK installation:

```bash
# Navigate to your QMK firmware directory
cd ~/qmk_firmware

# Create the keymap directory (adjust path for your keyboard)
mkdir -p keyboards/togkey/padplus/keymaps/vibe

# Copy the firmware files
cp /path/to/togkey-vibe/qmk/* keyboards/togkey/padplus/keymaps/vibe/
```

### 1.3 Configure for Your Hardware

Edit `config.h` to set the correct VID/PID for your Togkey Pad Plus:

```c
// Update these values based on your device
#define VENDOR_ID    0x0000  // Your device's Vendor ID
#define PRODUCT_ID   0x0000  // Your device's Product ID
```

To find your device's VID/PID:
```bash
# On macOS
system_profiler SPUSBDataType | grep -A 10 "Togkey"
```

### 1.4 Build and Flash

```bash
# Compile the firmware
qmk compile -kb togkey/padplus -km vibe

# Flash to device (put device in bootloader mode first)
qmk flash -kb togkey/padplus -km vibe
```

**Note**: To enter bootloader mode, typically hold the encoder button while plugging in the USB cable, or press a dedicated reset button on the PCB.

## Part 2: macOS Companion App Setup

### 2.1 Build the App

#### Option A: Using Swift Package Manager

```bash
cd togkey-vibe/app/TogkeyVibe

# Build
swift build -c release

# The binary will be at:
# .build/release/TogkeyVibe
```

#### Option B: Using Xcode

1. Open `app/TogkeyVibe` in Xcode
2. Create a new macOS App project
3. Add all source files from the directory
4. Configure signing and capabilities
5. Build and run

### 2.2 Configure App Permissions

The app requires the following permissions:

#### Accessibility Access
1. Open System Preferences → Security & Privacy → Privacy → Accessibility
2. Add TogkeyVibe to the list and enable it
3. This is required for keyboard simulation

#### Input Monitoring (if needed)
1. Open System Preferences → Security & Privacy → Privacy → Input Monitoring
2. Add TogkeyVibe if prompted

### 2.3 Configure Device Matching

Edit `HIDManager.swift` to set your device's VID/PID:

```swift
private let vendorID: Int = 0x0000  // Replace with actual VID
private let productID: Int = 0x0000 // Replace with actual PID
```

### 2.4 Launch the App

1. Run the app
2. It will appear in the menu bar
3. Connect your Togkey Pad Plus
4. The LED should change from dim white to blue (Ask mode)

## Part 3: Claude Code Integration

### 3.1 Ensure Claude Code is Installed

```bash
# Check if Claude Code is available
which claude

# If not installed, follow Anthropic's installation guide
```

### 3.2 Voice Mode Setup (Optional)

For STT functionality, ensure the voicemode MCP server is running:

```bash
# Check voicemode status
# (Refer to voicemode documentation for setup)
```

## Usage Guide

### Key Functions

| Key | Short Press | Long Press |
|-----|-------------|------------|
| 1 (Top-Left) | Cycle Think Level | - |
| 2 (Top-Middle) | Clear Chat (`/clear`) | - |
| 3 (Top-Right) | Undo Change (`/undo`) | - |
| 4 (Bottom-Left) | Resume Task (`/resume`) | - |
| 5 (Bottom-Middle) | Commit (`/commit`) | Create PR (`/pr`) |
| 6 (Bottom-Right) | Escape | Ctrl+C (Interrupt) |

### Encoder

| Action | Function |
|--------|----------|
| Rotate Clockwise | Next Mode |
| Rotate Counter-Clockwise | Previous Mode |
| Push | Toggle Voice Mode (STT) |

### Modes

1. **Ask** (Blue) - Default, asks permission for each action
2. **Plan** (Yellow) - Architecture and design mode
3. **Accept Edits** (Orange) - Auto-accepts file changes
4. **Accept All** (Green) - Full vibe mode, accepts everything

### Think Levels

Cycle through thinking depths with Key 1:
- **Off** - Normal prompts
- **Lite** - Light analysis ("think about")
- **Medium** - Step-by-step ("think step by step")
- **Hard** - Deep analysis ("ultrathink")

### LED Patterns

| State | Color | Pattern |
|-------|-------|---------|
| Ask Mode | Blue | Solid |
| Plan Mode | Yellow | Solid |
| Accept Edits | Orange | Solid |
| Accept All | Green | Solid |
| Voice Active | Purple | Pulsing |
| Processing | White | Breathing |
| Error | Red | Flashing |
| Disconnected | Dim White | Solid |

## Troubleshooting

### Device Not Detected

1. Check USB connection
2. Verify VID/PID in both firmware and app match your device
3. Check System Information → USB for device listing
4. Try a different USB port

### Keys Not Working

1. Ensure accessibility permissions are granted
2. Check that Claude Code is running in the foreground terminal
3. Verify the app is connected (check menu bar icon)

### LED Not Changing

1. Verify firmware was flashed correctly
2. Check raw HID communication is enabled in firmware
3. Look for errors in Console.app

### Voice Mode Not Working

1. Ensure voicemode MCP server is running
2. Check microphone permissions
3. Verify the service is available in app settings

## Development

### Debugging Firmware

Enable console output in `rules.mk`:
```make
CONSOLE_ENABLE = yes
```

Then use QMK Toolbox or `hid_listen` to view debug output.

### Debugging App

Run from Xcode with the debugger attached, or check Console.app for log messages.

## Resources

- [QMK Documentation](https://docs.qmk.fm/)
- [Claude Code Documentation](https://docs.anthropic.com/en/docs/claude-code)
- [Togkey Pad Plus](https://togkey.com/products/togkey-pad-plus-custom-qmk-macropad)
- [IOKit HID Programming Guide](https://developer.apple.com/library/archive/documentation/DeviceDrivers/Conceptual/HID/intro/intro.html)
