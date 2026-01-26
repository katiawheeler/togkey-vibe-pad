# Togkey Vibe

> The ultimate vibe coding companion for Claude Code CLI

Transform your [Togkey Pad Plus](https://togkey.com/products/togkey-pad-plus-custom-qmk-macropad) macropad into a dedicated Claude Code controller for the ultimate vibe coding experience.

![Togkey Vibe](docs/hero.png)

## Features

### Mode Control (Rotary Encoder)
- **Rotate** to cycle through Claude Code modes:
  - **Ask** (Blue) - Permission-based interactions
  - **Plan** (Yellow) - Architecture and design mode
  - **Accept Edits** (Orange) - Auto-accept file changes
  - **Accept All** (Green) - Full vibe mode
- **Push** to toggle voice input (STT)

### Key Functions (6 Keys + Encoder Button)

```
        [Encoder]
           STT
┌─────────┬─────────┬─────────┐
│  Think  │  Clear  │  Undo   │
│  Cycle  │  /clear │  /undo  │
├─────────┼─────────┼─────────┤
│ Resume  │ Commit  │ Escape  │
│ /resume │ /commit │  Stop   │
└─────────┴─────────┴─────────┘
```

| Key | Short Press | Long Press |
|-----|-------------|------------|
| Encoder Push | Toggle STT | - |
| Think Cycle | Cycle thinking depth | - |
| Clear | Clear conversation | - |
| Undo | Undo last change | - |
| Resume | Resume task | - |
| Commit | Git commit | Create PR |
| Escape | Send Escape | Ctrl+C |

### Think Levels
Cycle through thinking depths:
- **Off** - Normal prompts
- **Lite** - "think about"
- **Medium** - "think step by step"
- **Hard** - "ultrathink"

### Visual Feedback
- **Display**: Real-time mode, STT status, and last action (if OLED equipped)
- **LED**: Color-coded modes with animated patterns

## Quick Start

### 1. Install QMK

```bash
brew install qmk/qmk/qmk
qmk setup
```

### 2. Get Togkey Keyboard Definition

The Togkey Pad Plus keyboard definition is **not in the main QMK repo**. You must clone it from Togkey's GitHub:

```bash
# Clone Togkey's source repo
git clone https://github.com/togkey86/TogKey_Pads.git /tmp/TogKey_Pads

# Copy keyboard definition to QMK
mkdir -p ~/qmk_firmware/keyboards/togkey
cp -r /tmp/TogKey_Pads/togkey_qmk_source/pad_plus ~/qmk_firmware/keyboards/togkey/padplus
```

### 3. Install Vibe Keymap

```bash
# Create keymap directory and copy files
mkdir -p ~/qmk_firmware/keyboards/togkey/padplus/keymaps/vibe
cp qmk/* ~/qmk_firmware/keyboards/togkey/padplus/keymaps/vibe/
```

### 4. Compile Firmware

```bash
qmk compile -kb togkey/padplus -km vibe
```

This creates `~/qmk_firmware/togkey_padplus_vibe.uf2`

### 5. Flash Firmware

The Togkey Pad Plus uses an RP2040 chip. To flash:

1. **Enter bootloader mode**: Hold the encoder button while plugging in USB
   - The device will mount as a USB drive called `RPI-RP2`

2. **Copy the firmware**:
   ```bash
   cp ~/qmk_firmware/togkey_padplus_vibe.uf2 /Volumes/RPI-RP2/
   ```
   Or drag `togkey_padplus_vibe.uf2` to the `RPI-RP2` drive in Finder

3. The device will automatically reboot with the new firmware

> **Note**: This replaces VIAL firmware. You'll lose VIAL's real-time GUI configuration but gain Raw HID support for the companion app. To restore VIAL, flash the original firmware from Togkey.

### 6. Build & Run Companion App (Optional)

The companion app enables two-way communication (LED feedback, display updates).

**Using Swift Package Manager:**
```bash
cd app/TogkeyVibe
swift build -c release
.build/release/TogkeyVibe
```

**Using Xcode:**
```bash
cd app/TogkeyVibe
brew install xcodegen  # if needed
xcodegen generate
open TogkeyVibe.xcodeproj
```

### 7. Grant Permissions
- System Preferences → Security & Privacy → Accessibility
- Add TogkeyVibe to the list (required for keyboard simulation)

## Project Structure

```
togkey-vibe/
├── qmk/                      # QMK firmware files
│   ├── config.h              # Configuration (encoder, timing, RGB)
│   ├── keymap.c              # Main keymap and HID handling
│   ├── rules.mk              # Build rules
│   ├── vibe_display.c        # Display driver integration
│   └── vibe_display.h        # Display function declarations
├── app/                      # macOS companion app
│   └── TogkeyVibe/
│       ├── App/              # Main app & delegate
│       ├── Models/           # Data models
│       ├── Services/         # HID, Claude bridge
│       └── Views/            # SwiftUI views
├── protocol/                 # HID protocol spec
│   └── hid_protocol.md
└── docs/                     # Documentation
    └── setup.md
```

## Requirements

- **Hardware**: Togkey Pad Plus macropad
- **macOS**: 13.0 (Ventura) or later
- **Software**: QMK toolchain, Claude Code CLI (for full functionality)

## LED States

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

## How It Works

```
┌──────────────┐    HID Events    ┌──────────────┐    Commands    ┌──────────────┐
│  Togkey Pad  │ ───────────────► │  Companion   │ ─────────────► │  Claude Code │
│    (QMK)     │ ◄─────────────── │     App      │ ◄───────────── │     CLI      │
└──────────────┘  Display/LED     └──────────────┘    Status      └──────────────┘
```

1. **Macropad** sends key presses and encoder events via Raw HID
2. **Companion App** interprets events and sends commands to Claude Code
3. **Claude Code** executes commands and provides status
4. **Companion App** updates display and LED on the macropad

**Without the companion app**: The macropad still works as a basic macro keyboard, but you won't get LED feedback or display updates.

## Development

### Firmware Development

```bash
# Compile
qmk compile -kb togkey/padplus -km vibe

# Flash (enter bootloader first - hold encoder while plugging in)
# Then copy .uf2 to RPI-RP2 drive

# Enable debug output (edit rules.mk first)
# CONSOLE_ENABLE = yes
```

### App Development

```bash
cd app/TogkeyVibe
swift build
swift run
```

## Troubleshooting

### "Invalid keyboard_folder value" error
You need to install the Togkey keyboard definition first. See step 2 above.

### Device not entering bootloader mode
Try holding the encoder button **before** plugging in USB. Some units have a small reset button on the PCB.

### RPI-RP2 drive is read-only
Try a different USB port or cable. On macOS, you may need to drag the file via Finder instead of using `cp`.

### Firmware flashed but keys don't work
The firmware is device-independent - once flashed, it works on any computer. Check that the keymap compiled without errors.

## Resources

- [Togkey Pad Plus](https://togkey.com/products/togkey-pad-plus-custom-qmk-macropad)
- [Togkey Source Code](https://github.com/togkey86/TogKey_Pads)
- [QMK Documentation](https://docs.qmk.fm/)
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code)

## License

MIT License - See [LICENSE](LICENSE) for details.

## Acknowledgments

- [Togkey](https://togkey.com) for the hardware
- [QMK Firmware](https://qmk.fm) for the keyboard firmware framework
- [Anthropic](https://anthropic.com) for Claude Code

---

*Made with vibes*
