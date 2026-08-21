#!/bin/sh
# Apps/SystemInfo/system_info.sh
# System Info - Display device information

show_header() {
    echo "╔══════════════════════════════════════╗"
    echo "║        JukaMix OS System Info        ║"
    echo "╚══════════════════════════════════════╝"
    echo ""
}

show_device() {
    echo "── Device ──────────────────────────────"
    
    # Device code
    if [ -f /tmp/device_code ]; then
        echo "Model: $(cat /tmp/device_code)"
    else
        echo "Model: Unknown"
    fi
    
    # Device profile
    if [ -f /tmp/device_profile ]; then
        echo "Profile: $(cat /tmp/device_profile)"
    fi
    
    # Machine info
    echo "Machine: $(uname -m)"
    echo "Kernel: $(uname -r)"
    echo ""
}

show_software() {
    echo "── Software ────────────────────────────"
    
    # JukaMix version
    if [ -f /mnt/SDCARD/System/usr/trimui/jukamix-version.txt ]; then
        echo "JukaMix: $(cat /mnt/SDCARD/System/usr/trimui/jukamix-version.txt)"
    fi
    
    # Firmware version
    if [ -f /mnt/SDCARD/trimui/firmwares/MinFwVersion.txt ]; then
        echo "Min Firmware: $(cat /mnt/SDCARD/trimui/firmwares/MinFwVersion.txt)"
    fi
    
    # RetroArch version
    if [ -f /mnt/SDCARD/RetroArch/retroarch.cfg ]; then
        echo "RetroArch: Present"
    fi
    
    # Cores count
    local cores=$(ls /mnt/SDCARD/RetroArch/.retroarch/cores/*.so 2>/dev/null | wc -l)
    echo "RetroArch Cores: $cores"
    
    # Emulators count
    local emus=$(ls -d /mnt/SDCARD/Emus/*/ 2>/dev/null | wc -l)
    echo "Emulators: $emus"
    
    # Apps count
    local apps=$(ls -d /mnt/SDCARD/Apps/*/ 2>/dev/null | wc -l)
    echo "Apps: $apps"
    echo ""
}

show_hardware() {
    echo "── Hardware ────────────────────────────"
    
    # CPU
    if [ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq ]; then
        local freq=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq 2>/dev/null)
        local max=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq 2>/dev/null)
        echo "CPU: $((freq / 1000)) MHz (max: $((max / 1000)) MHz)"
    fi
    
    # CPU cores
    local cores=$(ls -d /sys/devices/system/cpu/cpu[0-9]* 2>/dev/null | wc -l)
    echo "CPU Cores: $cores"
    
    # Temperature
    if [ -f /sys/class/thermal/thermal_zone0/temp ]; then
        local temp=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null)
        echo "Temperature: $((temp / 1000))°C"
    fi
    
    # RAM
    if [ -f /proc/meminfo ]; then
        local total=$(grep "MemTotal" /proc/meminfo | awk '{print $2}')
        local free=$(grep "MemFree" /proc/meminfo | awk '{print $2}')
        local used=$((total - free))
        echo "RAM: $((used / 1024)) / $((total / 1024)) MB"
    fi
    
    # GPU (if available)
    if [ -f /sys/class/misc/mali0/device/clock ]; then
        local gpu=$(cat /sys/class/misc/mali0/device/clock 2>/dev/null)
        echo "GPU: $gpu Hz"
    fi
    echo ""
}

show_storage() {
    echo "── Storage ─────────────────────────────"
    
    # SD Card
    if [ -d /mnt/SDCARD ]; then
        local sd_info=$(df -h /mnt/SDCARD 2>/dev/null | tail -1)
        local sd_used=$(echo "$sd_info" | awk '{print $3}')
        local sd_total=$(echo "$sd_info" | awk '{print $2}')
        local sd_percent=$(echo "$sd_info" | awk '{print $5}')
        echo "SD Card: $sd_used / $sd_total ($sd_percent)"
        
        # ROMs size
        if [ -d /mnt/SDCARD/Roms ]; then
            local roms_size=$(du -sh /mnt/SDCARD/Roms 2>/dev/null | awk '{print $1}')
            echo "ROMs: $roms_size"
        fi
        
        # BIOS size
        if [ -d /mnt/SDCARD/BIOS ]; then
            local bios_size=$(du -sh /mnt/SDCARD/BIOS 2>/dev/null | awk '{print $1}')
            echo "BIOS: $bios_size"
        fi
        
        # Saves size
        if [ -d /mnt/SDCARD/Saves ]; then
            local saves_size=$(du -sh /mnt/SDCARD/Saves 2>/dev/null | awk '{print $1}')
            echo "Saves: $saves_size"
        fi
    fi
    echo ""
}

show_battery() {
    echo "── Battery ─────────────────────────────"
    
    local battery_path="/sys/class/power_supply/battery"
    
    if [ -f "$battery_path/capacity" ]; then
        local level=$(cat "$battery_path/capacity" 2>/dev/null)
        local status=$(cat "$battery_path/status" 2>/dev/null)
        echo "Level: $level%"
        echo "Status: $status"
        
        # Temperature
        if [ -f "$battery_path/temp" ]; then
            local temp=$(cat "$battery_path/temp" 2>/dev/null)
            echo "Temperature: $((temp / 10))°C"
        fi
        
        # Voltage
        if [ -f "$battery_path/voltage_now" ]; then
            local voltage=$(cat "$battery_path/voltage_now" 2>/dev/null)
            echo "Voltage: $((voltage / 1000)) mV"
        fi
    else
        echo "Battery info not available"
    fi
    echo ""
}

show_network() {
    echo "── Network ─────────────────────────────"
    
    # WiFi
    if [ -d /sys/class/net/wlan0 ]; then
        local status=$(cat /sys/class/net/wlan0/operstate 2>/dev/null)
        if [ "$status" = "up" ]; then
            local ip=$(ip addr show wlan0 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d/ -f1)
            local ssid=$(iwgetid -r 2>/dev/null)
            echo "WiFi: Connected"
            echo "SSID: $ssid"
            echo "IP: $ip"
        else
            echo "WiFi: Disconnected"
        fi
    else
        echo "WiFi: Not available"
    fi
    
    # Bluetooth
    if command -v bluetoothctl >/dev/null 2>&1; then
        local powered=$(bluetoothctl show 2>/dev/null | grep "Powered" | awk '{print $2}')
        if [ "$powered" = "yes" ]; then
            echo "Bluetooth: ON"
        else
            echo "Bluetooth: OFF"
        fi
    fi
    echo ""
}

show_emulators() {
    echo "── Top Emulators ───────────────────────"
    
    ls -d /mnt/SDCARD/Emus/*/ 2>/dev/null | head -10 | while read -r dir; do
        local name=$(basename "$dir")
        local launchers=$(ls "$dir"/*.sh 2>/dev/null | wc -l)
        echo "$name ($launchers launchers)"
    done
    
    local total=$(ls -d /mnt/SDCARD/Emus/*/ 2>/dev/null | wc -l)
    if [ "$total" -gt 10 ]; then
        echo "... and $((total - 10)) more"
    fi
    echo ""
}

show_games() {
    echo "── Games ───────────────────────────────"
    
    local total=0
    
    for rom_dir in /mnt/SDCARD/Roms/*/; do
        [ -d "$rom_dir" ] || continue
        
        local system=$(basename "$rom_dir")
        local count=$(find "$rom_dir" -maxdepth 1 -type f 2>/dev/null | wc -l)
        
        if [ "$count" -gt 0 ]; then
            echo "$system: $count"
            total=$((total + count))
        fi
    done
    
    echo ""
    echo "Total Games: $total"
    echo ""
}

# ── Main ──────────────────────────────────────────────────────────────
show_header
show_device
show_software
show_hardware
show_storage
show_battery
show_network
show_emulators
show_games

echo "════════════════════════════════════════"
echo "Press any key to exit..."
read -r -n 1 -s
