#!/bin/sh
# Atari 2600: Stella - accurate Atari 2600 emulation
. /mnt/SDCARD/System/usr/trimui/scripts/common_launcher.sh

if [ "$JUKAMIX_DEVICE_OPTIMIZED" = "tg5050" ]; then
    cpufreq.sh ondemand 2 5
else
    cpufreq.sh ondemand 2 4
fi

cd "$RA_DIR/"

HOME="$RA_DIR"/ "$RA_BIN" -v -L "$RA_DIR"/.retroarch/cores/stella_libretro.so "$@"
