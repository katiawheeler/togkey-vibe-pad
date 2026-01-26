# Togkey Vibe - QMK Build Rules
# For Togkey Pad Plus macropad

# Enable Raw HID for bidirectional communication with companion app
RAW_ENABLE = yes

# Enable encoder support
ENCODER_ENABLE = yes

# Enable RGB LED support (uncomment the appropriate one for your hardware)
RGBLIGHT_ENABLE = yes
# RGB_MATRIX_ENABLE = yes

# Enable OLED display support
OLED_ENABLE = yes
OLED_DRIVER = ssd1306

# Enable console for debugging (disable in production)
CONSOLE_ENABLE = no

# Enable deferred execution for timers
DEFERRED_EXEC_ENABLE = yes

# Optimize firmware size
LTO_ENABLE = yes
SPACE_CADET_ENABLE = no
GRAVE_ESC_ENABLE = no
MAGIC_ENABLE = no

# Source files
SRC += vibe_display.c
