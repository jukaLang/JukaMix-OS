#!/bin/sh
# PC Engine CD / TurboGrafx-CD: Mednafen PCE Fast (CD support)
. /mnt/SDCARD/System/usr/trimui/scripts/common_launcher.sh

# PCE CD needs more CPU for CD audio decoding
if [ "$JUKAMIX_DEVICE_OPTIMIZED" = "tg5050" ]; then
    cpufreq.sh ondemand 2 7
else
    cpufreq.sh ondemand 2 6
fi

cd "$RA_DIR/"

HOME="$RA_DIR"/ "$RA_BIN" -v -L "$RA_DIR"/.retroarch/cores/mednafen_pce_fast_libretro.so "$@"
