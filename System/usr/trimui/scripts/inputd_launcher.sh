#!/bin/sh
# inputd_launcher.sh - Launch the correct inputd binary for the current device
#
# Usage:
#   . /mnt/SDCARD/System/usr/trimui/scripts/inputd_launcher.sh
#   launch_inputd

INPUTD_DIR="/mnt/SDCARD/trimui/app"
RESOURCES_DIR="/mnt/SDCARD/System/resources"

# Get device code
DEVICE_CODE="unknown"
if [ -r /etc/trimui_device.txt ]; then
    DEVICE_CODE=$(tr -d '[:space:]' < /etc/trimui_device.txt 2>/dev/null | head -n 1)
fi

launch_inputd() {
    # Check if already running
    if pgrep -f trimui_inputd >/dev/null 2>&1; then
        return 0
    fi

    local inputd_binary=""
    local inputd_dir="$INPUTD_DIR"

    # Select the correct inputd for this device
    case "$DEVICE_CODE" in
        tg5050)
            # TG5050 has its own inputd in the app directory
            inputd_binary="$inputd_dir/trimui_inputd"
            ;;
        tsp)
            # TSP uses the resources version
            inputd_binary="$RESOURCES_DIR/tsp_inputd"
            ;;
        brick)
            # Brick uses the resources version
            inputd_binary="$RESOURCES_DIR/tsp_inputd"
            ;;
        brick_pro|brickpro)
            # Brick Pro: Try Pro-specific first, fallback to TSP
            if [ -f "$RESOURCES_DIR/brick_pro_inputd" ]; then
                inputd_binary="$RESOURCES_DIR/brick_pro_inputd"
            else
                # Brick Pro has same input hardware as TSP
                inputd_binary="$RESOURCES_DIR/tsp_inputd"
            fi
            ;;
        *)
            # Unknown device: try default
            inputd_binary="$inputd_dir/trimui_inputd"
            ;;
    esac

    # Fallback chain
    if [ ! -f "$inputd_binary" ]; then
        inputd_binary="$inputd_dir/trimui_inputd"
    fi
    if [ ! -f "$inputd_binary" ]; then
        inputd_binary="$RESOURCES_DIR/tsp_inputd"
    fi

    if [ -f "$inputd_binary" ]; then
        echo "inputd_launcher: Using $inputd_binary for device=$DEVICE_CODE"
        cd "$(dirname "$inputd_binary")"
        "./$(basename "$inputd_binary")" &
        return $?
    else
        echo "inputd_launcher: ERROR - No inputd binary found"
        return 1
    fi
}

# Auto-launch if sourced with --launch flag
if [ "$1" = "--launch" ]; then
    launch_inputd
fi
