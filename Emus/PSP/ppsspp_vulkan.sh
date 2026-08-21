#!/bin/sh
# Emus/PSP/ppsspp_vulkan.sh - PPSSPP v1.17.1 with Vulkan backend

. /mnt/SDCARD/System/usr/trimui/scripts/common_launcher.sh

PPSSPP_BASE="/mnt/SDCARD/Emus/PSP/PPSSPP"
PPSSPP_BINARY="$PPSSPP_BASE/PPSSPPSDL_vulkan"
PPSSPP_CONFIG="$PPSSPP_BASE/.config/ppsspp"

[ ! -f "$PPSSPP_BINARY" ] && { echo "PPSSPP 1.17.1 not found" >&2; exit 1; }

mkdir -p "$PPSSPP_CONFIG/PSP"/{Cheats,GAME,PLUGINS,PPSSPP_STATE,SAVEDATA,SYSTEM,TEXTURES}

export HOME="$PPSSPP_BASE"
export XDG_CONFIG_HOME="$PPSSPP_CONFIG"
export PPSSPP_GRAPHICS_BACKEND="vulkan"

cpufreq.sh ondemand 2 "${JUKAMIX_CPUFREQ_MAX:-7}"

echo "PPSSPP 1.17.1: Vulkan" >&2
exec "$PPSSPP_BINARY" "$@"
