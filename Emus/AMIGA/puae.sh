#!/bin/sh
. /mnt/SDCARD/System/usr/trimui/scripts/common_launcher.sh
cpufreq.sh ondemand 3 7
cd "$RA_DIR/"
HOME="$RA_DIR/" "$RA_BIN" -v -L "$RA_DIR/.retroarch/cores/puae2021_libretro.so" "$@"
