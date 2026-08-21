#!/bin/sh
# System/usr/trimui/scripts/deep_sleep.sh
# Deep Sleep mode - extends battery life when device is idle

SCRIPTS_DIR="/mnt/SDCARD/System/usr/trimui/scripts"
CONFIG_FILE="/mnt/SDCARD/System/etc/jukamix.json"
LOG_FILE="/tmp/deep_sleep.log"

# Logging
log() {
    echo "$(date '+%H:%M:%S') [deep_sleep] $1" >> "$LOG_FILE"
}

# ── Check if deep sleep is enabled ────────────────────────────────────
is_enabled() {
    if [ -f "$CONFIG_FILE" ]; then
        # Try jq first, fallback to grep
        if command -v jq >/dev/null 2>&1; then
            enabled=$(jq -r '.["DEEP_SLEEP"] // "enabled"' "$CONFIG_FILE" 2>/dev/null)
        else
            enabled=$(grep -o '"DEEP_SLEEP"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" 2>/dev/null | sed 's/.*"\([^"]*\)"$/\1/')
        fi
        [ "$enabled" != "disabled" ]
    else
        return 0  # Enabled by default
    fi
}

# ── Get idle timeout (in seconds) ─────────────────────────────────────
get_idle_timeout() {
    if [ -f "$CONFIG_FILE" ]; then
        # Try jq first, fallback to grep
        if command -v jq >/dev/null 2>&1; then
            jq -r '.["IDLE_TIMEOUT"] // "120"' "$CONFIG_FILE" 2>/dev/null
        else
            timeout=$(grep -o '"IDLE_TIMEOUT"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" 2>/dev/null | sed 's/.*"\([^"]*\)"$/\1/')
            echo "${timeout:-120}"
        fi
    else
        echo "120"  # Default 2 minutes
    fi
}

# ── Enter light sleep ─────────────────────────────────────────────────
enter_light_sleep() {
    log "Entering light sleep"
    
    # Turn off screen (with safeguard)
    if [ -w "/sys/class/backlight/backlight/brightness" ]; then
        echo 0 > /sys/class/backlight/backlight/brightness 2>/dev/null
    fi
    
    # Pulse LEDs to indicate sleep
    if [ -w "/sys/class/led_anim/effect_enable" ]; then
        echo 1 > /sys/class/led_anim/effect_enable 2>/dev/null
        echo "0000FF" > /sys/class/led_anim/effect_rgb_hex_lr 2>/dev/null
        echo "5" > /sys/class/led_anim/effect_cycles_lr 2>/dev/null
        echo "1000" > /sys/class/led_anim/effect_duration_lr 2>/dev/null
        echo "5" > /sys/class/led_anim/effect_lr 2>/dev/null
    fi
}

# ── Enter deep sleep ──────────────────────────────────────────────────
enter_deep_sleep() {
    log "Entering deep sleep"
    
    # Turn off screen (with safeguard)
    if [ -w "/sys/class/backlight/backlight/brightness" ]; then
        echo 0 > /sys/class/backlight/backlight/brightness 2>/dev/null
    fi
    
    # Turn off all LEDs (with safeguard)
    if [ -w "/sys/class/led_anim/effect_enable" ]; then
        echo 0 > /sys/class/led_anim/effect_enable 2>/dev/null
    fi
    
    # Reduce CPU frequency to minimum (with safeguard)
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        [ -w "$cpu" ] && echo "powersave" > "$cpu" 2>/dev/null
    done
    
    # Set up wakeup on power button press (with safeguard)
    if [ -f "/sys/class/input/input0/wakeup" ] && [ -w "/sys/class/input/input0/wakeup" ]; then
        echo "enabled" > /sys/class/input/input0/wakeup 2>/dev/null
    fi
}

# ── Wake from deep sleep ──────────────────────────────────────────────
wake_up() {
    log "Waking from deep sleep"
    
    # Restore screen brightness (with safeguard)
    brightness=50  # Default
    if [ -f "$CONFIG_FILE" ] && command -v jq >/dev/null 2>&1; then
        brightness=$(jq -r '.["BRIGHTNESS"] // "50"' "$CONFIG_FILE" 2>/dev/null || echo "50")
    fi
    if [ -w "/sys/class/backlight/backlight/brightness" ]; then
        echo "$brightness" > /sys/class/backlight/backlight/brightness 2>/dev/null
    fi
    
    # Restore LED state (with safeguard)
    if [ -w "/sys/class/led_anim/effect_enable" ]; then
        echo 0 > /sys/class/led_anim/effect_enable 2>/dev/null
    fi
    
    # Restore CPU governor (with safeguard)
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        [ -w "$cpu" ] && echo "ondemand" > "$cpu" 2>/dev/null
    done
    
    log "Wake up complete"
}

# ── Monitor idle state ────────────────────────────────────────────────
monitor_idle() {
    local timeout=$(get_idle_timeout)
    local last_input_time=$(date +%s)
    local light_sleep_triggered=0
    local check_interval=30  # Check every 30 seconds instead of 10
    
    log "Monitoring idle state (timeout: ${timeout}s)"
    
    while true; do
        sleep $check_interval
        
        local current_time=$(date +%s)
        local idle_time=$((current_time - last_input_time))
        
        # Check for user input (button press) - only if file exists
        if [ -f "/tmp/input_event" ] && [ -s "/tmp/input_event" ]; then
            last_input_time=$(date +%s)
            rm -f "/tmp/input_event" 2>/dev/null
            
            if [ "$light_sleep_triggered" -eq 1 ]; then
                wake_up
                light_sleep_triggered=0
            fi
        fi
        
        # Enter light sleep after half timeout
        if [ "$idle_time" -gt $((timeout / 2)) ] && [ "$light_sleep_triggered" -eq 0 ]; then
            enter_light_sleep
            light_sleep_triggered=1
        fi
        
        # Enter deep sleep after full timeout
        if [ "$idle_time" -gt "$timeout" ]; then
            enter_deep_sleep
            
            # Wait for wakeup event - with timeout to avoid infinite loop
            local wait_count=0
            while [ $wait_count -lt 60 ]; do
                sleep 2
                wait_count=$((wait_count + 1))
                
                # Check for power button press
                if [ -f "/tmp/wakeup_event" ]; then
                    wake_up
                    rm -f "/tmp/wakeup_event"
                    break
                fi
                
                # Check for any input
                if [ -f "/tmp/input_event" ] && [ -s "/tmp/input_event" ]; then
                    wake_up
                    rm -f "/tmp/input_event"
                    break
                fi
            done
            
            last_input_time=$(date +%s)
            light_sleep_triggered=0
        fi
    done
}

# ── Main ──────────────────────────────────────────────────────────────
case "${1:-}" in
    start)
        if is_enabled; then
            log "Starting deep sleep monitor"
            monitor_idle &
        fi
        ;;
    stop)
        log "Stopping deep sleep monitor"
        pkill -f "deep_sleep.sh"
        ;;
    status)
        if is_enabled; then
            echo "Deep sleep: enabled"
        else
            echo "Deep sleep: disabled"
        fi
        ;;
    *)
        echo "Usage: deep_sleep.sh {start|stop|status}" >&2
        exit 1
        ;;
esac
