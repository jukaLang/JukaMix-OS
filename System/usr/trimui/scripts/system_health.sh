#!/bin/sh
# system_health.sh - System Health Monitor for JukaMix
# Monitors CPU, memory, storage, temperature, and battery
# Provides alerts and recommendations

LOG_FILE="/tmp/system_health.log"
ALERT_FILE="/tmp/system_health_alerts.txt"
HISTORY_DIR="/mnt/SDCARD/trimui/health_history"
CONFIG_FILE="/mnt/SDCARD/System/etc/jukamix.json"

# Create directories
mkdir -p "$HISTORY_DIR" 2>/dev/null

# ── Logging ────────────────────────────────────────────────────────────
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [health] $1" >> "$LOG_FILE" 2>/dev/null
}

# ── Alert system ───────────────────────────────────────────────────────
alert() {
    level="$1"
    message="$2"
    
    echo "[$level] $message" >> "$ALERT_FILE" 2>/dev/null
    log "ALERT [$level]: $message"
}

# ── Get CPU usage ──────────────────────────────────────────────────────
get_cpu_usage() {
    # Read /proc/stat
    read cpu user nice system idle rest < /proc/stat 2>/dev/null
    
    total=$((user + nice + system + idle))
    used=$((user + nice + system))
    
    # Calculate percentage
    if [ "$total" -gt 0 ]; then
        percentage=$((used * 100 / total))
    else
        percentage=0
    fi
    
    echo "$percentage"
}

# ── Get CPU temperature ────────────────────────────────────────────────
get_cpu_temperature() {
    # Try thermal zone
    if [ -f /sys/class/thermal/thermal_zone0/temp ]; then
        temp=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null)
        if [ -n "$temp" ] && [ "$temp" -gt 0 ]; then
            # Convert millidegrees to degrees
            temp=$((temp / 1000))
            echo "$temp"
            return
        fi
    fi
    
    # Try hwmon
    for hwmon in /sys/class/hwmon/hwmon*/temp*_input; do
        if [ -f "$hwmon" ]; then
            temp=$(cat "$hwmon" 2>/dev/null)
            if [ -n "$temp" ] && [ "$temp" -gt 0 ]; then
                temp=$((temp / 1000))
                echo "$temp"
                return
            fi
        fi
    done
    
    echo "0"
}

# ── Get memory usage ───────────────────────────────────────────────────
get_memory_usage() {
    if [ -f /proc/meminfo ]; then
        total=$(grep "MemTotal" /proc/meminfo | awk '{print $2}')
        free=$(grep "MemAvailable" /proc/meminfo | awk '{print $2}')
        
        if [ -n "$total" ] && [ -n "$free" ] && [ "$total" -gt 0 ]; then
            used=$((total - free))
            percentage=$((used * 100 / total))
            echo "$percentage"
            return
        fi
    fi
    
    echo "0"
}

# ── Get storage usage ──────────────────────────────────────────────────
get_storage_usage() {
    mount_point="${1:-/mnt/SDCARD}"
    
    if [ -d "$mount_point" ]; then
        # Get usage in KB
        usage=$(df "$mount_point" 2>/dev/null | tail -1 | awk '{print $5}' | tr -d '%')
        if [ -n "$usage" ]; then
            echo "$usage"
            return
        fi
    fi
    
    echo "0"
}

# ── Get battery level ──────────────────────────────────────────────────
get_battery_level() {
    # Try power supply
    for battery in /sys/class/power_supply/battery/capacity; do
        if [ -f "$battery" ]; then
            level=$(cat "$battery" 2>/dev/null)
            if [ -n "$level" ] && [ "$level" -ge 0 ] && [ "$level" -le 100 ]; then
                echo "$level"
                return
            fi
        fi
    done
    
    # Try UPower
    if command -v upower >/dev/null 2>&1; then
        level=$(upower -i /org/freedesktop/UPower/devices/battery_BAT0 2>/dev/null | grep "percentage" | awk '{print $2}' | tr -d '%')
        if [ -n "$level" ]; then
            echo "$level"
            return
        fi
    fi
    
    echo "100"  # Assume full if can't read
}

# ── Get battery status ─────────────────────────────────────────────────
get_battery_status() {
    for battery in /sys/class/power_supply/battery/status; do
        if [ -f "$battery" ]; then
            status=$(cat "$battery" 2>/dev/null)
            if [ -n "$status" ]; then
                echo "$status"
                return
            fi
        fi
    done
    
    echo "Unknown"
}

# ── Check storage health ───────────────────────────────────────────────
check_storage_health() {
    mount_point="${1:-/mnt/SDCARD}"
    
    # Check if mount point is accessible
    if ! mountpoint -q "$mount_point" 2>/dev/null; then
        alert "CRITICAL" "Storage not mounted at $mount_point"
        return 1
    fi
    
    # Check available space
    available=$(df "$mount_point" 2>/dev/null | tail -1 | awk '{print $4}')
    if [ -n "$available" ] && [ "$available" -lt 102400 ]; then  # Less than 100MB
        alert "WARNING" "Low storage: ${available}KB available"
        return 1
    fi
    
    # Check for read-only filesystem
    if ! touch "$mount_point/.health_check_tmp" 2>/dev/null; then
        alert "CRITICAL" "Storage is read-only"
        return 1
    fi
    rm -f "$mount_point/.health_check_tmp" 2>/dev/null
    
    return 0
}

# ── Check process health ───────────────────────────────────────────────
check_process_health() {
    # Check if MainUI is running
    if ! pgrep -x "MainUI" >/dev/null 2>&1; then
        alert "WARNING" "MainUI not running"
    fi
    
    # Check if inputd is running
    if ! pgrep -x "inputd" >/dev/null 2>&1; then
        alert "WARNING" "inputd not running"
    fi
    
    # Check for zombie processes
    zombies=$(ps aux 2>/dev/null | grep -c "Z" || echo "0")
    if [ "$zombies" -gt 5 ]; then
        alert "WARNING" "Multiple zombie processes detected: $zombies"
    fi
    
    # Check for high CPU processes
    high_cpu=$(ps aux 2>/dev/null | awk '$3 > 50 {print $11}' | head -1)
    if [ -n "$high_cpu" ]; then
        alert "INFO" "High CPU process: $high_cpu"
    fi
}

# ── Check temperature alerts ───────────────────────────────────────────
check_temperature() {
    temp=$(get_cpu_temperature)
    
    if [ "$temp" -gt 80 ]; then
        alert "CRITICAL" "CPU temperature critical: ${temp}°C"
        # Throttle CPU
        for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
            [ -w "$cpu" ] && echo "powersave" > "$cpu" 2>/dev/null
        done
    elif [ "$temp" -gt 70 ]; then
        alert "WARNING" "CPU temperature high: ${temp}°C"
    elif [ "$temp" -gt 60 ]; then
        alert "INFO" "CPU temperature elevated: ${temp}°C"
    fi
}

# ── Check battery alerts ───────────────────────────────────────────────
check_battery() {
    level=$(get_battery_level)
    status=$(get_battery_status)
    
    if [ "$level" -le 10 ] && [ "$status" != "Charging" ]; then
        alert "CRITICAL" "Battery critically low: ${level}%"
        # Enable aggressive power saving
        for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
            [ -w "$cpu" ] && echo "powersave" > "$cpu" 2>/dev/null
        done
        echo 20 > /sys/class/backlight/backlight/brightness 2>/dev/null
    elif [ "$level" -le 20 ] && [ "$status" != "Charging" ]; then
        alert "WARNING" "Battery low: ${level}%"
    elif [ "$level" -le 30 ] && [ "$status" != "Charging" ]; then
        alert "INFO" "Battery getting low: ${level}%"
    fi
}

# ── Generate health report ─────────────────────────────────────────────
generate_report() {
    cpu_usage=$(get_cpu_usage)
    cpu_temp=$(get_cpu_temperature)
    mem_usage=$(get_memory_usage)
    storage_usage=$(get_storage_usage)
    battery_level=$(get_battery_level)
    battery_status=$(get_battery_status)
    
    report="╔══════════════════════════════════════╗"
    report="$report\n║      JukaMix System Health           ║"
    report="$report\n╠══════════════════════════════════════╣"
    report="$report\n║ CPU Usage:     ${cpu_usage}%"
    report="$report\n║ CPU Temp:      ${cpu_temp}°C"
    report="$report\n║ Memory Usage:  ${mem_usage}%"
    report="$report\n║ Storage Usage: ${storage_usage}%"
    report="$report\n║ Battery:       ${battery_level}% ($battery_status)"
    report="$report\n╠══════════════════════════════════════╣"
    
    # Add alerts
    if [ -f "$ALERT_FILE" ]; then
        alert_count=$(wc -l < "$ALERT_FILE" 2>/dev/null || echo "0")
        if [ "$alert_count" -gt 0 ]; then
            report="$report\n║ Alerts: $alert_count"
            tail -3 "$ALERT_FILE" | while IFS= read -r alert_line; do
                report="$report\n║   $alert_line"
            done
        else
            report="$report\n║ Status: All systems nominal"
        fi
    else
        report="$report\n║ Status: All systems nominal"
    fi
    
    report="$report\n╚══════════════════════════════════════╝"
    
    echo -e "$report"
}

# ── Save health data ───────────────────────────────────────────────────
save_health_data() {
    timestamp=$(date +%Y%m%d_%H%M%S)
    data_file="$HISTORY_DIR/health_${timestamp}.txt"
    
    {
        echo "Timestamp: $(date)"
        echo "CPU Usage: $(get_cpu_usage)%"
        echo "CPU Temperature: $(get_cpu_temperature)°C"
        echo "Memory Usage: $(get_memory_usage)%"
        echo "Storage Usage: $(get_storage_usage)%"
        echo "Battery Level: $(get_battery_level)%"
        echo "Battery Status: $(get_battery_status)"
    } > "$data_file" 2>/dev/null
    
    # Keep only last 24 hours of data (assuming hourly checks)
    find "$HISTORY_DIR" -name "health_*.txt" -mtime +1 -delete 2>/dev/null
}

# ── Run health check ───────────────────────────────────────────────────
run_health_check() {
    log "Starting health check"
    
    # Clear previous alerts
    > "$ALERT_FILE" 2>/dev/null
    
    # Run all checks
    check_temperature
    check_battery
    check_process_health
    check_storage_health
    
    # Generate and display report
    generate_report
    
    # Save health data
    save_health_data
    
    log "Health check complete"
}

# ── Show alerts via OSD ────────────────────────────────────────────────
show_alerts_osd() {
    if [ -f "$ALERT_FILE" ]; then
        critical=$(grep -c "CRITICAL" "$ALERT_FILE" 2>/dev/null || echo "0")
        warning=$(grep -c "WARNING" "$ALERT_FILE" 2>/dev/null || echo "0")
        
        if [ "$critical" -gt 0 ]; then
            alert_msg="CRITICAL: $critical critical alerts"
            /mnt/SDCARD/System/usr/trimui/scripts/infoscreen.sh -i "/mnt/SDCARD/System/resources/error.png" -t "$alert_msg" -d 3000
        elif [ "$warning" -gt 0 ]; then
            alert_msg="WARNING: $warning warnings detected"
            /mnt/SDCARD/System/usr/trimui/scripts/infoscreen.sh -i "/mnt/SDCARD/System/resources/warning.png" -t "$alert_msg" -d 2000
        fi
    fi
}

# ── Main ───────────────────────────────────────────────────────────────
case "${1:-}" in
    check)
        run_health_check
        ;;
    report)
        generate_report
        ;;
    alerts)
        show_alerts_osd
        ;;
    status)
        cpu=$(get_cpu_usage)
        temp=$(get_cpu_temperature)
        mem=$(get_memory_usage)
        bat=$(get_battery_level)
        echo "CPU: ${cpu}% | Temp: ${temp}°C | RAM: ${mem}% | Battery: ${bat}%"
        ;;
    *)
        echo "System Health Monitor"
        echo "Usage: system_health.sh {check|report|alerts|status}"
        echo ""
        echo "Commands:"
        echo "  check    - Run full health check"
        echo "  report   - Show health report"
        echo "  alerts   - Show alerts via OSD"
        echo "  status   - Quick status summary"
        ;;
esac
