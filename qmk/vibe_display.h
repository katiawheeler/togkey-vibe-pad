// Togkey Vibe - Raw HID Header
// Display and HID function declarations

#pragma once

#include <stdint.h>
#include <stdbool.h>

// Display functions
void display_init(void);
void display_set_line(uint8_t line, const char *text);
void display_draw_icon(uint8_t icon_id, uint8_t x, uint8_t y);
void display_check_connection(void);

// Host connection tracking
void display_mark_host_active(void);
bool display_is_host_connected(void);

// State setters (for local fallback display)
void display_set_mode(uint8_t mode);
void display_set_stt(bool enabled);

// Extended HID handler for display commands
void raw_hid_receive_display(uint8_t *data, uint8_t length);

// Icon IDs for display_draw_icon
enum display_icons {
    ICON_MIC_ON = 0,
    ICON_MIC_OFF = 1,
    ICON_BRAIN = 2,
    ICON_CHECK = 3,
    ICON_X = 4,
    ICON_LIGHTNING = 5,
    ICON_CLOCK = 6
};

// HID command IDs for display
#define HID_CMD_DISPLAY_HEADER  0x12
#define HID_CMD_DISPLAY_LINE1   0x13
#define HID_CMD_DISPLAY_LINE2   0x14
#define HID_CMD_DISPLAY_FOOTER  0x15
#define HID_CMD_DISPLAY_REFRESH 0x16
#define HID_CMD_DISPLAY_ICON    0x17
#define HID_CMD_SET_MODE        0x18
#define HID_CMD_SET_STT         0x19
