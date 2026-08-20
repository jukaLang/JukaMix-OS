#!/bin/sh
# TG5050 Thermal & Power Management Script
# Optimized for Allwinner A523 SoC in TrimUI Smart Pro S

# This script monitors temperature and adjusts CPU frequency/governor accordingly
# to prevent thermal throttling while maintaining performance

# Configuration
TEMP_THRESHOLD_HIGH="85"    # °C - switch to conservative mode
TEMP_THRESHOLD_MEDIUM="75"  # °C - warn and consider reducing freq
TEMP_THRESHOLD_LOW="65"     # °C - safe zone, can use performance mode

# Get current temperature (try multiple sources)
get_temperature() {
    # Try thermal zones first
    if [ -f "/sys/class/thermal/thermal_zone*/temp" ]; then
        _temp=$(cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null | head -n 1 | sed 's/\..*//')
        [ -n "$_temp" ] && echo "$_temp" && return 0
    fi
    
    # Try CPU temp
    if [ -f "/sys/devices/virtual/thermal/thermal_zone*/temp" ]; then
        _temp=$(cat /sys/devices/virtual/thermal/thermal_zone*/temp 2>/dev/null | head -n 1 | sed 's/\..*//')
        [ -n "$_temp" ] && echo "$_temp" && return 0
    fi
    
    # Fallback: assume 50°C if no sensors available
    echo "50"
}

# Apply governor based on temperature
apply_governor_by_temp() {
    _temp=$(get_temperature)
    
    if [ "$_temp" -ge "$TEMP_THRESHOLD_HIGH" ]; then
        echo "High temp (${_temp}°C): switching to conservative governor"
        sh /mnt/SDCARD/System/usr/trimui/scripts/tg5050_cpufreq.sh conservative 1 4 4 >/dev/null 2>&1
    elif [ "$_temp" -ge "$TEMP_THRESHOLD_MEDIUM" ]; then
        echo "Medium temp (${_temp}°C): switching to ondemand governor"
        sh /mnt/SDCARD/System/usr/trimui/scripts/tg5050_cpufreq.sh ondemand 2 6 4 >/dev/null 2>&1
    else
        echo "Low temp (${_temp}°C): using performance governor"
        sh /mnt/SDCARD/System/usr/trimui/scripts/tg5050_cpufreq.sh performance 3 7 4 >/dev/null 2>&1
    fi
    
    unset _temp
}

# Show current thermal status
show_thermal_status() {
    _temp=$(get_temperature)
    _gov=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null)
    _min_freq=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq 2>/dev/null)
    _max_freq=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq 2>/dev/null)
    
    echo "=== TG5050 Thermal Status ==="
    echo "Temperature: ${_temp}°C"
    echo "Governor: $_gov"
    echo "Frequency range: ${_min_freq} - ${_max_freq} kHz"
    echo ""
    
    if [ "$_temp" -ge "$TEMP_THRESHOLD_HIGH" ]; then
        echo "⚠️  WARNING: High temperature! Consider cooling or reducing load."
    elif [ "$_temp" -ge "$TEMP_THRESHOLD_MEDIUM" ]; then
        echo "ℹ️  Medium temperature - normal operation."
    else
        echo "✅  Good temperature - optimal performance."
    fi
    
    unset _temp _gov _min_freq _max_freq
}

# Main execution
case "${1:-status}" in
    --status|-s)
        show_thermal_status
        ;;
    --auto|-a)
        apply_governor_by_temp
        ;;
    --performance|-p)
        echo "Setting performance mode (3-7 GHz, 4 cores)"
        sh /mnt/SDCARD/System/usr/trimui/scripts/tg5050_cpufreq.sh performance 3 7 4 >/dev/null 2>&1
        ;;
    --balanced|-b)
        echo "Setting balanced mode (2-6 GHz, 4 cores)"
        sh /mnt/SDCARD/System/usr/trimui/scripts/tg5050_cpufreq.sh ondemand 2 6 4 >/dev/null 2>&1
        ;;
    --conservative|-c)
        echo "Setting conservative mode (1-4 GHz, 4 cores)"
        sh /mnt/SDCARD/System/usr/trimui/scripts/tg5050_cpufreq.sh conservative 1 4 4 >/dev/null 2>&1
        ;;
    --help|-h)
        echo "Usage: $0 [--status|-s] [--auto|-a] [--performance|-p] [--balanced|-b] [--conservative|-c]"
        echo ""
        echo "Options:"
        echo "  --status, -s    Show current thermal status"
        echo "  --auto, -a      Auto-adjust governor based on temperature"
        echo "  --performance, -p  Set performance mode (highest frequencies)"
        echo "  --balanced, -b   Set balanced mode (default for TG5050)"
        echo "  --conservative, -c Set conservative mode (lowest power)"
        ;;
    *)
        echo "Unknown option: $1"
        echo "Use --help for usage information"
        exit 1
        ;;
esac

exit 0