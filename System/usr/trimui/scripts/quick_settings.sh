#!/bin/sh
# System/usr/trimui/scripts/quick_settings.sh
# Quick Settings - Easy access to common settings

SCRIPTS_DIR="/mnt/SDCARD/System/usr/trimui/scripts"
OSD_DIR="/tmp/trimui_osd"
CONFIG_DIR="/mnt/SDCARD/trimui/settings"

# Create settings directory
mkdir -p "$CONFIG_DIR"

# ── Show quick settings menu ───────────────────────────────────────────
show_menu() {
    echo "=== JukaMix Quick Settings ==="
    echo ""
    echo "1. WiFi: $(get_wifi_status)"
    echo "2. Bluetooth: $(get_bt_status)"
    echo "3. Brightness: $(get_brightness)%"
    echo "4. Volume: $(get_volume)%"
    echo "5. LED: $(get_led_status)"
    echo "6. Deep Sleep: $(get_sleep_status)"
    echo "7. FPS Display: $(get_fps_status)"
    echo ""
    echo "Commands:"
    echo "  wifi [on|off]        - Toggle WiFi"
    echo "  bt [on|off]          - Toggle Bluetooth"
    echo "  brightness [0-100]   - Set brightness"
    echo "  volume [0-100]       - Set volume"
    echo "  led [on|off|color]   - Control LED"
    echo "  sleep [on|off]       - Toggle deep sleep"
    echo "  fps [on|off]         - Toggle FPS display"
    echo "  battery              - Show battery info"
    echo "  info                 - Show system info"
}

# ── Get WiFi status ────────────────────────────────────────────────────
get_wifi_status() {
    if [ -d /sys/class/net/wlan0 ]; then
        local status=$(cat /sys/class/net/wlan0/operstate 2>/dev/null)
        if [ "$status" = "up" ]; then
            echo "ON"
        else
            echo "OFF"
        fi
    else
        echo "N/A"
    fi
}

# ── Get Bluetooth status ───────────────────────────────────────────────
get_bt_status() {
    if command -v bluetoothctl >/dev/null 2>&1; then
        local powered=$(bluetoothctl show 2>/dev/null | grep "Powered" | awk '{print $2}')
        if [ "$powered" = "yes" ]; then
            echo "ON"
        else
            echo "OFF"
        fi
    else
        echo "N/A"
    fi
}

# ── Get brightness ─────────────────────────────────────────────────────
get_brightness() {
    if [ -f /sys/class/backlight/*/brightness ]; then
        local current=$(cat /sys/class/backlight/*/brightness 2>/dev/null)
        local max=$(cat /sys/class/backlight/*/max_brightness 2>/dev/null)
        echo $((current * 100 / max))
    else
        echo "N/A"
    fi
}

# ── Get volume ─────────────────────────────────────────────────────────
get_volume() {
    if command -v amixer >/dev/null 2>&1; then
        amixer get Master 2>/dev/null | grep -o '[0-9]*%' | head -1
    else
        echo "N/A"
    fi
}

# ── Get LED status ─────────────────────────────────────────────────────
get_led_status() {
    if [ -f /sys/class/led_anim/effect_enable ]; then
        local enabled=$(cat /sys/class/led_anim/effect_enable 2>/dev/null)
        if [ "$enabled" = "1" ]; then
            echo "ON"
        else
            echo "OFF"
        fi
    else
        echo "N/A"
    fi
}

# ── Get sleep status ───────────────────────────────────────────────────
get_sleep_status() {
    local config="$CONFIG_DIR/deep_sleep.conf"
    
    if [ -f "$config" ]; then
        local enabled=$(grep "^enabled=" "$config" | cut -d= -f2)
        if [ "$enabled" = "true" ]; then
            echo "ON"
        else
            echo "OFF"
        fi
    else
        echo "ON"
    fi
}

# ── Get FPS status ─────────────────────────────────────────────────────
get_fps_status() {
    local config="/mnt/SDCARD/RetroArch/.retroarch/retroarch.cfg"
    
    if [ -f "$config" ]; then
        local fps=$(grep "fps_show" "$config" | head -1 | awk -F' = ' '{print $2}' | tr -d '"')
        if [ "$fps" = "true" ]; then
            echo "ON"
        else
            echo "OFF"
        fi
    else
        echo "N/A"
    fi
}

# ── Toggle WiFi ────────────────────────────────────────────────────────
toggle_wifi() {
    local state="$1"
    local iface="wlan0"
    
    if [ "$state" = "on" ]; then
        ifconfig "$iface" up 2>/dev/null
        echo "WiFi ON"
    elif [ "$state" = "off" ]; then
        ifconfig "$iface" down 2>/dev/null
        echo "WiFi OFF"
    else
        # Toggle
        local current=$(get_wifi_status)
        if [ "$current" = "ON" ]; then
            toggle_wifi "off"
        else
            toggle_wifi "on"
        fi
    fi
}

# ── Toggle Bluetooth ───────────────────────────────────────────────────
toggle_bt() {
    local state="$1"
    
    if command -v bluetoothctl >/dev/null 2>&1; then
        if [ "$state" = "on" ]; then
            bluetoothctl power on 2>/dev/null
            echo "Bluetooth ON"
        elif [ "$state" = "off" ]; then
            bluetoothctl power off 2>/dev/null
            echo "Bluetooth OFF"
        else
            # Toggle
            local current=$(get_bt_status)
            if [ "$current" = "ON" ]; then
                toggle_bt "off"
            else
                toggle_bt "on"
            fi
        fi
    else
        echo "Bluetooth not available"
    fi
}

# ── Set brightness ─────────────────────────────────────────────────────
set_brightness() {
    local value="$1"
    
    if [ -f /sys/class/backlight/*/max_brightness ]; then
        local max=$(cat /sys/class/backlight/*/max_brightness 2>/dev/null)
        local level=$((value * max / 100))
        echo "$level" > /sys/class/backlight/*/brightness 2>/dev/null
        echo "Brightness: $value%"
    else
        echo "Brightness control not available"
    fi
}

# ── Set volume ─────────────────────────────────────────────────────────
set_volume() {
    local value="$1"
    
    if command -v amixer >/dev/null 2>&1; then
        amixer set Master "$value%" 2>/dev/null
        echo "Volume: $value%"
    else
        echo "Volume control not available"
    fi
}

# ── Toggle LED ─────────────────────────────────────────────────────────
toggle_led() {
    local state="$1"
    local led_file="/sys/class/led_anim/effect_enable"
    
    if [ -f "$led_file" ]; then
        if [ "$state" = "on" ]; then
            echo 1 > "$led_file" 2>/dev/null
            echo "LED ON"
        elif [ "$state" = "off" ]; then
            echo 0 > "$led_file" 2>/dev/null
            echo "LED OFF"
        else
            # Toggle
            local current=$(get_led_status)
            if [ "$current" = "ON" ]; then
                toggle_led "off"
            else
                toggle_led "on"
            fi
        fi
    else
        echo "LED control not available"
    fi
}

# ── Toggle deep sleep ──────────────────────────────────────────────────
toggle_sleep() {
    local state="$1"
    local config="$CONFIG_DIR/deep_sleep.conf"
    
    mkdir -p "$(dirname "$config")"
    
    if [ "$state" = "on" ]; then
        echo "enabled=true" > "$config"
        echo "Deep Sleep: ON"
    elif [ "$state" = "off" ]; then
        echo "enabled=false" > "$config"
        echo "Deep Sleep: OFF"
    else
        # Toggle
        local current=$(get_sleep_status)
        if [ "$current" = "ON" ]; then
            toggle_sleep "off"
        else
            toggle_sleep "on"
        fi
    fi
}

# ── Toggle FPS display ─────────────────────────────────────────────────
toggle_fps() {
    local state="$1"
    local config="/mnt/SDCARD/RetroArch/.retroarch/retroarch.cfg"
    
    if [ -f "$config" ]; then
        if [ "$state" = "on" ]; then
            sed -i 's/fps_show = "false"/fps_show = "true"/' "$config"
            echo "FPS Display: ON"
        elif [ "$state" = "off" ]; then
            sed -i 's/fps_show = "true"/fps_show = "false"/' "$config"
            echo "FPS Display: OFF"
        else
            # Toggle
            local current=$(get_fps_status)
            if [ "$current" = "ON" ]; then
                toggle_fps "off"
            else
                toggle_fps "on"
            fi
        fi
    else
        echo "RetroArch config not found"
    fi
}

# ── Show battery info ──────────────────────────────────────────────────
show_battery() {
    local battery_path="/sys/class/power_supply/battery"
    
    if [ -f "$battery_path/capacity" ]; then
        local level=$(cat "$battery_path/capacity" 2>/dev/null)
        local status=$(cat "$battery_path/status" 2>/dev/null)
        echo "Battery: $level% ($status)"
    else
        echo "Battery info not available"
    fi
}

# ── Show system info ───────────────────────────────────────────────────
show_info() {
    echo "=== System Info ==="
    echo ""
    
    # Device
    if [ -f /tmp/device_code ]; then
        echo "Device: $(cat /tmp/device_code)"
    else
        echo "Device: Unknown"
    fi
    
    # JukaMix version
    if [ -f /mnt/SDCARD/System/usr/trimui/jukamix-version.txt ]; then
        echo "JukaMix: $(cat /mnt/SDCARD/System/usr/trimui/jukamix-version.txt)"
    fi
    
    # CPU
    if [ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq ]; then
        local freq=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq 2>/dev/null)
        echo "CPU: $((freq / 1000)) MHz"
    fi
    
    # Temperature
    if [ -f /sys/class/thermal/thermal_zone0/temp ]; then
        local temp=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null)
        echo "Temp: $((temp / 1000))°C"
    fi
    
    # RAM
    if [ -f /proc/meminfo ]; then
        local total=$(grep "MemTotal" /proc/meminfo | awk '{print $2}')
        echo "RAM: $((total / 1024)) MB"
    fi
    
    # Storage
    local sd_used=$(df /mnt/SDCARD 2>/dev/null | tail -1 | awk '{print $3}')
    local sd_total=$(df /mnt/SDCARD 2>/dev/null | tail -1 | awk '{print $2}')
    if [ -n "$sd_used" ]; then
        echo "SD: $((sd_used / 1024)) / $((sd_total / 1024)) MB"
    fi
    
    echo ""
    show_battery
}

# ── Main ──────────────────────────────────────────────────────────────
case "${1:-}" in
    menu|show)
        show_menu
        ;;
    wifi)
        toggle_wifi "$2"
        ;;
    bt|bluetooth)
        toggle_bt "$2"
        ;;
    brightness)
        if [ -n "$2" ]; then
            set_brightness "$2"
        else
            echo "Brightness: $(get_brightness)%"
        fi
        ;;
    volume|vol)
        if [ -n "$2" ]; then
            set_volume "$2"
        else
            echo "Volume: $(get_volume)"
        fi
        ;;
    led)
        toggle_led "$2"
        ;;
    sleep)
        toggle_sleep "$2"
        ;;
    fps)
        toggle_fps "$2"
        ;;
    battery)
        show_battery
        ;;
    info)
        show_info
        ;;
    *)
        echo "Quick Settings"
        echo "=============="
        echo ""
        show_menu
        exit 1
        ;;
esac
