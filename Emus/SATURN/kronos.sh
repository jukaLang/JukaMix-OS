#!/bin/sh
# Sega Saturn: Kronos - accurate Saturn emulation (TG5050 only recommended)
. /mnt/SDCARD/System/usr/trimui/scripts/common_launcher.sh

# Kronos needs high CPU - only recommended on TG5050
if [ "$JUKAMIX_DEVICE_OPTIMIZED" = "tg5050" ]; then
    cpufreq.sh performance 5 9
else
    cpufreq.sh performance 3 8
fi

cd "$RA_DIR/"

HOME="$RA_DIR"/ "$RA_BIN" -v -L "$RA_DIR"/.retroarch/cores/kronos_libretro.so "$@"
