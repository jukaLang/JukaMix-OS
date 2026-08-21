#!/bin/sh
# gaming_modes.sh - Gaming Modes Switcher
# One-tap global modes for different usage scenarios
#
# Usage: gaming_modes.sh <mode>

CONFIG_FILE="/mnt/SDCARD/System/etc/jukamix.json"
LOG_FILE="/tmp/gaming_modes.log"

# ── Logging ────────────────────────────────────────────────────────────
log() {
    echo "$(date '+%H:%M:%S') [modes] $1" >> "$LOG_FILE" 2>/dev/null
}

# ── Show OSD message ───────────────────────────────────────────────────
show_osd() {
    message="$1"
    
    if [ -d /tmp/trimui_osd ] && [ -w /tmp/trimui_osd ]; then
        echo "{\"type\":\"info\",\"size\":2,\"duration\":3000,\"x\":660,\"y\":0,\"message\":\"$message\",\"icon\":\"\"}" > /tmp/trimui_osd/osd_toast_msg 2>/dev/null
    fi
}

# ── Travel Mode ────────────────────────────────────────────────────────
travel_mode() {
    log "Activating Travel mode"
    
    # Low brightness
    echo 30 > /sys/class/backlight/backlight/brightness 2>/dev/null
    
    # Wi-Fi off
    ifconfig wlan0 down 2>/dev/null
    
    # Eco CPU
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        [ -w "$cpu" ] && echo "powersave" > "$cpu" 2>/dev/null
    done
    
    # Aggressive sleep (5 minutes)
    echo "120" > /tmp/deep_sleep_timeout 2>/dev/null
    
    show_osd "Travel Mode: Low power, Wi-Fi off"
    log "Travel mode activated"
}

# ── Performance Mode ───────────────────────────────────────────────────
performance_mode() {
    log "Activating Performance mode"
    
    # Maximum safe performance
    device=$(cat /etc/trimui_device.txt 2>/dev/null || echo "tsp")
    
    case "$device" in
        tg5050)
            for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
                [ -w "$cpu" ] && echo "performance" > "$cpu" 2>/dev/null
            done
            ;;
        *)
            for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
                [ -w "$cpu" ] && echo "ondemand" > "$cpu" 2>/dev/null
            done
            ;;
    esac
    
    # Disable background services
    pkill -f "battery_monitor.sh" 2>/dev/null
    pkill -f "deep_sleep.sh" 2>/dev/null
    
    # Full brightness
    echo 100 > /sys/class/backlight/backlight/brightness 2>/dev/null
    
    show_osd "Performance Mode: Maximum performance"
    log "Performance mode activated"
}

# ── Retro Pixel Mode ───────────────────────────────────────────────────
retro_pixel_mode() {
    log "Activating Retro Pixel mode"
    
    # Integer scaling
    # Sharp filter
    # System-specific overlays
    
    # Set RetroArch config if available
    ra_config="/mnt/SDCARD/RetroArch/.retroarch/retroarch.cfg"
    if [ -f "$ra_config" ]; then
        sed -i 's/video_smooth = ".*"/video_smooth = "false"/' "$ra_config" 2>/dev/null
        sed -i 's/video_scale_integer = ".*"/video_scale_integer = "true"/' "$ra_config" 2>/dev/null
    fi
    
    show_osd "Retro Pixel Mode: Integer scaling, sharp filter"
    log "Retro Pixel mode activated"
}

# ── Couch Multiplayer Mode ─────────────────────────────────────────────
couch_multiplayer_mode() {
    log "Activating Couch Multiplayer mode"
    
    # Bluetooth on for controllers
    btmgmt power on 2>/dev/null
    
    # Wi-Fi on for online multiplayer
    ifconfig wlan0 up 2>/dev/null
    
    # Balanced performance
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        [ -w "$cpu" ] && echo "ondemand" > "$cpu" 2>/dev/null
    done
    
    show_osd "Couch Multiplayer: Bluetooth & Wi-Fi on"
    log "Couch Multiplayer mode activated"
}

# ── Night Mode ─────────────────────────────────────────────────────────
night_mode() {
    log "Activating Night mode"
    
    # Warm colors (if available)
    if [ -f /sys/class/disp/disp/attr/color_temperature ]; then
        echo "235" > /sys/class/disp/disp/attr/color_temperature 2>/dev/null
    fi
    
    # Reduced brightness
    echo 25 > /sys/class/backlight/backlight/brightness 2>/dev/null
    
    # Quiet notifications
    # Disable sound effects
    
    show_osd "Night Mode: Warm colors, low brightness"
    log "Night mode activated"
}

# ── Developer Mode ─────────────────────────────────────────────────────
developer_mode() {
    log "Activating Developer mode"
    
    # Enable SSH
    /etc/init.d/sshd start 2>/dev/null
    
    # Show FPS overlay
    echo "1" > /tmp/show_fps 2>/dev/null
    
    # Enable logging
    echo "1" > /tmp/enable_logging 2>/dev/null
    
    # Show frame-time overlay
    echo "1" > /tmp/show_frametime 2>/dev/null
    
    show_osd "Developer Mode: SSH, FPS, logging enabled"
    log "Developer mode activated"
}

# ── Default/Balanced Mode ──────────────────────────────────────────────
balanced_mode() {
    log "Activating Balanced mode"
    
    # Normal brightness
    echo 50 > /sys/class/backlight/backlight/brightness 2>/dev/null
    
    # Ondemand governor
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        [ -w "$cpu" ] && echo "ondemand" > "$cpu" 2>/dev/null
    done
    
    # Restart background services
    /mnt/SDCARD/System/usr/trimui/scripts/battery_monitor.sh record &
    
    show_osd "Balanced Mode: Default settings"
    log "Balanced mode activated"
}

# ── Get current mode ───────────────────────────────────────────────────
get_current_mode() {
    if [ -f "$CONFIG_FILE" ] && command -v jq >/dev/null 2>&1; then
        jq -r '.["GAMING_MODE"] // "balanced"' "$CONFIG_FILE" 2>/dev/null
    else
        echo "balanced"
    fi
}

# ── Save mode to config ────────────────────────────────────────────────
save_mode() {
    mode="$1"
    
    if [ -f "$CONFIG_FILE" ] && command -v jq >/dev/null 2>&1; then
        jq --arg mode "$mode" '. += {"GAMING_MODE": $mode}' "$CONFIG_FILE" > /tmp/jukamix_tmp.json 2>/dev/null && \
        mv /tmp/jukamix_tmp.json "$CONFIG_FILE" 2>/dev/null
    fi
}

# ── Cycle modes ────────────────────────────────────────────────────────
cycle_modes() {
    current=$(get_current_mode)
    
    case "$current" in
        balanced)     next="performance" ;;
        performance)  next="eco" ;;
        eco)          next="night" ;;
        night)        next="developer" ;;
        developer)    next="balanced" ;;
        *)            next="balanced" ;;
    esac
    
    echo "$next"
}

# ── Usage ──────────────────────────────────────────────────────────────
usage() {
    echo "Usage: gaming_modes.sh <mode>"
    echo ""
    echo "Modes:"
    echo "  travel          Low power, Wi-Fi off, aggressive sleep"
    echo "  performance     Maximum safe performance"
    echo "  retro_pixel     Integer scaling, sharp filter"
    echo "  couch_multi     Bluetooth & Wi-Fi on, balanced"
    echo "  night           Warm colors, low brightness"
    echo "  developer       SSH, FPS, logging enabled"
    echo "  balanced        Default settings"
    echo "  cycle           Cycle through modes"
    echo "  status          Show current mode"
    echo ""
    echo "Example:"
    echo "  gaming_modes.sh travel"
    echo "  gaming_modes.sh cycle"
}

# ── Main ───────────────────────────────────────────────────────────────
if [ $# -eq 0 ]; then
    usage
    exit 0
fi

mode="$1"

case "$mode" in
    travel)
        travel_mode
        save_mode "travel"
        ;;
    performance)
        performance_mode
        save_mode "performance"
        ;;
    retro_pixel)
        retro_pixel_mode
        save_mode "retro_pixel"
        ;;
    couch_multi)
        couch_multiplayer_mode
        save_mode "couch_multi"
        ;;
    night)
        night_mode
        save_mode "night"
        ;;
    developer)
        developer_mode
        save_mode "developer"
        ;;
    balanced)
        balanced_mode
        save_mode "balanced"
        ;;
    cycle)
        next=$(cycle_modes)
        "$0" "$next"
        ;;
    status)
        current=$(get_current_mode)
        echo "Current mode: $current"
        ;;
    *)
        echo "Unknown mode: $mode"
        usage
        exit 1
        ;;
esac
