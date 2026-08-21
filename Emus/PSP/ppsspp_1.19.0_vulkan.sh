#!/bin/sh
# Emus/PSP/ppsspp_1.19.0_vulkan.sh - PPSSPP v1.19.0 with Vulkan backend
# Cross-compiled for TrimUI devices

. /mnt/SDCARD/System/usr/trimui/scripts/common_launcher.sh

# ── Paths ──────────────────────────────────────────────────────────────
PPSSPP_BASE="/mnt/SDCARD/Emus/PSP/PPSSPP"
PPSSPP_BINARY="$PPSSPP_BASE/PPSSPPSDL_1.19.0"
PPSSPP_CONFIG="$PPSSPP_BASE/.config/ppsspp"

# ── Detect device ──────────────────────────────────────────────────────
detect_device() {
    if [ -f /sys/firmware/devicetree/base/model ]; then
        local model
        model=$(tr -d '\0' < /sys/firmware/devicetree/base/model 2>/dev/null)
        case "$model" in
            *SmartPro*|*smartpro*) echo "tsp" ;;
            *TG5050*|*tg5050*)     echo "tg5050" ;;
            *Brick*)               echo "brick" ;;
            *)                     echo "unknown" ;;
        esac
    else
        echo "unknown"
    fi
}

DEVICE=$(detect_device)

# ── CPU frequency by device ───────────────────────────────────────────
set_cpu_freq() {
    case "$DEVICE" in
        tg5050)
            cpufreq.sh ondemand 3 9 2>/dev/null || cpufreq.sh performance 3 2>/dev/null
            ;;
        brick_pro)
            cpufreq.sh ondemand 3 8 2>/dev/null || cpufreq.sh performance 3 2>/dev/null
            ;;
        *)
            cpufreq.sh ondemand 3 8 2>/dev/null || cpufreq.sh performance 3 2>/dev/null
            ;;
    esac
}

# ── Check binary exists ───────────────────────────────────────────────
if [ ! -f "$PPSSPP_BINARY" ]; then
    echo "PPSSPP 1.19.0 binary not found: $PPSSPP_BINARY" >&2
    exit 1
fi

# ── Setup config directory ────────────────────────────────────────────
mkdir -p "$PPSSPP_CONFIG/PSP"
mkdir -p "$PPSSPP_CONFIG/PSP/Cheats"
mkdir -p "$PPSSPP_CONFIG/PSP/GAME"
mkdir -p "$PPSSPP_CONFIG/PSP/PLUGINS"
mkdir -p "$PPSSPP_CONFIG/PSP/PPSSPP_STATE"
mkdir -p "$PPSSPP_CONFIG/PSP/SAVEDATA"
mkdir -p "$PPSSPP_CONFIG/PSP/SYSTEM"
mkdir -p "$PPSSPP_CONFIG/PSP/TEXTURES"

# ── Set environment ───────────────────────────────────────────────────
export HOME="$PPSSPP_BASE"
export XDG_CONFIG_HOME="$PPSSPP_CONFIG"
export PPSSPP_CONFIG_DIR="$PPSSPP_CONFIG"
export PPSSPP_GRAPHICS_BACKEND="vulkan"

# ── Set CPU frequency (Vulkan more efficient, higher clocks) ──────────
set_cpu_freq

echo "PPSSPP 1.19.0: Vulkan mode" >&2

# ── Launch ────────────────────────────────────────────────────────────
exec "$PPSSPP_BINARY" "$@"
