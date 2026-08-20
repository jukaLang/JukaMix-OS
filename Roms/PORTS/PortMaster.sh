#!/bin/sh
# JukaMix OS - PortMaster entry point (safe to delete; recreated on demand).
# Installs or repairs PortMaster when needed, then opens the PortMaster app.

JUKAMIX_ROOT="/mnt/SDCARD"
PM_TOOL="/mnt/SDCARD/System/usr/jukamix/bin/jm-portmaster"
PM_DIR="/mnt/SDCARD/Apps/PortMaster/PortMaster"
PM_APP="/mnt/SDCARD/Apps/PortMaster"

if [ -x "$PM_TOOL" ]; then
    "$PM_TOOL" ensure || { echo "PortMaster install failed - see System/logs/jukamix.log" >&2; exit 1; }
else
    if [ ! -d "$PM_DIR" ]; then
        echo "PortMaster is not installed (missing $PM_TOOL)" >&2
        exit 1
    fi
fi

exec /bin/sh "$PM_APP/launch.sh"
