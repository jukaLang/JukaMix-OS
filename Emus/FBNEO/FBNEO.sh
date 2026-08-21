#!/bin/sh
. /mnt/SDCARD/System/usr/trimui/scripts/common_launcher.sh

# FBNeo: Arcade emulator - performance mode for responsive input
if [ "$JUKAMIX_DEVICE_OPTIMIZED" = "tg5050" ]; then
    cpufreq.sh performance 2 9
else
    cpufreq.sh performance 2 7
fi

cd "$RA_DIR/"

HOME="$RA_DIR"/ "$RA_BIN" -v -L "$RA_DIR"/.retroarch/cores/fbneo_libretro.so "$@"
