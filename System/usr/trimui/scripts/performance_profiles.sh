#!/bin/sh
# performance_profiles.sh - Device-Specific Performance Profiles for JukaMix
# Manages performance settings based on device capabilities

CONFIG_FILE="/mnt/SDCARD/System/etc/jukamix.json"
PROFILES_DIR="/mnt/SDCARD/System/etc/profiles"
LOG_FILE="/tmp/performance_profiles.log"

# Create profiles directory
mkdir -p "$PROFILES_DIR" 2>/dev/null

# ── Logging ────────────────────────────────────────────────────────────
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [perf] $1" >> "$LOG_FILE" 2>/dev/null
}

# ── Get device type ────────────────────────────────────────────────────
get_device() {
    cat /etc/trimui_device.txt 2>/dev/null || echo "tsp"
}

# ── Get device capabilities ────────────────────────────────────────────
get_device_capabilities() {
    device="$1"
    
    case "$device" in
        tg5050)
            # Smart Pro S - Most powerful
            echo "cpu_cores=4"
            echo "cpu_max_freq=1800000"
            echo "gpu=opengl"
            echo "ram=2048"
            echo "screen=1280x720"
            echo "bluetooth=yes"
            echo "wifi=yes"
            ;;
        brick_pro)
            # Brick Pro - Mid-range
            echo "cpu_cores=4"
            echo "cpu_max_freq=1500000"
            echo "gpu=opengl"
            echo "ram=1024"
            echo "screen=640x480"
            echo "bluetooth=yes"
            echo "wifi=yes"
            ;;
        brick)
            # Brick - Basic
            echo "cpu_cores=4"
            echo "cpu_max_freq=1200000"
            echo "gpu=opengl"
            echo "ram=512"
            echo "screen=640x480"
            echo "bluetooth=no"
            echo "wifi=yes"
            ;;
        *)
            # TSP - Default
            echo "cpu_cores=4"
            echo "cpu_max_freq=1200000"
            echo "gpu=opengl"
            echo "ram=512"
            echo "screen=640x480"
            echo "bluetooth=no"
            echo "wifi=yes"
            ;;
    esac
}

# ── Apply performance profile ───────────────────────────────────────────
apply_profile() {
    profile="$1"
    device=$(get_device)
    
    log "Applying profile: $profile for device: $device"
    
    # Get device capabilities
    eval "$(get_device_capabilities "$device")"
    
    case "$profile" in
        eco)
            # Eco mode - Maximum battery life
            for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
                [ -w "$cpu" ] && echo "powersave" > "$cpu" 2>/dev/null
            done
            
            # Set max frequency to 50% of device max
            max_freq=$((cpu_max_freq / 2))
            for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_max_freq; do
                [ -w "$cpu" ] && echo "$max_freq" > "$cpu" 2>/dev/null
            done
            
            # Dim screen
            echo 30 > /sys/class/backlight/backlight/brightness 2>/dev/null
            
            # Disable Wi-Fi if possible
            if [ "$wifi" = "yes" ]; then
                ifconfig wlan0 down 2>/dev/null
            fi
            
            log "Eco profile applied"
            echo "Eco profile applied"
            ;;
        
        balanced)
            # Balanced mode - Good performance, reasonable battery
            for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
                [ -w "$cpu" ] && echo "ondemand" > "$cpu" 2>/dev/null
            done
            
            # Set max frequency to 75% of device max
            max_freq=$((cpu_max_freq * 75 / 100))
            for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_max_freq; do
                [ -w "$cpu" ] && echo "$max_freq" > "$cpu" 2>/dev/null
            done
            
            # Normal brightness
            echo 50 > /sys/class/backlight/backlight/brightness 2>/dev/null
            
            log "Balanced profile applied"
            echo "Balanced profile applied"
            ;;
        
        performance)
            # Performance mode - Maximum performance
            for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
                [ -w "$cpu" ] && echo "performance" > "$cpu" 2>/dev/null
            done
            
            # Set max frequency to device max
            for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_max_freq; do
                [ -w "$cpu" ] && echo "$cpu_max_freq" > "$cpu" 2>/dev/null
            done
            
            # Full brightness
            echo 100 > /sys/class/backlight/backlight/brightness 2>/dev/null
            
            log "Performance profile applied"
            echo "Performance profile applied"
            ;;
        
        gaming)
            # Gaming mode - Optimized for emulators
            for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
                [ -w "$cpu" ] && echo "performance" > "$cpu" 2>/dev/null
            done
            
            # Set max frequency to 90% of device max (balance heat)
            max_freq=$((cpu_max_freq * 90 / 100))
            for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_max_freq; do
                [ -w "$cpu" ] && echo "$max_freq" > "$cpu" 2>/dev/null
            done
            
            # High brightness
            echo 80 > /sys/class/backlight/backlight/brightness 2>/dev/null
            
            log "Gaming profile applied"
            echo "Gaming profile applied"
            ;;
        
        *)
            echo "Unknown profile: $profile"
            return 1
            ;;
    esac
    
    # Save current profile to config
    if [ -f "$CONFIG_FILE" ] && command -v jq >/dev/null 2>&1; then
        jq --arg profile "$profile" '. += {"PERFORMANCE_PROFILE": $profile}' "$CONFIG_FILE" > /tmp/jukamix_tmp.json 2>/dev/null && \
        mv /tmp/jukamix_tmp.json "$CONFIG_FILE" 2>/dev/null
    fi
    
    return 0
}

# ── Get current profile ────────────────────────────────────────────────
get_current_profile() {
    if [ -f "$CONFIG_FILE" ] && command -v jq >/dev/null 2>&1; then
        jq -r '.["PERFORMANCE_PROFILE"] // "balanced"' "$CONFIG_FILE" 2>/dev/null
    else
        echo "balanced"
    fi
}

# ── Create custom profile ───────────────────────────────────────────────
create_custom_profile() {
    profile_name="$1"
    cpu_governor="${2:-ondemand}"
    cpu_freq_percent="${3:-75}"
    brightness="${4:-50}"
    
    if [ -z "$profile_name" ]; then
        echo "Usage: performance_profiles.sh create <name> [governor] [freq_percent] [brightness]"
        return 1
    fi
    
    profile_file="$PROFILES_DIR/${profile_name}.conf"
    
    cat > "$profile_file" << EOF
# Custom Performance Profile: $profile_name
# Created: $(date)

CPU_GOVERNOR=$cpu_governor
CPU_FREQ_PERCENT=$cpu_freq_percent
BRIGHTNESS=$brightness
EOF
    
    log "Created custom profile: $profile_name"
    echo "Custom profile created: $profile_name"
}

# ── Apply custom profile ────────────────────────────────────────────────
apply_custom_profile() {
    profile_name="$1"
    profile_file="$PROFILES_DIR/${profile_name}.conf"
    
    if [ ! -f "$profile_file" ]; then
        echo "Profile not found: $profile_name"
        return 1
    fi
    
    # Source the profile
    . "$profile_file"
    
    device=$(get_device)
    eval "$(get_device_capabilities "$device")"
    
    # Apply CPU governor
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        [ -w "$cpu" ] && echo "$CPU_GOVERNOR" > "$cpu" 2>/dev/null
    done
    
    # Apply CPU frequency
    max_freq=$((cpu_max_freq * CPU_FREQ_PERCENT / 100))
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_max_freq; do
        [ -w "$cpu" ] && echo "$max_freq" > "$cpu" 2>/dev/null
    done
    
    # Apply brightness
    echo "$BRIGHTNESS" > /sys/class/backlight/backlight/brightness 2>/dev/null
    
    log "Applied custom profile: $profile_name"
    echo "Applied custom profile: $profile_name"
}

# ── List profiles ────────────────────────────────────────────────────────
list_profiles() {
    echo "Available Performance Profiles:"
    echo "==============================="
    echo ""
    
    echo "Built-in Profiles:"
    echo "  eco         - Maximum battery life"
    echo "  balanced    - Good performance, reasonable battery"
    echo "  performance - Maximum performance"
    echo "  gaming      - Optimized for emulators"
    echo ""
    
    # List custom profiles
    custom_count=0
    for profile in "$PROFILES_DIR"/*.conf; do
        [ -f "$profile" ] || continue
        
        profile_name=$(basename "$profile" .conf)
        echo "  $profile_name (custom)"
        custom_count=$((custom_count + 1))
    done
    
    if [ "$custom_count" -eq 0 ]; then
        echo "  No custom profiles"
    fi
    
    echo ""
    echo "Current profile: $(get_current_profile)"
}

# ── Monitor performance ─────────────────────────────────────────────────
monitor_performance() {
    echo "Performance Monitor:"
    echo "==================="
    echo ""
    
    # CPU usage
    cpu_usage=$(top -bn1 2>/dev/null | grep "CPU:" | awk '{print $2}' || echo "N/A")
    echo "CPU Usage: $cpu_usage%"
    
    # Memory usage
    if [ -f /proc/meminfo ]; then
        total=$(grep "MemTotal" /proc/meminfo | awk '{print $2}')
        free=$(grep "MemAvailable" /proc/meminfo | awk '{print $2}')
        used=$((total - free))
        percent=$((used * 100 / total))
        echo "Memory: ${percent}% used"
    fi
    
    # Temperature
    if [ -f /sys/class/thermal/thermal_zone0/temp ]; then
        temp=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null)
        temp=$((temp / 1000))
        echo "Temperature: ${temp}°C"
    fi
    
    # Battery
    if [ -f /sys/class/power_supply/battery/capacity ]; then
        battery=$(cat /sys/class/power_supply/battery/capacity 2>/dev/null)
        echo "Battery: ${battery}%"
    fi
    
    # Current profile
    echo "Profile: $(get_current_profile)"
}

# ── Main ───────────────────────────────────────────────────────────────
case "${1:-}" in
    apply)
        apply_profile "${2:-balanced}"
        ;;
    get)
        get_current_profile
        ;;
    list)
        list_profiles
        ;;
    create)
        create_custom_profile "${2:-}" "${3:-ondemand}" "${4:-75}" "${5:-50}"
        ;;
    apply-custom)
        apply_custom_profile "${2:-}"
        ;;
    monitor)
        monitor_performance
        ;;
    capabilities)
        get_device_capabilities "$(get_device)"
        ;;
    *)
        echo "Device-Specific Performance Profiles"
        echo "Usage: performance_profiles.sh {apply|get|list|create|apply-custom|monitor|capabilities}"
        echo ""
        echo "Commands:"
        echo "  apply <profile>      - Apply built-in profile"
        echo "  get                  - Get current profile"
        echo "  list                 - List available profiles"
        echo "  create <name> ...    - Create custom profile"
        echo "  apply-custom <name>  - Apply custom profile"
        echo "  monitor              - Monitor performance"
        echo "  capabilities         - Show device capabilities"
        ;;
esac
