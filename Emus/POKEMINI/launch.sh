#!/bin/sh
# Pokemon Mini: PokéMini
. /mnt/SDCARD/System/usr/trimui/scripts/common_launcher.sh

if [ "$JUKAMIX_DEVICE_OPTIMIZED" = "tg5050" ]; then
    cpufreq.sh ondemand 2 4
else
    cpufreq.sh ondemand 2 3
fi

cd "$RA_DIR/"

HOME="$RA_DIR"/ "$RA_BIN" -v -L "$RA_DIR"/.retroarch/cores/pokemini_libretro.so "$@"
