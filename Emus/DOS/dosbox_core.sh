#!/bin/sh
# DOS: DOSBox Core - alternative DOS emulation (more accurate than Pure)
. /mnt/SDCARD/System/usr/trimui/scripts/common_launcher.sh

# DOSBox Core needs more CPU than DOSBox Pure
if [ "$JUKAMIX_DEVICE_OPTIMIZED" = "tg5050" ]; then
    cpufreq.sh ondemand 3 8
else
    cpufreq.sh ondemand 3 7
fi

cd "$RA_DIR/"

HOME="$RA_DIR"/ "$RA_BIN" -v -L "$RA_DIR"/.retroarch/cores/dosbox_core_libretro.so "$@"
