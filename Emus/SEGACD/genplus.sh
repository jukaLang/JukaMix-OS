#!/bin/sh
# Sega CD / Mega CD: Genesis Plus GX - accurate Sega CD emulation
. /mnt/SDCARD/System/usr/trimui/scripts/common_launcher.sh

# Sega CD needs more CPU for CD audio + BIOS
if [ "$JUKAMIX_DEVICE_OPTIMIZED" = "tg5050" ]; then
    cpufreq.sh ondemand 2 7
else
    cpufreq.sh ondemand 2 6
fi

cd "$RA_DIR/"

HOME="$RA_DIR"/ "$RA_BIN" -v -L "$RA_DIR"/.retroarch/cores/genesis_plus_gx_libretro.so "$@"
