#!/bin/sh
# System/usr/trimui/scripts/fps_counter.sh
# FPS Counter - Show FPS overlay in RetroArch

OSD_DIR="/tmp/trimui_osd"
FPS_FILE="$OSD_DIR/fps.json"
LOG_FILE="/tmp/fps_counter.log"

# Logging
log() {
    echo "$(date '+%H:%M:%S') [fps] $1" >> "$LOG_FILE"
}

# ── Get FPS from RetroArch ─────────────────────────────────────────────
get_retroarch_fps() {
    # Try RetroArch network command
    if command -v nc >/dev/null 2>&1; then
        local response=$(echo "FPS" | nc -w 1 127.0.0.1 55355 2>/dev/null)
        if [ -n "$response" ]; then
            echo "$response"
            return
        fi
    fi
    
    # Fallback: estimate from frame time
    if [ -f /proc/$(pgrep retroarch)/status ]; then
        echo "N/A"
    else
        echo "N/A"
    fi
}

# ── Show FPS in OSD ────────────────────────────────────────────────────
show_fps() {
    local fps=$(get_retroarch_fps)
    local pid=$(pgrep -f "retroarch" | head -1)
    
    if [ -z "$pid" ]; then
        echo "RetroArch not running"
        return
    fi
    
    # Show in OSD
    if [ -d "$OSD_DIR" ]; then
        echo "{\"type\":\"info\",\"size\":1,\"duration\":2000,\"x\":0,\"y\":0,\"message\":\"FPS: $fps\",\"icon\":\"\"}" > "$FPS_FILE"
    fi
    
    echo "FPS: $fps"
}

# ── Toggle FPS display ─────────────────────────────────────────────────
toggle_fps() {
    local config="/mnt/SDCARD/RetroArch/.retroarch/retroarch.cfg"
    
    if [ ! -f "$config" ]; then
        echo "RetroArch config not found"
        return
    fi
    
    # Check current state
    local current=$(grep "fps_show" "$config" | head -1 | awk -F' = ' '{print $2}' | tr -d '"')
    
    if [ "$current" = "true" ]; then
        sed -i 's/fps_show = "true"/fps_show = "false"/' "$config"
        echo "FPS display: OFF"
    else
        sed -i 's/fps_show = "false"/fps_show = "true"/' "$config"
        echo "FPS display: ON"
    fi
}

# ── Main ──────────────────────────────────────────────────────────────
case "${1:-}" in
    show|status)
        show_fps
        ;;
    toggle)
        toggle_fps
        ;;
    *)
        echo "Usage: fps_counter.sh {show|toggle}" >&2
        echo "" >&2
        echo "Commands:" >&2
        echo "  show    - Show current FPS" >&2
        echo "  toggle  - Toggle FPS display in RetroArch" >&2
        exit 1
        ;;
esac
