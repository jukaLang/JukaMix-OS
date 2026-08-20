#!/bin/sh
RA_DIR=/mnt/SDCARD/RetroArch
EMU_DIR=/mnt/SDCARD/Emus/VIDEOS
cd "$RA_DIR/"

. /mnt/SDCARD/System/usr/trimui/scripts/cpufreq_default.sh 2>/dev/null || true
/mnt/SDCARD/System/usr/trimui/scripts/cpufreq.sh ondemand 2 "${JUKAMIX_CPUFREQ_MAX:-6}"

HOME="$RA_DIR"/ "$RA_DIR"/ra64.trimui -L "$RA_DIR"/.retroarch/cores/ffmpeg_libretro.so "$@"
