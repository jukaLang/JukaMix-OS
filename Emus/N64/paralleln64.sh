#!/bin/sh
. /mnt/SDCARD/System/usr/trimui/scripts/common_launcher.sh
if [ "$JUKAMIX_DEVICE_OPTIMIZED" = "tg5050" ]; then
    cpufreq.sh ondemand 4 9
else
    cpufreq.sh ondemand 4 7
fi


cd "$RA_DIR/"

HOME="$RA_DIR"/ "$RA_BIN" -v -L "$RA_DIR"/.retroarch/cores/parallel_n64_libretro.so "$@"
