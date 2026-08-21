#!/bin/sh
# Atari Lynx: Mednafen Lynx - alternative accurate emulator
. /mnt/SDCARD/System/usr/trimui/scripts/common_launcher.sh

if [ "$JUKAMIX_DEVICE_OPTIMIZED" = "tg5050" ]; then
    cpufreq.sh ondemand 2 6
else
    cpufreq.sh ondemand 2 5
fi

cd "$RA_DIR/"

HOME="$RA_DIR"/ "$RA_BIN" -v -L "$RA_DIR"/.retroarch/cores/mednafen_lynx_libretro.so "$@"
