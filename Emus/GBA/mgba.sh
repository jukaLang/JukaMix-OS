#!/bin/sh
. /mnt/SDCARD/System/usr/trimui/scripts/common_launcher.sh

# GBA: mGBA - accurate, moderate CPU usage
if [ "$JUKAMIX_DEVICE_OPTIMIZED" = "tg5050" ]; then
    cpufreq.sh ondemand 2 7
else
    cpufreq.sh ondemand 2 6
fi

cd "$RA_DIR/"

HOME="$RA_DIR"/ "$RA_BIN" -v -L "$RA_DIR"/.retroarch/cores/mgba_libretro.so "$@"
