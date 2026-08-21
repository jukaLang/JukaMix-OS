#!/bin/sh
. /mnt/SDCARD/System/usr/trimui/scripts/common_launcher.sh

# PPSSPP AppImage launcher - OpenGL mode

performance=$(grep -i "dowork 0x" "/tmp/log/messages" | tail -n 1 | grep -i "Perf.")
if [ -n "$performance" ]; then
    if [ "$JUKAMIX_DEVICE_OPTIMIZED" = "tg5050" ]; then
        cpufreq.sh ondemand 3 9
    else
        cpufreq.sh ondemand 3 8
    fi
else
    cpufreq.sh ondemand 3 6
fi

if [ -f "/tmp/cmd_to_run.sh" ] && ! grep -q "dowork 0x" "/tmp/cmd_to_run.sh"; then
    sed -i "1s|^|echo \"$performance\" > /tmp/log/messages\n|" "/tmp/cmd_to_run.sh"
fi

# Force OpenGL backend
export PPSSPP_GRAPHICS_BACKEND="opengl"

PPSSPP_DIR="/mnt/SDCARD/Emus/PSP/PPSSPP"
if [ -f "$PPSSPP_DIR/PPSSPP.AppImage" ]; then
    HOME=$PWD "$PPSSPP_DIR/PPSSPP.AppImage" "$*"
else
    echo "PPSSPP.AppImage not found in $PPSSPP_DIR" >&2
    exit 1
fi
