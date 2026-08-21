#!/bin/sh
# ADVMAME: Advanced MAME - arcade emulation
. /mnt/SDCARD/System/usr/trimui/scripts/common_launcher.sh

# ADVMAME needs good CPU for arcade emulation
if [ "$JUKAMIX_DEVICE_OPTIMIZED" = "tg5050" ]; then
    cpufreq.sh ondemand 2 7
else
    cpufreq.sh ondemand 2 6
fi

export LD_LIBRARY_PATH="$PWD/lib:/mnt/SDCARD/System/lib:/usr/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

Gamedir=$(dirname "$@")
Gamefile=$(basename "$@")
HOME="$PWD" ./advmame -dir_rom "$Gamedir" "${Gamefile%.*}"
