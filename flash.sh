#!/bin/bash
# flash.sh - Build and flash Togkey Pad Plus firmware
set -euo pipefail

FIRMWARE_NAME="togkey_padplus_vibe"
UF2_FILE="${FIRMWARE_NAME}.uf2"
QMK_OUTPUT="${HOME}/qmk_firmware/${UF2_FILE}"
LOCAL_UF2="$(dirname "$0")/${UF2_FILE}"
BOOT_VOLUME="/Volumes/RPI-RP2"
BOOT_TIMEOUT=30

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

usage() {
    echo "Usage: $0 [build|flash|build-flash]"
    echo ""
    echo "  build        Compile firmware with QMK"
    echo "  flash        Flash pre-compiled .uf2 to device"
    echo "  build-flash  Compile and flash in one step"
    echo ""
    echo "If no argument given, defaults to 'flash' using local .uf2"
    exit 1
}

build() {
    echo -e "${CYAN}Compiling firmware...${NC}"

    if ! command -v qmk &>/dev/null; then
        echo -e "${RED}Error: qmk CLI not found. Install with: python3 -m pip install qmk${NC}"
        exit 1
    fi

    qmk compile -kb togkey/padplus -km vibe

    if [[ -f "$QMK_OUTPUT" ]]; then
        cp "$QMK_OUTPUT" "$LOCAL_UF2"
        echo -e "${GREEN}Build complete: ${UF2_FILE}${NC}"
    else
        echo -e "${RED}Build failed: ${QMK_OUTPUT} not found${NC}"
        exit 1
    fi
}

wait_for_bootloader() {
    if [[ -d "$BOOT_VOLUME" ]]; then
        return 0
    fi

    echo -e "${YELLOW}Waiting for bootloader...${NC}"
    echo "Hold the top-left key (MacWhisper) while plugging in USB."
    echo ""

    local elapsed=0
    while [[ ! -d "$BOOT_VOLUME" ]]; do
        if (( elapsed >= BOOT_TIMEOUT )); then
            echo -e "${RED}Timed out waiting for ${BOOT_VOLUME}${NC}"
            echo "Make sure the device is in bootloader mode (hold top-left key + plug USB)."
            exit 1
        fi
        sleep 1
        ((elapsed++))
        printf "\r  Waiting... %ds / %ds" "$elapsed" "$BOOT_TIMEOUT"
    done
    printf "\r"
    echo -e "${GREEN}Bootloader detected!${NC}"
}

flash() {
    local uf2="$LOCAL_UF2"

    if [[ ! -f "$uf2" ]]; then
        echo -e "${RED}Error: ${UF2_FILE} not found. Run '$0 build' first.${NC}"
        exit 1
    fi

    local size
    size=$(stat -f%z "$uf2" 2>/dev/null || stat --printf="%s" "$uf2" 2>/dev/null)
    echo -e "${CYAN}Firmware: ${UF2_FILE} (${size} bytes)${NC}"

    wait_for_bootloader

    echo -e "${CYAN}Flashing...${NC}"
    cp "$uf2" "$BOOT_VOLUME/"

    # Wait for device to reboot (volume unmounts)
    sleep 2
    if [[ -d "$BOOT_VOLUME" ]]; then
        echo -e "${YELLOW}Device may still be flashing, waiting...${NC}"
        sleep 3
    fi

    echo -e "${GREEN}Flash complete! Device should reboot automatically.${NC}"
}

case "${1:-flash}" in
    build)
        build
        ;;
    flash)
        flash
        ;;
    build-flash)
        build
        flash
        ;;
    -h|--help|help)
        usage
        ;;
    *)
        echo -e "${RED}Unknown command: $1${NC}"
        usage
        ;;
esac
