#!/bin/sh
. /mnt/SDCARD/System/usr/trimui/scripts/common_launcher.sh

# PPSSPP AppImage launcher with auto GPU backend selection
# The AppImage includes both GL and Vulkan support

# Detect GPU capabilities and select backend
if [ -d "/dev/dri" ] && ls /dev/dri/render* >/dev/null 2>&1; then
    # Check if Vulkan is available
    if [ -f "/usr/lib/libvulkan.so" ] || [ -f "/usr/lib64/libvulkan.so" ]; then
        BACKEND="vulkan"
    else
        BACKEND="opengl"
    fi
else
    BACKEND="opengl"
fi

# Performance mode detection
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

# Set backend via environment variable
export PPSSPP_GRAPHICS_BACKEND="$BACKEND"

# Launch the AppImage
PPSSPP_DIR="/mnt/SDCARD/Emus/PSP/PPSSPP"
if [ -f "$PPSSPP_DIR/PPSSPP.AppImage" ]; then
    HOME=$PWD "$PPSSPP_DIR/PPSSPP.AppImage" "$*"
else
    echo "PPSSPP.AppImage not found in $PPSSPP_DIR" >&2
    exit 1
fi
