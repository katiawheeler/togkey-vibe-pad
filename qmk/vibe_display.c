// Togkey Vibe - Raw HID Implementation
// Additional HID functionality and display driver integration

#include QMK_KEYBOARD_H
#include "vibe_display.h"

// This file provides additional raw HID functionality
// The main HID handling is in keymap.c

// Display buffer (if the macropad has a built-in display)
#define DISPLAY_WIDTH 128
#define DISPLAY_HEIGHT 32
#define DISPLAY_LINES 4
#define DISPLAY_CHARS_PER_LINE 21

static char display_buffer[DISPLAY_LINES][DISPLAY_CHARS_PER_LINE + 1];
static bool display_dirty = true;  // Flag to trigger refresh

// Current mode/state for local display when host is disconnected
static uint8_t current_mode = 0;  // 0=ask, 1=plan, 2=edits, 3=all
static bool stt_enabled = false;
static bool host_connected = false;
static uint32_t last_host_message = 0;

// Connection timeout (ms) - show fallback display if no host messages
#define HOST_TIMEOUT 10000

// Mode names for fallback display
static const char* mode_names[] = {"ASK", "PLAN", "EDITS", "ALL"};

// Update host connection timestamp (call this when receiving any HID message)
void display_mark_host_active(void) {
    last_host_message = timer_read32();
    if (!host_connected) {
        host_connected = true;
        display_dirty = true;
    }
}

// Check if host has timed out
bool display_is_host_connected(void) {
    if (timer_elapsed32(last_host_message) > HOST_TIMEOUT) {
        if (host_connected) {
            host_connected = false;
            display_dirty = true;
        }
        return false;
    }
    return host_connected;
}

// Update local state from host commands
void display_set_mode(uint8_t mode) {
    if (mode != current_mode) {
        current_mode = mode;
        display_dirty = true;
    }
}

void display_set_stt(bool enabled) {
    if (enabled != stt_enabled) {
        stt_enabled = enabled;
        display_dirty = true;
    }
}

// Render fallback display when host is disconnected
static void render_fallback_display(void) {
    char line_buf[DISPLAY_CHARS_PER_LINE + 1];

    // Line 0: Title
    display_set_line(0, "TOGKEY VIBE");

    // Line 1: Current mode
    snprintf(line_buf, sizeof(line_buf), "Mode: %s",
             current_mode < 4 ? mode_names[current_mode] : "???");
    display_set_line(1, line_buf);

    // Line 2: STT status
    snprintf(line_buf, sizeof(line_buf), "STT: %s",
             stt_enabled ? "ON" : "OFF");
    display_set_line(2, line_buf);

    // Line 3: Connection status
    display_set_line(3, "Waiting for host...");
}

// Icon definitions for OLED display
// These would be used if the Togkey Pad Plus has an OLED
#ifdef OLED_ENABLE

// 8x8 pixel icons
static const char PROGMEM icon_mic_on[] = {
    0x18, 0x24, 0x24, 0x24, 0x24, 0x18, 0x08, 0x1C
};

static const char PROGMEM icon_mic_off[] = {
    0x19, 0x26, 0x2C, 0x34, 0x64, 0x98, 0x08, 0x1C
};

static const char PROGMEM icon_brain[] = {
    0x3C, 0x42, 0x99, 0xA5, 0xA5, 0x99, 0x42, 0x3C
};

static const char PROGMEM icon_check[] = {
    0x00, 0x01, 0x02, 0x04, 0x88, 0x50, 0x20, 0x00
};

static const char PROGMEM icon_x[] = {
    0x00, 0x41, 0x22, 0x14, 0x08, 0x14, 0x22, 0x41
};

static const char PROGMEM icon_lightning[] = {
    0x04, 0x08, 0x10, 0x3E, 0x08, 0x10, 0x20, 0x00
};

static const char PROGMEM icon_clock[] = {
    0x3C, 0x42, 0x91, 0x91, 0x8F, 0x81, 0x42, 0x3C
};

// OLED task
bool oled_task_user(void) {
    // Check host connection and render fallback if disconnected
    if (!display_is_host_connected()) {
        render_fallback_display();
    }

    // Only redraw if dirty (optimization)
    if (display_dirty) {
        oled_clear();
        for (int line = 0; line < DISPLAY_LINES; line++) {
            oled_set_cursor(0, line);
            oled_write(display_buffer[line], false);
        }
        display_dirty = false;
    }
    return false;
}

// Set display line
void display_set_line(uint8_t line, const char *text) {
    if (line < DISPLAY_LINES) {
        // Only mark dirty if content actually changed
        if (strncmp(display_buffer[line], text, DISPLAY_CHARS_PER_LINE) != 0) {
            strncpy(display_buffer[line], text, DISPLAY_CHARS_PER_LINE);
            display_buffer[line][DISPLAY_CHARS_PER_LINE] = '\0';
            display_dirty = true;
        }
    }
}

// Draw icon at position
void display_draw_icon(uint8_t icon_id, uint8_t x, uint8_t y) {
    const char *icon = NULL;

    switch (icon_id) {
        case 0: icon = icon_mic_on; break;
        case 1: icon = icon_mic_off; break;
        case 2: icon = icon_brain; break;
        case 3: icon = icon_check; break;
        case 4: icon = icon_x; break;
        case 5: icon = icon_lightning; break;
        case 6: icon = icon_clock; break;
    }

    if (icon != NULL) {
        oled_set_cursor(x, y);
        oled_write_raw_P(icon, 8);
    }
}

#else

// No OLED - stub functions (still maintain buffer state for HID responses)
void display_set_line(uint8_t line, const char *text) {
    if (line < DISPLAY_LINES) {
        if (strncmp(display_buffer[line], text, DISPLAY_CHARS_PER_LINE) != 0) {
            strncpy(display_buffer[line], text, DISPLAY_CHARS_PER_LINE);
            display_buffer[line][DISPLAY_CHARS_PER_LINE] = '\0';
            display_dirty = true;
        }
    }
}

void display_draw_icon(uint8_t icon_id, uint8_t x, uint8_t y) {
    // No-op without OLED
    (void)icon_id;
    (void)x;
    (void)y;
}

// Periodic check for host timeout (call from matrix_scan_user in keymap.c)
void display_check_connection(void) {
    display_is_host_connected();
}

#endif

// Initialize display
void display_init(void) {
    for (int i = 0; i < DISPLAY_LINES; i++) {
        memset(display_buffer[i], ' ', DISPLAY_CHARS_PER_LINE);
        display_buffer[i][DISPLAY_CHARS_PER_LINE] = '\0';
    }

    // Default display content
    display_set_line(0, "TOGKEY VIBE");
    display_set_line(1, "Connecting...");
    display_set_line(2, "");
    display_set_line(3, "");
}

// Extended raw HID handler for display commands
void raw_hid_receive_display(uint8_t *data, uint8_t length) {
    // Mark host as active on any display command
    display_mark_host_active();

    uint8_t cmd = data[0];
    uint8_t payload_len = data[1];
    char *payload = (char *)&data[2];

    switch (cmd) {
        case 0x12: // Header line
            display_set_line(0, payload);
            break;
        case 0x13: // Content line 1
            display_set_line(1, payload);
            break;
        case 0x14: // Content line 2
            display_set_line(2, payload);
            break;
        case 0x15: // Footer line
            display_set_line(3, payload);
            break;
        case 0x16: // Full refresh
            if (payload_len > 0) {
                uint8_t chunk = (uint8_t)payload[0];
                if (chunk < DISPLAY_LINES) {
                    display_set_line(chunk, &payload[1]);
                }
            }
            break;
        case 0x17: // Icon
            if (payload_len >= 3) {
                display_draw_icon((uint8_t)payload[0], (uint8_t)payload[1], (uint8_t)payload[2]);
            }
            break;
        case 0x18: // Set mode (for local state tracking)
            if (payload_len >= 1) {
                display_set_mode((uint8_t)payload[0]);
            }
            break;
        case 0x19: // Set STT state (for local state tracking)
            if (payload_len >= 1) {
                display_set_stt(payload[0] != 0);
            }
            break;
    }
}
