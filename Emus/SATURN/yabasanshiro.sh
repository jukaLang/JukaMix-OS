#!/bin/sh
. /mnt/SDCARD/System/usr/trimui/scripts/common_launcher.sh
if [ "$JUKAMIX_DEVICE_OPTIMIZED" = "tg5050" ]; then
    cpufreq.sh performance 5 9
else
    cpufreq.sh performance 2 7
fi

cd "$RA_DIR/"

HOME="$RA_DIR"/ "$RA_DIR"/ra64.trimui -v -L "$RA_DIR"/.retroarch/cores/yabasanshiro_libretro.so "$@"
