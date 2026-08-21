#!/bin/sh
# Sega 32X: PicoDrive - 32X emulation
. /mnt/SDCARD/System/usr/trimui/scripts/common_launcher.sh

# 32X needs more CPU than standard Genesis
if [ "$JUKAMIX_DEVICE_OPTIMIZED" = "tg5050" ]; then
    cpufreq.sh ondemand 2 7
else
    cpufreq.sh ondemand 2 6
fi

cd "$RA_DIR/"

HOME="$RA_DIR"/ "$RA_BIN" -v -L "$RA_DIR"/.retroarch/cores/picodrive_libretro.so "$@"
