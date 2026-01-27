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

// Custom keycodes
enum custom_keycodes {
    TV_MACWHISPER = SAFE_RANGE,  // Key 1: MacWhisper (Right Command)
    TV_ENTER,                     // Key 2: Enter key
    TV_STOP,                      // Key 3: Single Escape
    TV_BOOT,                      // Key 4: Bootloader mode
    TV_CLEAR,                     // Key 5: /clear + Enter
    TV_COMPACT,                   // Key 6: /compact + Enter
    TV_PARTY,                     // Encoder push: RGB party mode
    TV_MODE_CW,                   // Mode clockwise
    TV_MODE_CCW                   // Mode counter-clockwise
};

// RGB party mode state
static bool rgb_party_mode = false;

// Forward declarations
static void set_mode_led_color(void);

// HID command definitions (matching protocol)
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

// Direction
#define DIR_CCW                 0x00
#define DIR_CW                  0x01

// Heartbeat timer
static uint32_t last_heartbeat = 0;

// Current LED state (for display updates from host)
static uint8_t current_led_r = 64;
static uint8_t current_led_g = 64;
static uint8_t current_led_b = 64;
static uint8_t current_pattern = 0;

// Keymap
// Layout: encoder button, then 6 keys in 2x3 grid
// Physical layout:
//        [ENCODER]              ← push + dial
// [KEY1]  [KEY2]  [KEY3]        ← top row
// [KEY4]  [KEY5]  [KEY6]        ← bottom row
const uint16_t PROGMEM keymaps[][MATRIX_ROWS][MATRIX_COLS] = {
    [0] = LAYOUT(
        TV_PARTY,                              // Encoder push: RGB party mode
        TV_MACWHISPER, TV_ENTER,   TV_STOP,    // Row 1: MacWhisper, Enter, ESC
        TV_BOOT,       TV_CLEAR,   TV_COMPACT  // Row 2: Bootloader, /clear, /compact
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

// Process custom keycodes
bool process_record_user(uint16_t keycode, keyrecord_t *record) {
    // Handle specific key actions
    switch (keycode) {
        case TV_MACWHISPER:
            // Key 1: Send Right Command (MacWhisper STT toggle)
            if (record->event.pressed) {
                #ifdef RGBLIGHT_ENABLE
                rgblight_setrgb(0, 255, 255);  // Cyan feedback
                #endif
                register_code(KC_RGUI);
            } else {
                unregister_code(KC_RGUI);
                #ifdef RGBLIGHT_ENABLE
                if (!rgb_party_mode) set_mode_led_color();
                #endif
            }
            return false;

        case TV_ENTER:
            // Key 2: Enter key
            if (record->event.pressed) {
                #ifdef RGBLIGHT_ENABLE
                rgblight_setrgb(255, 128, 0);  // Orange feedback
                #endif
                tap_code(KC_ENT);
            } else {
                #ifdef RGBLIGHT_ENABLE
                if (!rgb_party_mode) set_mode_led_color();
                #endif
            }
            return false;

        case TV_STOP:
            // Key 3: Single Escape
            if (record->event.pressed) {
                #ifdef RGBLIGHT_ENABLE
                rgblight_setrgb(255, 0, 0);  // Red feedback
                #endif
                tap_code(KC_ESC);
            } else {
                #ifdef RGBLIGHT_ENABLE
                if (!rgb_party_mode) set_mode_led_color();
                #endif
            }
            return false;

        case TV_BOOT:
            // Key 4: Enter bootloader mode
            if (record->event.pressed) {
                #ifdef RGBLIGHT_ENABLE
                rgblight_setrgb(255, 255, 255);  // White flash before reboot
                #endif
                reset_keyboard();
            }
            return false;

        case TV_CLEAR:
            // Key 5: Type /clear + Enter
            if (record->event.pressed) {
                #ifdef RGBLIGHT_ENABLE
                rgblight_setrgb(0, 255, 0);  // Green feedback
                #endif
                SEND_STRING("/clear" SS_TAP(X_ENTER));
            } else {
                #ifdef RGBLIGHT_ENABLE
                if (!rgb_party_mode) set_mode_led_color();
                #endif
            }
            return false;

        case TV_COMPACT:
            // Key 6: Type /compact + Enter
            if (record->event.pressed) {
                #ifdef RGBLIGHT_ENABLE
                rgblight_setrgb(128, 0, 255);  // Purple feedback
                #endif
                SEND_STRING("/compact" SS_TAP(X_ENTER));
            } else {
                #ifdef RGBLIGHT_ENABLE
                if (!rgb_party_mode) set_mode_led_color();
                #endif
            }
            return false;

        case TV_PARTY:
            // Encoder push: Toggle RGB party mode
            if (record->event.pressed) {
                rgb_party_mode = !rgb_party_mode;
                #ifdef RGBLIGHT_ENABLE
                if (rgb_party_mode) {
                    rgblight_enable();
                    rgblight_mode(RGBLIGHT_MODE_RAINBOW_SWIRL + 2);  // Fast rainbow swirl
                    rgblight_set_speed(255);
                } else {
                    rgblight_mode(RGBLIGHT_MODE_STATIC_LIGHT);
                    set_mode_led_color();  // Restore mode color
                }
                #endif
            }
            return false;

        case TV_MODE_CW:
            // Encoder clockwise
            if (record->event.pressed) {
                send_encoder_event(DIR_CW, 1);
            }
            return false;

        case TV_MODE_CCW:
            // Encoder counter-clockwise
            if (record->event.pressed) {
                send_encoder_event(DIR_CCW, 1);
            }
            return false;

        default:
            return true;
    }
}

// Local mode tracking
static uint8_t local_mode = 0;  // 0=ASK, 1=PLAN, 2=EDITS, 3=ALL

// Set LED color based on current mode
static void set_mode_led_color(void) {
    #ifdef RGBLIGHT_ENABLE
    if (rgb_party_mode) return;  // Don't override party mode

    switch (local_mode) {
        case 0:  // ASK - Blue
            rgblight_setrgb(0, 100, 255);
            break;
        case 1:  // PLAN - Yellow/Gold
            rgblight_setrgb(255, 180, 0);
            break;
        case 2:  // EDITS - Green
            rgblight_setrgb(0, 255, 100);
            break;
        case 3:  // ALL - White
            rgblight_setrgb(255, 255, 255);
            break;
    }
    #endif
}

// Encoder callback - cycle modes locally, send HID event, AND send Shift+Tab
bool encoder_update_user(uint8_t index, bool clockwise) {
    if (clockwise) {
        local_mode = (local_mode + 1) % 4;
        send_encoder_event(DIR_CW, 1);
    } else {
        local_mode = (local_mode + 3) % 4;  // +3 is same as -1 mod 4
        send_encoder_event(DIR_CCW, 1);
    }

    // Send Shift+Tab to change mode in Claude Code
    register_code(KC_LSFT);
    tap_code(KC_TAB);
    unregister_code(KC_LSFT);

    // Update local display and LED
    display_set_mode(local_mode);
    set_mode_led_color();
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
            // Pressed - toggle RGB party mode
            rgb_party_mode = !rgb_party_mode;
            #ifdef RGBLIGHT_ENABLE
            if (rgb_party_mode) {
                rgblight_enable();
                rgblight_mode(RGBLIGHT_MODE_RAINBOW_SWIRL + 2);
                rgblight_set_speed(255);
            } else {
                rgblight_mode(RGBLIGHT_MODE_STATIC_LIGHT);
                set_mode_led_color();  // Restore mode color
            }
            #endif
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

// Matrix scan - check encoder push, heartbeat, and display
void matrix_scan_user(void) {
    // Check encoder push button if using GPIO
    #ifdef ENCODER_PUSH_PIN
    check_encoder_push();
    #endif

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

    // Set initial LED to mode color (ASK = blue)
    set_led_pattern(0, 128);  // Solid
    set_mode_led_color();

    // Send device ready message
    send_device_ready();

    // Initialize heartbeat timer
    last_heartbeat = timer_read32();
}
