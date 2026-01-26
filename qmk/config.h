// Togkey Vibe - QMK Configuration
// For Togkey Pad Plus macropad

#pragma once

// Raw HID configuration
#define RAW_USAGE_PAGE 0xFF60
#define RAW_USAGE_ID 0x61

// ============================================================
// ENCODER CONFIGURATION
// ============================================================
// The Togkey Pad Plus has one rotary encoder with push button.
// Configure how the encoder push is wired based on your hardware:
//
// OPTION 1: Encoder push on dedicated GPIO pin (RECOMMENDED)
//   Set ENCODER_PUSH_PIN to your hardware's encoder switch pin.
//   Common pins for STM32: B12, C13, A8
//   Common pins for ATmega32U4: B7, D7, E6
//
// OPTION 2: Encoder push in the switch matrix
//   If the encoder push is wired into the key matrix, add TV_STT
//   to the LAYOUT macro in keymap.c at the appropriate position.
//
// OPTION 3: Encoder with integrated switch (EC11 style)
//   Enable ENCODER_SWITCH_ENABLE and set row/col position.
// ============================================================

// OPTION 1: Dedicated GPIO pin for encoder push
// NOTE: Togkey Pad Plus has encoder push in the switch matrix, not GPIO
// Uncomment and set correct GP pin if your hardware uses separate GPIO
// #define ENCODER_PUSH_PIN GP12

// OPTION 2: Encoder switch in matrix (uncomment if using matrix)
// #define ENCODER_SWITCH_ENABLE
// #define ENCODER_SWITCH_ROW 2
// #define ENCODER_SWITCH_COL 0

// OPTION 3: If encoder push doesn't work with above, try these pins:
// #define ENCODER_PUSH_PIN C13
// #define ENCODER_PUSH_PIN A8

// Encoder resolution (pulses per detent)
// EC11 encoders typically have 4 pulses per detent
// Some have 2 pulses - adjust if rotation feels "double"
#ifndef ENCODER_RESOLUTION
#define ENCODER_RESOLUTION 4
#endif

// Encoder direction (swap if rotation is reversed)
// #define ENCODER_DIRECTION_FLIP

// ============================================================
// TIMING CONFIGURATION
// ============================================================
// Timing for long press detection
#define TAPPING_TERM 200
#define LONG_PRESS_DELAY 500  // ms to trigger long press

// Debounce settings
#define DEBOUNCE 5

// RGB LED configuration (if using WS2812)
#ifdef RGBLIGHT_ENABLE
    #define RGBLIGHT_EFFECT_BREATHING
    #define RGBLIGHT_EFFECT_RAINBOW_MOOD
    #define RGBLIGHT_EFFECT_STATIC_GRADIENT
    #define RGBLIGHT_DEFAULT_HUE 170  // Blue
    #define RGBLIGHT_DEFAULT_SAT 255
    #define RGBLIGHT_DEFAULT_VAL 128
    #define RGBLIGHT_LIMIT_VAL 200    // Limit brightness for power
#endif

// RGB Matrix configuration (if using per-key RGB)
#ifdef RGB_MATRIX_ENABLE
    #define RGB_MATRIX_STARTUP_MODE RGB_MATRIX_SOLID_COLOR
    #define RGB_MATRIX_STARTUP_HUE 170
    #define RGB_MATRIX_STARTUP_SAT 255
    #define RGB_MATRIX_STARTUP_VAL 128
#endif

// Communication timing
#define HEARTBEAT_INTERVAL 5000  // Send heartbeat every 5 seconds

// Firmware version
#define FIRMWARE_VERSION_MAJOR 1
#define FIRMWARE_VERSION_MINOR 0
#define FIRMWARE_VERSION_PATCH 0
