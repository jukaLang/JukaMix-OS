#!/bin/sh
# Neo Geo CD: NeoCD - Neo Geo CD emulation
. /mnt/SDCARD/System/usr/trimui/scripts/common_launcher.sh

# Neo Geo CD needs more CPU for CD loading
if [ "$JUKAMIX_DEVICE_OPTIMIZED" = "tg5050" ]; then
    cpufreq.sh ondemand 3 8
else
    cpufreq.sh ondemand 3 7
fi

cd "$RA_DIR/"

HOME="$RA_DIR"/ "$RA_BIN" -v -L "$RA_DIR"/.retroarch/cores/neocd_libretro.so "$@"
