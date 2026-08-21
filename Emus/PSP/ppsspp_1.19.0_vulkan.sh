#!/bin/sh
# Emus/PSP/ppsspp_1.19.0_vulkan.sh - PPSSPP v1.19.0 with Vulkan backend

. /mnt/SDCARD/System/usr/trimui/scripts/common_launcher.sh

PPSSPP_BASE="/mnt/SDCARD/Emus/PSP/PPSSPP"
PPSSPP_BINARY="$PPSSPP_BASE/PPSSPPSDL_1.19.0"
PPSSPP_CONFIG="$PPSSPP_BASE/.config/ppsspp"

[ ! -f "$PPSSPP_BINARY" ] && { echo "PPSSPP 1.19.0 not found" >&2; exit 1; }

mkdir -p "$PPSSPP_CONFIG/PSP"/{Cheats,GAME,PLUGINS,PPSSPP_STATE,SAVEDATA,SYSTEM,TEXTURES}

export HOME="$PPSSPP_BASE"
export XDG_CONFIG_HOME="$PPSSPP_CONFIG"
export PPSSPP_GRAPHICS_BACKEND="vulkan"

# Vulkan is more efficient, allow higher clocks
cpufreq.sh ondemand 2 "${JUKAMIX_CPUFREQ_MAX:-7}"

echo "PPSSPP 1.19.0: Vulkan" >&2
exec "$PPSSPP_BINARY" "$@"
