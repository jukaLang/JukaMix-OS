#!/bin/sh
. /mnt/SDCARD/System/usr/trimui/scripts/common_launcher.sh

# CPS1/CPS2/CPS3: FBNeo arcade emulator
if [ "$JUKAMIX_DEVICE_OPTIMIZED" = "tg5050" ]; then
    cpufreq.sh performance 2 9
else
    cpufreq.sh performance 2 7
fi

cd "$RA_DIR/"

# Force using fbneo
HOME="$RA_DIR"/ "$RA_BIN" -v -L "$RA_DIR"/.retroarch/cores/fbneo_libretro.so "$@"
