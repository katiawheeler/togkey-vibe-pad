// Togkey Vibe - QMK Keymap
// For Togkey Pad Plus macropad
// Ultimate vibe coding controller for Claude Code CLI

#include QMK_KEYBOARD_H
#include "vibe_display.h"

// RAW HID definitions
#ifdef RAW_ENABLE
// RAW_EPSIZE is the USB endpoint size for raw HID (typically 32 bytes)
#ifndef RAW_EPSIZE
#define RAW_EPSIZE 32
#endif
void raw_hid_send(uint8_t *data, uint8_t length);
#endif

// Key indices (matching HID protocol)
enum key_indices {
    KEY_THINK_CYCLE = 0,
    KEY_CLEAR_CHAT = 1,
    KEY_UNDO_CHANGE = 2,
    KEY_RESUME_TASK = 3,
    KEY_COMMIT_PR = 4,
    KEY_ESCAPE_STOP = 5,
    KEY_ENCODER_PUSH = 6
};

// Custom keycodes
enum custom_keycodes {
    TV_THINK = SAFE_RANGE,  // Think cycle
    TV_CLEAR,               // Clear chat
    TV_UNDO,                // Undo change
    TV_RESUME,              // Resume task
    TV_COMMIT,              // Commit / PR (long press)
    TV_STOP,                // Escape / Stop
    TV_STT,                 // STT toggle (encoder push)
    TV_MODE_CW,             // Mode clockwise
    TV_MODE_CCW             // Mode counter-clockwise
};

// HID command definitions (matching protocol)
#define HID_CMD_KEY_EVENT       0x01
#define HID_CMD_ENCODER_EVENT   0x02
#define HID_CMD_DEVICE_READY    0x03
#define HID_CMD_HEARTBEAT       0x04

#define HID_CMD_SET_LED_COLOR   0x10
#define HID_CMD_SET_LED_PATTERN 0x11
#define HID_CMD_DISPLAY_HEADER  0x12
#define HID_CMD_DISPLAY_LINE1   0x13
#define HID_CMD_DISPLAY_LINE2   0x14
#define HID_CMD_DISPLAY_FOOTER  0x15
#define HID_CMD_PING_RESPONSE   0x1F

// Event types
#define EVENT_RELEASED          0x00
#define EVENT_PRESSED           0x01
#define EVENT_LONG_PRESS_START  0x02
#define EVENT_LONG_PRESS_END    0x03

// Direction
#define DIR_CCW                 0x00
#define DIR_CW                  0x01

// Long press tracking
static uint16_t key_press_timer[7] = {0};
static bool key_held[7] = {false};
static bool long_press_triggered[7] = {false};

// Heartbeat timer
static uint32_t last_heartbeat = 0;

// Current LED state (for display updates from host)
static uint8_t current_led_r = 64;
static uint8_t current_led_g = 64;
static uint8_t current_led_b = 64;
static uint8_t current_pattern = 0;

// Keymap
// Layout: encoder button, then 6 keys in 2x3 grid
const uint16_t PROGMEM keymaps[][MATRIX_ROWS][MATRIX_COLS] = {
    [0] = LAYOUT(
        TV_STT,                          // Encoder push (matrix position 0,2)
        TV_THINK,  TV_CLEAR,  TV_UNDO,   // Row 1
        TV_RESUME, TV_COMMIT, TV_STOP    // Row 2
    )
};

// Encoder map
#ifdef ENCODER_MAP_ENABLE
const uint16_t PROGMEM encoder_map[][NUM_ENCODERS][NUM_DIRECTIONS] = {
    [0] = { ENCODER_CCW_CW(TV_MODE_CCW, TV_MODE_CW) }
};
#endif

// Send HID report
static void send_hid_report(uint8_t cmd, uint8_t *payload, uint8_t len) {
    uint8_t report[RAW_EPSIZE] = {0};
    report[0] = cmd;
    report[1] = len;
    if (len > 0 && payload != NULL) {
        memcpy(&report[2], payload, len);
    }
    raw_hid_send(report, RAW_EPSIZE);
}

// Send key event
static void send_key_event(uint8_t key_idx, uint8_t event_type) {
    uint8_t payload[2] = {key_idx, event_type};
    send_hid_report(HID_CMD_KEY_EVENT, payload, 2);
}

// Send encoder event
static void send_encoder_event(uint8_t direction, uint8_t steps) {
    uint8_t payload[2] = {direction, steps};
    send_hid_report(HID_CMD_ENCODER_EVENT, payload, 2);
}

// Send device ready
static void send_device_ready(void) {
    uint8_t payload[3] = {
        FIRMWARE_VERSION_MAJOR,
        FIRMWARE_VERSION_MINOR,
        FIRMWARE_VERSION_PATCH
    };
    send_hid_report(HID_CMD_DEVICE_READY, payload, 3);
}

// Send heartbeat
static void send_heartbeat(void) {
    send_hid_report(HID_CMD_HEARTBEAT, NULL, 0);
}

// Set LED color
static void set_led_color(uint8_t r, uint8_t g, uint8_t b) {
    current_led_r = r;
    current_led_g = g;
    current_led_b = b;

#ifdef RGBLIGHT_ENABLE
    rgblight_setrgb(r, g, b);
#endif
#ifdef RGB_MATRIX_ENABLE
    rgb_matrix_set_color_all(r, g, b);
#endif
}

// Set LED pattern
static void set_led_pattern(uint8_t pattern, uint8_t speed) {
    current_pattern = pattern;

#ifdef RGBLIGHT_ENABLE
    switch (pattern) {
        case 0: // Solid
            rgblight_mode(RGBLIGHT_MODE_STATIC_LIGHT);
            break;
        case 1: // Pulse
            rgblight_mode(RGBLIGHT_MODE_BREATHING);
            rgblight_set_speed(speed);
            break;
        case 2: // Breathe (slow)
            rgblight_mode(RGBLIGHT_MODE_BREATHING + 2);
            rgblight_set_speed(speed / 2);
            break;
        case 3: // Flash
            rgblight_mode(RGBLIGHT_MODE_BREATHING);
            rgblight_set_speed(speed * 2);
            break;
    }
#endif
}

// Process received HID data from host
void raw_hid_receive(uint8_t *data, uint8_t length) {
    uint8_t cmd = data[0];
    uint8_t payload_len = data[1];
    uint8_t *payload = &data[2];

    switch (cmd) {
        case HID_CMD_SET_LED_COLOR:
            if (payload_len >= 3) {
                set_led_color(payload[0], payload[1], payload[2]);
            }
            break;

        case HID_CMD_SET_LED_PATTERN:
            if (payload_len >= 2) {
                set_led_pattern(payload[0], payload[1]);
            }
            break;

        case HID_CMD_DISPLAY_HEADER:
        case HID_CMD_DISPLAY_LINE1:
        case HID_CMD_DISPLAY_LINE2:
        case HID_CMD_DISPLAY_FOOTER:
        case 0x16: // Full refresh
        case 0x17: // Icon
        case 0x18: // Set mode
        case 0x19: // Set STT
            // Route display commands to the display handler
            raw_hid_receive_display(data, length);
            break;

        case HID_CMD_PING_RESPONSE:
            // Host acknowledged our heartbeat
            break;
    }
}

// Get key index from keycode
static int8_t get_key_index(uint16_t keycode) {
    switch (keycode) {
        case TV_THINK:  return KEY_THINK_CYCLE;
        case TV_CLEAR:  return KEY_CLEAR_CHAT;
        case TV_UNDO:   return KEY_UNDO_CHANGE;
        case TV_RESUME: return KEY_RESUME_TASK;
        case TV_COMMIT: return KEY_COMMIT_PR;
        case TV_STOP:   return KEY_ESCAPE_STOP;
        case TV_STT:    return KEY_ENCODER_PUSH;
        default:        return -1;
    }
}

// Process custom keycodes
bool process_record_user(uint16_t keycode, keyrecord_t *record) {
    int8_t key_idx = get_key_index(keycode);

    if (key_idx >= 0) {
        if (record->event.pressed) {
            // Key pressed - flash RGB green for feedback
            #ifdef RGBLIGHT_ENABLE
            rgblight_setrgb(0, 255, 0);
            #endif
            // Key pressed
            key_press_timer[key_idx] = timer_read();
            key_held[key_idx] = true;
            long_press_triggered[key_idx] = false;
            send_key_event(key_idx, EVENT_PRESSED);
        } else {
            // Key released - restore dim white
            #ifdef RGBLIGHT_ENABLE
            rgblight_setrgb(64, 64, 64);
            #endif
            // Key released
            key_held[key_idx] = false;
            if (long_press_triggered[key_idx]) {
                send_key_event(key_idx, EVENT_LONG_PRESS_END);
            } else {
                send_key_event(key_idx, EVENT_RELEASED);
            }
            long_press_triggered[key_idx] = false;
        }
        return false;
    }

    // Encoder rotation events
    if (keycode == TV_MODE_CW) {
        if (record->event.pressed) {
            send_encoder_event(DIR_CW, 1);
        }
        return false;
    }

    if (keycode == TV_MODE_CCW) {
        if (record->event.pressed) {
            send_encoder_event(DIR_CCW, 1);
        }
        return false;
    }

    return true;
}

// Local mode tracking
static uint8_t local_mode = 0;  // 0=ASK, 1=PLAN, 2=EDITS, 3=ALL

// Encoder callback - cycle modes locally AND send HID event
bool encoder_update_user(uint8_t index, bool clockwise) {
    if (clockwise) {
        local_mode = (local_mode + 1) % 4;
        send_encoder_event(DIR_CW, 1);
    } else {
        local_mode = (local_mode + 3) % 4;  // +3 is same as -1 mod 4
        send_encoder_event(DIR_CCW, 1);
    }
    // Update local display
    display_set_mode(local_mode);
    return false;
}

// ============================================================
// ENCODER PUSH BUTTON HANDLING
// ============================================================
// The encoder push can be connected in several ways:
// 1. Dedicated GPIO pin (ENCODER_PUSH_PIN)
// 2. Part of the switch matrix (add TV_STT to LAYOUT)
// 3. Encoder switch matrix feature (ENCODER_SWITCH_ENABLE)
//
// Configure the appropriate option in config.h

// OPTION 1: GPIO-based encoder push
#ifdef ENCODER_PUSH_PIN
static bool encoder_push_state = false;
static bool encoder_push_initialized = false;

void init_encoder_push_gpio(void) {
    if (!encoder_push_initialized) {
        setPinInputHigh(ENCODER_PUSH_PIN);  // Internal pull-up
        encoder_push_initialized = true;
    }
}

void check_encoder_push(void) {
    bool current_state = !readPin(ENCODER_PUSH_PIN);  // Active low

    if (current_state != encoder_push_state) {
        encoder_push_state = current_state;

        if (encoder_push_state) {
            // Pressed
            key_press_timer[KEY_ENCODER_PUSH] = timer_read();
            key_held[KEY_ENCODER_PUSH] = true;
            long_press_triggered[KEY_ENCODER_PUSH] = false;
            send_key_event(KEY_ENCODER_PUSH, EVENT_PRESSED);
        } else {
            // Released
            key_held[KEY_ENCODER_PUSH] = false;
            if (long_press_triggered[KEY_ENCODER_PUSH]) {
                send_key_event(KEY_ENCODER_PUSH, EVENT_LONG_PRESS_END);
            } else {
                send_key_event(KEY_ENCODER_PUSH, EVENT_RELEASED);
            }
            long_press_triggered[KEY_ENCODER_PUSH] = false;
        }
    }
}
#endif

// OPTION 3: Encoder switch matrix feature
// Some keyboards wire the encoder switch into a separate matrix position
#ifdef ENCODER_SWITCH_ENABLE
static bool encoder_switch_state = false;

void check_encoder_switch_matrix(void) {
    // Read from matrix position defined in config.h
    // This requires keyboard-specific implementation
    // The matrix state should be available after matrix_scan()
    #if defined(ENCODER_SWITCH_ROW) && defined(ENCODER_SWITCH_COL)
    // Implementation depends on keyboard's matrix driver
    // For now, this is a placeholder - keyboard-specific code needed
    #endif
}
#endif

// Matrix scan - check for long presses, encoder push, heartbeat, and display
void matrix_scan_user(void) {
    // Check encoder push button if using GPIO
    #ifdef ENCODER_PUSH_PIN
    check_encoder_push();
    #endif

    // Check for long press on all keys
    for (int i = 0; i < 7; i++) {
        if (key_held[i] && !long_press_triggered[i]) {
            if (timer_elapsed(key_press_timer[i]) > LONG_PRESS_DELAY) {
                long_press_triggered[i] = true;
                send_key_event(i, EVENT_LONG_PRESS_START);
            }
        }
    }

    // Send heartbeat periodically
    if (timer_elapsed32(last_heartbeat) > HEARTBEAT_INTERVAL) {
        send_heartbeat();
        last_heartbeat = timer_read32();
    }

    // Check display connection status (for fallback rendering)
    #ifndef OLED_ENABLE
    display_check_connection();
    #endif
}

// Keyboard initialization
void keyboard_post_init_user(void) {
    // Initialize encoder push GPIO if configured
    #ifdef ENCODER_PUSH_PIN
    init_encoder_push_gpio();
    #endif

    // Initialize display buffer
    display_init();

    // Set initial LED to dim white (idle/disconnected)
    set_led_color(64, 64, 64);
    set_led_pattern(0, 128);  // Solid

    // Send device ready message
    send_device_ready();

    // Initialize heartbeat timer
    last_heartbeat = timer_read32();
}
