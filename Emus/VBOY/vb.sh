#!/bin/sh
. /mnt/SDCARD/System/usr/trimui/scripts/common_launcher.sh
cpufreq.sh ondemand 2 6
cd "$RA_DIR/"
HOME="$RA_DIR/" "$RA_BIN" -v -L "$RA_DIR/.retroarch/cores/mednafen_vb_libretro.so" "$@"
