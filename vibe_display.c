// Togkey Vibe - OLED Display Driver
// Shows Claude thinking animation

#include QMK_KEYBOARD_H
#include "vibe_display.h"

// Current mode/state
static uint8_t current_mode = 0;  // 0=ASK, 1=PLAN, 2=EDITS, 3=ALL
static bool stt_enabled = false;
static bool host_connected = false;
static uint32_t last_host_message = 0;
static bool display_dirty = true;

// Connection timeout (ms)
#define HOST_TIMEOUT 10000

// Update host connection timestamp
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

// Update mode
void display_set_mode(uint8_t mode) {
    if (mode != current_mode && mode < 4) {
        current_mode = mode;
        display_dirty = true;
    }
}

// Update STT state
void display_set_stt(bool enabled) {
    if (enabled != stt_enabled) {
        stt_enabled = enabled;
        display_dirty = true;
    }
}

#ifdef OLED_ENABLE

// Animation state
static uint8_t anim_frame = 0;
static uint32_t last_anim_update = 0;
#define ANIM_FRAME_DURATION 150  // ms between frames

// Claude thinking glyphs as 8x8 bitmap patterns (will be scaled 2x)
// Glyphs: · ✻ ✽ ✶ ✳ ✢
// Each byte is one column, LSB at top

// · Small centered dot
static const uint8_t PROGMEM glyph_0[] = {
    0x00, 0x00, 0x00, 0x18, 0x18, 0x00, 0x00, 0x00
};

// ✻ Six-pointed asterisk with lines
static const uint8_t PROGMEM glyph_1[] = {
    0x08, 0x49, 0x2A, 0x1C, 0x1C, 0x2A, 0x49, 0x08
};

// ✽ Heavy teardrop asterisk (fuller)
static const uint8_t PROGMEM glyph_2[] = {
    0x08, 0x1C, 0x2A, 0x7F, 0x7F, 0x2A, 0x1C, 0x08
};

// ✶ Six-pointed solid star
static const uint8_t PROGMEM glyph_3[] = {
    0x08, 0x08, 0x3E, 0x1C, 0x1C, 0x3E, 0x08, 0x08
};

// ✳ Eight-spoked asterisk
static const uint8_t PROGMEM glyph_4[] = {
    0x41, 0x22, 0x14, 0x08, 0x08, 0x14, 0x22, 0x41
};

// ✢ Four teardrop cross
static const uint8_t PROGMEM glyph_5[] = {
    0x00, 0x08, 0x08, 0x3E, 0x3E, 0x08, 0x08, 0x00
};

static const uint8_t* const glyphs[] = {
    glyph_0, glyph_1, glyph_2, glyph_3, glyph_4, glyph_5
};
#define NUM_GLYPHS 6

// Initialize OLED with correct rotation
oled_rotation_t oled_init_user(oled_rotation_t rotation) {
    return OLED_ROTATION_180;
}

// Draw the thinking animation - cycling glyph centered on screen
static void draw_thinking_animation(void) {
    oled_clear();

    const uint8_t* glyph = glyphs[anim_frame % NUM_GLYPHS];

    // 8x8 glyph scaled 2x = 16x16 pixels
    // X center: (128 - 16) / 2 = 56
    // Y: moved down to 20
    uint8_t start_x = 56;
    uint8_t start_y = 20;

    // Draw 8x8 glyph scaled 2x (16x16 result)
    for (uint8_t col = 0; col < 8; col++) {
        uint8_t column_data = pgm_read_byte(&glyph[col]);
        for (uint8_t bit = 0; bit < 8; bit++) {
            if (column_data & (1 << bit)) {
                // Draw 2x2 pixel block for each bit
                uint8_t px = start_x + col * 2;
                uint8_t py = start_y + bit * 2;
                oled_write_pixel(px, py, true);
                oled_write_pixel(px + 1, py, true);
                oled_write_pixel(px, py + 1, true);
                oled_write_pixel(px + 1, py + 1, true);
            }
        }
    }
}

// OLED task - runs every frame
bool oled_task_user(void) {
    // Update animation
    if (timer_elapsed32(last_anim_update) > ANIM_FRAME_DURATION) {
        anim_frame = (anim_frame + 1) % NUM_GLYPHS;
        last_anim_update = timer_read32();
        draw_thinking_animation();
    }

    return false;
}

#endif

// Initialize display
void display_init(void) {
    display_dirty = true;
}

// Set display line (for host control - currently unused with animation display)
void display_set_line(uint8_t line, const char *text) {
    // Mark host as active
    display_mark_host_active();
    display_dirty = true;
}

// Draw icon (stub - not used with animation display)
void display_draw_icon(uint8_t icon_id, uint8_t x, uint8_t y) {
    (void)icon_id;
    (void)x;
    (void)y;
}

// Check connection (called from matrix_scan_user when OLED not enabled)
void display_check_connection(void) {
    display_is_host_connected();
}

// Extended raw HID handler for display commands
void raw_hid_receive_display(uint8_t *data, uint8_t length) {
    display_mark_host_active();

    uint8_t cmd = data[0];
    uint8_t payload_len = data[1];
    uint8_t *payload = &data[2];

    switch (cmd) {
        case 0x18: // Set mode
            if (payload_len >= 1) {
                display_set_mode(payload[0]);
            }
            break;
        case 0x19: // Set STT state
            if (payload_len >= 1) {
                display_set_stt(payload[0] != 0);
            }
            break;
        default:
            // Other display commands mark activity but we only show animation
            break;
    }
}
