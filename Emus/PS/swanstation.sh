#!/bin/sh
. /mnt/SDCARD/System/usr/trimui/scripts/common_launcher.sh
if [ "$JUKAMIX_DEVICE_OPTIMIZED" = "tg5050" ]; then
    cpufreq.sh ondemand 5 9
else
    cpufreq.sh ondemand 5 7
fi

cd "$RA_DIR/"

if ! find "/mnt/SDCARD/BIOS" -maxdepth 1 -iname "scph*" -o -iname "psxonpsp660.bin" -o -iname "ps*.bin" | grep -q .; then
	/mnt/SDCARD/System/usr/trimui/scripts/infoscreen.sh -i bg-exit.png -m "No bios found, SwanStation will probably not work." -k " "
fi

HOME="$RA_DIR"/ "$RA_BIN" -v -L "$RA_DIR"/.retroarch/cores/swanstation_libretro.so "$@"
