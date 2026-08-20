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
        cpufreq.sh performance 2 7
        ;;
    *)
        cpufreq.sh performance 5 8
        ;;
esac

cd "$RA_DIR/"

# Video driver settings per device
case "$DEVICE_CODE" in
    tg5050)
        # TG5050: Use glcore driver for Mali-G57
        export RA_VIDEO_DRIVER="glcore"
        export RA_VIDEO_CONTEXT="gl"
        ;;
    tsp|brick)
        # TSP/Brick: Use default driver for Mali-G31
        export RA_VIDEO_DRIVER="gl"
        export RA_VIDEO_CONTEXT="gl"
        ;;
    *)
        export RA_VIDEO_DRIVER="gl"
        export RA_VIDEO_CONTEXT="gl"
        ;;
esac

HOME="$RA_DIR"/ "$RA_DIR"/ra64.trimui -v -L "$RA_DIR"/.retroarch/cores/yabasanshiro_libretro.so "$@"
