#!/bin/sh
# System/usr/trimui/scripts/battery_monitor.sh
# Battery monitoring with history and time left prediction

MONITOR_DIR="/mnt/SDCARD/trimui/battery"
HISTORY_FILE="$MONITOR_DIR/history.csv"
LOG_FILE="/tmp/battery_monitor.log"

# Create monitor directory
mkdir -p "$MONITOR_DIR"

# Logging
log() {
    echo "$(date '+%H:%M:%S') [battery] $1" >> "$LOG_FILE"
}

# ── Get battery level ─────────────────────────────────────────────────
get_battery_level() {
    local battery_path="/sys/class/power_supply/battery"
    
    if [ -f "$battery_path/capacity" ]; then
        cat "$battery_path/capacity"
    else
        echo "0"
    fi
}

# ── Get battery status ────────────────────────────────────────────────
get_battery_status() {
    local battery_path="/sys/class/power_supply/battery"
    
    if [ -f "$battery_path/status" ]; then
        cat "$battery_path/status"
    else
        echo "Unknown"
    fi
}

# ── Get battery temperature ───────────────────────────────────────────
get_battery_temperature() {
    local battery_path="/sys/class/power_supply/battery"
    
    if [ -f "$battery_path/temp" ]; then
        local temp=$(cat "$battery_path/temp")
        echo $((temp / 10))
    else
        echo "0"
    fi
}

# ── Record battery history ────────────────────────────────────────────
record_history() {
    local level=$(get_battery_level)
    local status=$(get_battery_status)
    local temp=$(get_battery_temperature)
    local timestamp=$(date +%s)
    local datetime=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Initialize CSV if it doesn't exist
    if [ ! -f "$HISTORY_FILE" ]; then
        echo "timestamp,datetime,level,status,temperature" > "$HISTORY_FILE"
    fi
    
    # Add entry
    echo "$timestamp,$datetime,$level,$status,$temp" >> "$HISTORY_FILE"
    
    # Trim old entries (keep last 24 hours = 1440 entries at 1 minute intervals)
    local count=$(wc -l < "$HISTORY_FILE")
    if [ "$count" -gt 1441 ]; then
        head -1 "$HISTORY_FILE" > "$HISTORY_FILE.tmp"
        tail -1440 "$HISTORY_FILE" >> "$HISTORY_FILE.tmp"
        mv "$HISTORY_FILE.tmp" "$HISTORY_FILE"
    fi
}

# ── Calculate time left ───────────────────────────────────────────────
calculate_time_left() {
    local status=$(get_battery_status)
    
    # If charging, calculate time to full
    if [ "$status" = "Charging" ]; then
        echo "Charging"
        return
    fi
    
    # Get last few entries to calculate drain rate
    if [ ! -f "$HISTORY_FILE" ]; then
        echo "Unknown"
        return
    fi
    
    local entries=$(tail -10 "$HISTORY_FILE" | grep -v "timestamp")
    local count=$(echo "$entries" | wc -l)
    
    if [ "$count" -lt 2 ]; then
        echo "Unknown"
        return
    fi
    
    # Calculate average drain rate
    local first_level=$(echo "$entries" | head -1 | cut -d, -f3)
    local last_level=$(echo "$entries" | tail -1 | cut -d, -f3)
    local first_time=$(echo "$entries" | head -1 | cut -d, -f1)
    local last_time=$(echo "$entries" | tail -1 | cut -d, -f1)
    
    local level_diff=$((first_level - last_level))
    local time_diff=$((last_time - first_time))
    
    if [ "$time_diff" -eq 0 ] || [ "$level_diff" -le 0 ]; then
        echo "Unknown"
        return
    fi
    
    local drain_rate=$((level_diff * 60 / time_diff))  # % per minute
    local current_level=$(get_battery_level)
    local minutes_left=$((current_level / drain_rate))
    
    if [ "$minutes_left" -ge 60 ]; then
        local hours=$((minutes_left / 60))
        local mins=$((minutes_left % 60))
        echo "${hours}h ${mins}m"
    else
        echo "${minutes_left}m"
    fi
}

# ── Show battery info ─────────────────────────────────────────────────
show_info() {
    local level=$(get_battery_level)
    local status=$(get_battery_status)
    local temp=$(get_battery_temperature)
    local time_left=$(calculate_time_left)
    
    echo "Battery Level: ${level}%"
    echo "Status: $status"
    echo "Temperature: ${temp}°C"
    echo "Time Left: $time_left"
}

# ── Show battery history graph (text-based) ───────────────────────────
show_history() {
    if [ ! -f "$HISTORY_FILE" ]; then
        echo "No battery history available"
        return
    fi
    
    echo "Battery History (last 10 entries):"
    echo "-----------------------------------"
    tail -10 "$HISTORY_FILE" | while IFS=, read -r timestamp datetime level status temp; do
        if [ "$timestamp" != "timestamp" ]; then
            printf "%s %3s%% %s %2d°C\n" "$datetime" "$level" "$status" "$temp"
        fi
    done
}

# ── Low battery warning ──────────────────────────────────────────────
low_battery_warning() {
    local level=$(get_battery_level)
    local status=$(get_battery_status)
    
    # Skip if charging
    [ "$status" = "Charging" ] && return
    
    local warn_file="/tmp/battery_warn"
    local warn_cooldown="/tmp/battery_warn_cooldown"
    
    # Check cooldown (don't warn more than once per 5 minutes)
    if [ -f "$warn_cooldown" ]; then
        local last_warn=$(cat "$warn_cooldown" 2>/dev/null || echo "0")
        local now=$(date +%s)
        local elapsed=$((now - last_warn))
        if [ "$elapsed" -lt 300 ]; then
            return  # Still in cooldown
        fi
    fi
    
    # Critical: 5% - shutdown
    if [ "$level" -le 5 ]; then
        log "CRITICAL: Battery at ${level}% - shutting down"
        # Show warning on OSD ONLY if OSD directory exists and is writable
        if [ -d /tmp/trimui_osd ] && [ -w /tmp/trimui_osd ]; then
            echo '{"type":"warning","size":3,"duration":5000,"x":660,"y":0,"message":"CRITICAL: Battery at '${level}'% - Shutdown in 30s","icon":""}' > /tmp/trimui_osd/osd_toast_msg 2>/dev/null
        fi
        echo "$(date +%s)" > "$warn_cooldown"
        sleep 30
        # Force shutdown
        poweroff 2>/dev/null || shutdown -h now 2>/dev/null
    
    # Low: 15% - warning
    elif [ "$level" -le 15 ]; then
        # Only warn once per level
        local prev_warn=$(cat "$warn_file" 2>/dev/null || echo "0")
        if [ "$level" -le "$prev_warn" ]; then
            return
        fi
        
        log "WARNING: Battery at ${level}%"
        echo "$level" > "$warn_file"
        echo "$(date +%s)" > "$warn_cooldown"
        
        # Show warning on OSD ONLY if OSD directory exists and is writable
        if [ -d /tmp/trimui_osd ] && [ -w /tmp/trimui_osd ]; then
            echo '{"type":"warning","size":2,"duration":3000,"x":660,"y":0,"message":"Low battery: '${level}'%","icon":""}' > /tmp/trimui_osd/osd_toast_msg 2>/dev/null
        fi
    fi
}

# ── Main ──────────────────────────────────────────────────────────────
case "${1:-}" in
    record)
        record_history
        low_battery_warning
        ;;
    status)
        show_info
        ;;
    history)
        show_history
        ;;
    warn)
        low_battery_warning
        ;;
    monitor)
        # Continuous monitoring
        log "Starting battery monitor"
        while true; do
            record_history
            low_battery_warning
            sleep 60  # Record every minute
        done
        ;;
    *)
        echo "Usage: battery_monitor.sh {record|status|history|warn|monitor}" >&2
        echo "  record   - Record current battery state" >&2
        echo "  status   - Show current battery info" >&2
        echo "  history  - Show battery history" >&2
        echo "  warn     - Check and show low battery warning" >&2
        echo "  monitor  - Start continuous monitoring" >&2
        exit 1
        ;;
esac
