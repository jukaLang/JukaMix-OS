#!/bin/sh
# System/usr/trimui/scripts/osd_stats.sh
# OSD Stats - Show CPU, temperature, and battery in OSD

OSD_DIR="/tmp/trimui_osd"
STATS_FILE="$OSD_DIR/stats.json"

# Create OSD directory
mkdir -p "$OSD_DIR"

# ── Get CPU frequency ──────────────────────────────────────────────────
get_cpu_freq() {
    local cpu_path="/sys/devices/system/cpu/cpu0/cpufreq"
    
    if [ -f "$cpu_path/scaling_cur_freq" ]; then
        local freq=$(cat "$cpu_path/scaling_cur_freq" 2>/dev/null)
        echo $((freq / 1000))  # Convert to MHz
    else
        echo "N/A"
    fi
}

# ── Get CPU temperature ────────────────────────────────────────────────
get_cpu_temp() {
    # Try thermal zone
    if [ -f /sys/class/thermal/thermal_zone0/temp ]; then
        local temp=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null)
        echo $((temp / 1000))
    # Try cpu thermal
    elif [ -f /sys/class/hwmon/hwmon0/temp1_input ]; then
        local temp=$(cat /sys/class/hwmon/hwmon0/temp1_input 2>/dev/null)
        echo $((temp / 1000))
    else
        echo "N/A"
    fi
}

# ── Get battery level ──────────────────────────────────────────────────
get_battery() {
    local battery_path="/sys/class/power_supply/battery"
    
    if [ -f "$battery_path/capacity" ]; then
        echo "$(cat "$battery_path/capacity" 2>/dev/null)%"
    else
        echo "N/A"
    fi
}

# ── Get battery status ────────────────────────────────────────────────
get_battery_status() {
    local battery_path="/sys/class/power_supply/battery"
    
    if [ -f "$battery_path/status" ]; then
        echo "$(cat "$battery_path/status" 2>/dev/null)"
    else
        echo "N/A"
    fi
}

# ── Get RAM usage ──────────────────────────────────────────────────────
get_ram_usage() {
    if [ -f /proc/meminfo ]; then
        local total=$(grep "MemTotal" /proc/meminfo | awk '{print $2}')
        local free=$(grep "MemFree" /proc/meminfo | awk '{print $2}')
        local buffers=$(grep "Buffers" /proc/meminfo | awk '{print $2}')
        local cached=$(grep "Cached" /proc/meminfo | awk '{print $2}')
        
        local used=$((total - free - buffers - cached))
        local percent=$((used * 100 / total))
        
        echo "${percent}%"
    else
        echo "N/A"
    fi
}

# ── Show stats in OSD ──────────────────────────────────────────────────
show_stats() {
    local cpu=$(get_cpu_freq)
    local temp=$(get_cpu_temp)
    local battery=$(get_battery)
    local battery_status=$(get_battery_status)
    local ram=$(get_ram_usage)
    
    # Build stats message
    local msg="CPU: ${cpu}MHz | Temp: ${temp}°C | Battery: ${battery} (${battery_status}) | RAM: ${ram}"
    
    # Show in OSD
    if [ -d "$OSD_DIR" ]; then
        echo "{\"type\":\"info\",\"size\":1,\"duration\":3000,\"x\":0,\"y\":0,\"message\":\"$msg\",\"icon\":\"\"}" > "$STATS_FILE"
    fi
    
    echo "$msg"
}

# ── Show compact stats ─────────────────────────────────────────────────
show_compact() {
    local temp=$(get_cpu_temp)
    local battery=$(get_battery)
    
    echo "${temp}°C | ${battery}"
}

# ── Main ──────────────────────────────────────────────────────────────
case "${1:-}" in
    show|status)
        show_stats
        ;;
    compact)
        show_compact
        ;;
    cpu)
        get_cpu_freq
        ;;
    temp)
        get_cpu_temp
        ;;
    battery)
        get_battery
        ;;
    ram)
        get_ram_usage
        ;;
    *)
        echo "Usage: osd_stats.sh {show|compact|cpu|temp|battery|ram}" >&2
        echo "" >&2
        echo "Commands:" >&2
        echo "  show     - Show all stats in OSD" >&2
        echo "  compact  - Show compact stats (temp | battery)" >&2
        echo "  cpu      - Show CPU frequency" >&2
        echo "  temp     - Show CPU temperature" >&2
        echo "  battery  - Show battery level" >&2
        echo "  ram      - Show RAM usage" >&2
        exit 1
        ;;
esac
