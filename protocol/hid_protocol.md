# Togkey Vibe HID Communication Protocol

## Overview

This document defines the bidirectional HID communication protocol between the Togkey Pad Plus macropad (running QMK firmware) and the Togkey Vibe companion app.

## Raw HID Configuration

- **Usage Page**: `0xFF60` (Vendor Defined)
- **Usage**: `0x61`
- **Report Size**: 32 bytes (QMK default)
- **Report ID**: Not used (single report type)

## Message Format

All messages follow this structure:

```
┌─────────┬─────────┬──────────────────────────────────┐
│ Byte 0  │ Byte 1  │ Bytes 2-31                       │
├─────────┼─────────┼──────────────────────────────────┤
│ Command │ Length  │ Payload (up to 30 bytes)         │
└─────────┴─────────┴──────────────────────────────────┘
```

- **Command** (1 byte): Message type identifier
- **Length** (1 byte): Payload length (0-30)
- **Payload** (0-30 bytes): Command-specific data

## Commands: Device → Host

### 0x01: Key Press Event

Sent when a key is pressed or released.

```
Payload:
  Byte 0: Key index (0-5 for keys, 6 for encoder push)
  Byte 1: Event type
    0x00 = Released
    0x01 = Pressed
    0x02 = Long press started (held > 500ms)
    0x03 = Long press released
```

### 0x02: Encoder Rotation Event

Sent when the rotary encoder is rotated.

```
Payload:
  Byte 0: Direction
    0x00 = Counter-clockwise
    0x01 = Clockwise
  Byte 1: Steps (number of detents, usually 1)
```

### 0x03: Device Ready

Sent when the device finishes initialization.

```
Payload:
  Byte 0: Firmware version major
  Byte 1: Firmware version minor
  Byte 2: Firmware version patch
```

### 0x04: Heartbeat/Ping

Sent periodically to indicate device is connected (every 5 seconds).

```
Payload: (empty)
```

## Commands: Host → Device

### 0x10: Set LED Color

Sets the RGB LED color.

```
Payload:
  Byte 0: Red (0-255)
  Byte 1: Green (0-255)
  Byte 2: Blue (0-255)
```

### 0x11: Set LED Pattern

Sets the LED animation pattern.

```
Payload:
  Byte 0: Pattern type
    0x00 = Solid (no animation)
    0x01 = Pulse (fade in/out)
    0x02 = Breathe (slow fade)
    0x03 = Flash (quick blink)
  Byte 1: Speed (0-255, where 128 = normal speed)
```

### 0x12: Display Update - Header Line

Updates the top header line of the display.

```
Payload:
  Bytes 0-29: ASCII text (null-terminated or padded)
```

### 0x13: Display Update - Content Line 1

Updates the first content line.

```
Payload:
  Bytes 0-29: ASCII text (null-terminated or padded)
```

### 0x14: Display Update - Content Line 2

Updates the second content line.

```
Payload:
  Bytes 0-29: ASCII text (null-terminated or padded)
```

### 0x15: Display Update - Footer Line

Updates the bottom footer/status line.

```
Payload:
  Bytes 0-29: ASCII text (null-terminated or padded)
```

### 0x16: Display Full Refresh

Sends complete display state in multiple chunks.

```
Payload:
  Byte 0: Chunk index (0-3 for 4-line display)
  Bytes 1-29: Line content
```

### 0x17: Display Icon

Sets a special icon/glyph at a position.

```
Payload:
  Byte 0: Icon ID
    0x00 = Microphone on
    0x01 = Microphone off
    0x02 = Brain (thinking)
    0x03 = Check mark
    0x04 = X mark
    0x05 = Lightning bolt
    0x06 = Clock
  Byte 1: Position X (0-127)
  Byte 2: Position Y (0-3 for line number)
```

### 0x18: Set Mode State

Sends the current mode to device for local state tracking (fallback display).

```
Payload:
  Byte 0: Mode index
    0x00 = Ask
    0x01 = Plan
    0x02 = Accept Edits
    0x03 = Accept All
```

### 0x19: Set STT State

Sends the current STT enabled state to device for local state tracking.

```
Payload:
  Byte 0: STT state
    0x00 = STT disabled
    0x01 = STT enabled
```

### 0x1F: Ping/Heartbeat Response

Response to device heartbeat, keeps connection alive.

```
Payload: (empty)
```

## LED Color Presets

For convenience, the following color values are recommended:

| Mode | R | G | B | Hex |
|------|---|---|---|-----|
| Ask Mode (Blue) | 66 | 135 | 245 | `#4287F5` |
| Plan Mode (Yellow) | 245 | 208 | 66 | `#F5D042` |
| Accept Edits (Orange) | 245 | 152 | 66 | `#F59842` |
| Accept All (Green) | 82 | 196 | 82 | `#52C452` |
| STT Active (Purple) | 167 | 66 | 245 | `#A742F5` |
| Processing (White) | 255 | 255 | 255 | `#FFFFFF` |
| Error (Red) | 245 | 66 | 66 | `#F54242` |
| Idle (Dim White) | 64 | 64 | 64 | `#404040` |

## LED Pattern Timing

| Pattern | Behavior |
|---------|----------|
| Solid | No animation, constant brightness |
| Pulse | Sine wave fade: 0% → 100% → 0% over ~1s cycle |
| Breathe | Slow sine: 30% → 100% → 30% over ~3s cycle |
| Flash | Quick on/off: 100ms on, 100ms off |

## Key Index Mapping

```
Physical Layout:     Index:
┌─────┬─────┬─────┐  ┌───┬───┬───┐
│  A  │  B  │  C  │  │ 0 │ 1 │ 2 │
├─────┼─────┼─────┤  ├───┼───┼───┤
│  D  │  E  │  F  │  │ 3 │ 4 │ 5 │
└─────┴─────┴─────┘  └───┴───┴───┘

Encoder Push: Index 6
```

## Example Message Sequences

### Mode Change (Host → Device)

When user rotates encoder to "Accept All" mode:

1. Host receives encoder rotation event
2. Host updates internal state
3. Host sends:
   - `0x10 0x03 0x52 0xC4 0x52` (Set LED to green)
   - `0x11 0x02 0x00 0x80` (Set LED pattern to solid)
   - `0x12 0x1C MODE: Accept All     [mic]` (Update header)

### Key Press (Device → Host)

When user presses Key 5 (Commit):

1. Device sends: `0x01 0x02 0x04 0x01` (Key 4, Pressed)
2. Host triggers `/commit` command
3. Host updates display with feedback
4. Device sends: `0x01 0x02 0x04 0x00` (Key 4, Released)

### Long Press Detection

For Commit/PR (long press = PR):

1. Device sends: `0x01 0x02 0x04 0x01` (Key 4, Pressed)
2. After 500ms hold, device sends: `0x01 0x02 0x04 0x02` (Long press started)
3. Host prepares PR workflow
4. On release: `0x01 0x02 0x04 0x03` (Long press released)
5. Host triggers `/pr` command

## Error Handling

- If a malformed message is received, it should be ignored
- If heartbeat is not received for 10 seconds, consider device disconnected
- All string payloads should handle non-null-terminated data gracefully

## Implementation Notes

### QMK Side
- Use `raw_hid_receive()` callback to handle host → device messages
- Use `raw_hid_send()` to send device → host events
- Timer-based heartbeat using `timer_read()` or deferred execution

### Host Side (macOS)
- Use IOKit `IOHIDManager` for device detection and communication
- Match on VID/PID of Togkey Pad Plus
- Implement `IOHIDReportCallback` for receiving device events
- Use `IOHIDDeviceSetReport` for sending commands
