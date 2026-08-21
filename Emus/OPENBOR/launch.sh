#!/bin/sh
# OpenBOR: Beats of Rage Remixed - beat 'em up engine
. /mnt/SDCARD/System/usr/trimui/scripts/common_launcher.sh

# OpenBOR needs moderate CPU
if [ "$JUKAMIX_DEVICE_OPTIMIZED" = "tg5050" ]; then
    cpufreq.sh ondemand 2 7
else
    cpufreq.sh ondemand 2 6
fi

export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$PWD

./OpenBOR "$1"
