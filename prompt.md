# Togkey Pad Plus - Ultimate Vibe Coding Macropad

## Project Overview

Build a companion application and QMK firmware configuration for the Togkey Pad Plus macropad (https://togkey.com/products/togkey-pad-plus-custom-qmk-macropad) that transforms it into the ultimate vibe coding controller for Claude Code CLI.

## Hardware Specs

- **Device**: Togkey Pad Plus
- **Keys**: 6 mechanical keys (2x3 grid)
- **Encoder**: 1 rotary encoder with push button
- **Display**: Small screen for status/mode display
- **LED**: RGB indicator light
- **Firmware**: QMK compatible
- **Connection**: USB

## Desired Functionality

### Rotary Encoder - Claude Mode Selector

The rotary knob should cycle through Claude Code's autoaccept modes:

| Direction | Action |
|-----------|--------|
| Clockwise | Next mode |
| Counter-clockwise | Previous mode |
| Push | Toggle STT (speech-to-text) on/off |

**Modes to cycle through:**
1. `ask` - Ask for permission before each action (default)
2. `plan` - Plan mode for architecture/design
3. `acceptEdits` - Auto-accept file edits only
4. `acceptAll` - Auto-accept all actions (full vibe mode)

### Display

The display should show:
- Current Claude mode (ask/plan/acceptEdits/acceptAll)
- STT status (on/off with microphone icon)
- Current thinking level when active
- Last action performed
- Connection status

### LED Indicator Colors

| State | Color | Pattern |
|-------|-------|---------|
| **Ask Mode** | Blue | Solid |
| **Plan Mode** | Yellow | Solid |
| **Accept Edits Mode** | Orange | Solid |
| **Accept All Mode** | Green | Solid |
| **STT Active/Listening** | Purple | Pulsing |
| **Processing/Thinking** | White | Breathing |
| **Error/Stopped** | Red | Flash |
| **Idle/Disconnected** | Dim White | Solid |

### Key Layout (2x3 Grid)

```
┌─────────┬─────────┬─────────┐
│  Think  │  Clear  │  Undo   │
│  Cycle  │  Chat   │  Change │
├─────────┼─────────┼─────────┤
│  Resume │  Commit │  Escape │
│  Task   │  /PR    │  /Stop  │
└─────────┴─────────┴─────────┘
```

### Key Functions

| Key | Function | Implementation |
|-----|----------|----------------|
| 1 | **Think Cycle** | Cycle through thinking depths: off → lite → medium → hard |
| 2 | **Clear Chat** | Send `/clear` command to reset context |
| 3 | **Undo Change** | Send `/undo` to revert last file change |
| 4 | **Resume Task** | Send `/resume` to continue interrupted work |
| 5 | **Commit/PR** | Trigger `/commit` skill (long press for PR) |
| 6 | **Escape/Stop** | Send Escape key / Ctrl+C to stop current operation |

### Think Cycle Levels

Press Key 1 repeatedly to cycle through:
1. **Off** - Normal prompts
2. **Lite** - Prepend "think about"
3. **Medium** - Prepend "think step by step"
4. **Hard** - Prepend "ultrathink" / deep analysis mode

Display shows current think level, LED briefly flashes on each cycle.

## Technical Architecture

### Recommended Approach: Companion App + QMK

Since the Togkey Pad Plus has a display and RGB LED, a companion app is required for full functionality. The QMK firmware handles input, while the companion app manages state and feedback.

**Data Flow:**
```
┌──────────────┐    HID Events    ┌──────────────┐    Commands    ┌──────────────┐
│  Togkey Pad  │ ───────────────► │  Companion   │ ─────────────► │  Claude Code │
│    (QMK)     │ ◄─────────────── │     App      │ ◄───────────── │     CLI      │
└──────────────┘  Display/LED     └──────────────┘    Status      └──────────────┘
```

## Implementation Requirements

### QMK Firmware
1. Create custom keymap for Togkey Pad Plus
2. Configure encoder for rotation events + push button
3. Send HID reports for key presses (raw HID or keyboard shortcuts)
4. Receive display/LED commands from companion app via raw HID

### Companion App (macOS)
1. **Platform**: macOS (Swift/SwiftUI)
2. **Core Features**:
   - HID device detection and bidirectional communication
   - State management (current mode, STT status, think level)
   - Terminal integration for Claude Code commands
   - Display content generation (text, icons, layouts)
   - LED color/pattern control
   - STT service control via voicemode MCP
3. **Menu Bar Presence**:
   - Shows current mode icon
   - Quick access to settings
   - Connection status
4. **Dependencies**:
   - IOKit for HID communication
   - Accessibility APIs for keyboard simulation
   - Serial/HID protocol for display updates

### Display Protocol

The companion app sends display updates to the macropad:

```
┌─────────────────────────────┐
│ MODE: Accept All      🎤 ON │  <- Header: mode + STT status
├─────────────────────────────┤
│                             │
│      🧠 THINK: Hard         │  <- Current think level
│                             │
│      Last: /commit          │  <- Last action
└─────────────────────────────┘
```

### LED Control Protocol

Companion app sends LED commands:
- Color (RGB values)
- Pattern (solid, pulse, breathe, flash)
- Duration (for temporary states)

### Claude Code Integration Points
- `/clear` - Clear conversation
- `/undo` - Undo last change
- `/resume` - Resume task
- `/commit` - Git commit workflow
- `/pr` - Create pull request
- Mode switching via CLI flags or environment
- Voicemode MCP for STT control
- Process monitoring for status updates

## File Structure

```
togkey-vibe/
├── qmk/
│   ├── keymap.c              # QMK keymap configuration
│   ├── config.h              # QMK config overrides
│   ├── rules.mk              # Build rules
│   └── raw_hid.c             # Raw HID protocol for display/LED
├── app/
│   └── TogkeyVibe/           # macOS companion app
│       ├── App/
│       │   ├── TogkeyVibeApp.swift
│       │   └── AppDelegate.swift
│       ├── Models/
│       │   ├── VibeMode.swift
│       │   ├── ThinkLevel.swift
│       │   └── DeviceState.swift
│       ├── Services/
│       │   ├── HIDManager.swift
│       │   ├── DisplayRenderer.swift
│       │   ├── LEDController.swift
│       │   ├── ClaudeCodeBridge.swift
│       │   └── VoiceModeService.swift
│       ├── Views/
│       │   ├── MenuBarView.swift
│       │   └── SettingsView.swift
│       └── Resources/
├── protocol/
│   └── hid_protocol.md       # HID communication spec
├── docs/
│   └── setup.md              # Setup instructions
└── README.md
```

## Success Criteria

1. Rotary encoder push toggles STT on/off with LED feedback
2. Rotary encoder rotation smoothly cycles through Claude modes
3. Display updates in real-time with current state
4. LED color accurately reflects current mode
5. All 6 keys have useful, responsive functions
6. Think level cycles correctly with visual feedback
7. Long-press on Commit key triggers PR workflow
8. Escape key reliably stops current Claude operation
9. Works reliably with Claude Code CLI
10. Easy to customize key mappings via settings

## Future Enhancements

- Custom per-project key mappings
- Integration with other dev tools (Cursor, VS Code)
- Programmable macro sequences
- Display themes/skins
- Notification display (errors, completions)
- Battery status (if wireless version)
- Multi-device support

## References

- [QMK Documentation](https://docs.qmk.fm/)
- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code)
- [Togkey Pad Plus](https://togkey.com/products/togkey-pad-plus-custom-qmk-macropad)
- [Voicemode MCP](voicemode://docs/quickstart)
