#!/bin/sh
. /mnt/SDCARD/System/usr/trimui/scripts/common_launcher.sh

# Device detection
DEVICE_CODE="unknown"
if [ -f /etc/trimui_device.txt ]; then
    DEVICE_CODE=$(tr -d '[:space:]' < /etc/trimui_device.txt | head -n 1)
fi

# CPU settings per device
case "$DEVICE_CODE" in
    tg5050)
        cpufreq.sh performance 5 9
        ;;
    tsp|brick)
        cpufreq.sh performance 7 7
        ;;
    *)
        cpufreq.sh performance 5 8
        ;;
esac

# cwd is EMU_DIR
export HOME="$PWD"

# BIOS detection
choice=$(grep -i "dowork 0x" "/tmp/log/messages" | tail -n 1 | grep -i "(HLE BIOS)")
if [ -n "$choice" ]; then
    BIOS_FILE=""
    echo "Using Yabasanshiro HLE BIOS"
else
    BIOS_FILE="/mnt/SDCARD/BIOS/saturn_bios.bin"
    if [ ! -f "$BIOS_FILE" ]; then
        echo "BIOS file not found, falling back to HLE BIOS"
        /mnt/SDCARD/System/usr/trimui/scripts/infoscreen.sh -i bg-exit.png -m "No bios found, Yabasanshiro will use HLE (less compatible)." -k "A B"
    else
        echo "Using real Saturn BIOS"
    fi
fi

if [ -f "/tmp/cmd_to_run.sh" ] && ! grep -q "dowork 0x" "/tmp/cmd_to_run.sh"; then
    sed -i "1s|^|echo \"$choice\" > /tmp/log/messages\n|" "/tmp/cmd_to_run.sh"
fi

# Rendering mode: TG5050 Mali-G57 needs software rendering (-r 0)
# TSP/Brick Mali-G31 can use hardware acceleration (-r 3)
case "$DEVICE_CODE" in
    tg5050)
        # TG5050: Use software rendering for Mali-G57 compatibility
        echo "TG5050 detected: Using software rendering"
        ./yabasanshiro -r 0 -i "$@" -b "$BIOS_FILE"
        ;;
    tsp|brick)
        # TSP/Brick: Use hardware acceleration for Mali-G31
        echo "TSP/Brick detected: Using hardware acceleration"
        ./yabasanshiro -r 3 -i "$@" -b "$BIOS_FILE"
        ;;
    *)
        # Unknown device: Try hardware acceleration first, fallback to software
        echo "Unknown device: Trying hardware acceleration"
        ./yabasanshiro -r 3 -i "$@" -b "$BIOS_FILE" 2>/dev/null || {
            echo "Hardware acceleration failed, falling back to software rendering"
            ./yabasanshiro -r 0 -i "$@" -b "$BIOS_FILE"
        }
        ;;
esac
