#!/bin/sh
# GBA: mGBA Standalone - accurate GBA emulation
. /mnt/SDCARD/System/usr/trimui/scripts/common_launcher.sh

if [ "$JUKAMIX_DEVICE_OPTIMIZED" = "tg5050" ]; then
    cpufreq.sh ondemand 2 7
else
    cpufreq.sh ondemand 2 6
fi

export LD_LIBRARY_PATH="$PM_DIR:/mnt/SDCARD/System/lib:$EMU_DIR/lib:/usr/lib:$LD_LIBRARY_PATH"
export XDG_CONFIG_HOME="$EMU_DIR/.config"

HOTKEY=guide $PM_DIR/gptokeyb2 "mgba" -k "mgba" -c "/mnt/SDCARD/Emus/GBA/.config/mgba/mgba.gptk" &
sleep 0.3

$EMU_DIR/mgba "$@"
kill -9 $(pidof gptokeyb2)
