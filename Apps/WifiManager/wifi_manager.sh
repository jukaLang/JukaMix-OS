#!/bin/sh
# Apps/WifiManager/wifi_manager.sh
# WiFi Manager - Easy WiFi setup and management

SCRIPTS_DIR="/mnt/SDCARD/System/usr/trimui/scripts"
WIFI_DIR="/mnt/SDCARD/trimui/wifi"
LOG_FILE="/tmp/wifi_manager.log"

# Create wifi directory
mkdir -p "$WIFI_DIR"

# Logging
log() {
    echo "$(date '+%H:%M:%S') [wifi] $1" >> "$LOG_FILE"
}

# ── Check if WiFi is available ─────────────────────────────────────────
check_wifi() {
    if command -v iwconfig >/dev/null 2>&1; then
        return 0
    elif [ -d /sys/class/net/wlan0 ]; then
        return 0
    fi
    return 1
}

# ── Get WiFi status ────────────────────────────────────────────────────
get_status() {
    local iface="wlan0"
    
    if [ ! -d "/sys/class/net/$iface" ]; then
        echo "Not available"
        return
    fi
    
    local status=$(cat "/sys/class/net/$iface/operstate" 2>/dev/null)
    
    if [ "$status" = "up" ]; then
        local ip=$(ip addr show "$iface" 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d/ -f1)
        local ssid=$(iwgetid -r 2>/dev/null)
        
        if [ -n "$ssid" ]; then
            echo "Connected: $ssid ($ip)"
        else
            echo "Connected: $ip"
        fi
    else
        echo "Disconnected"
    fi
}

# ── Scan networks ──────────────────────────────────────────────────────
scan_networks() {
    local iface="wlan0"
    
    if [ ! -d "/sys/class/net/$iface" ]; then
        echo "WiFi not available"
        return
    fi
    
    # Bring up interface
    ifconfig "$iface" up 2>/dev/null
    
    # Scan
    if command -v iwlist >/dev/null 2>&1; then
        iwlist "$iface" scan 2>/dev/null | grep "ESSID" | sed 's/.*ESSID:"\(.*\)"/\1/' | sort -u
    elif command -v iw >/dev/null 2>&1; then
        iw dev "$iface" scan 2>/dev/null | grep "SSID:" | awk '{print $2}' | sort -u
    else
        echo "Scan not available"
    fi
}

# ── Connect to network ─────────────────────────────────────────────────
connect_network() {
    local ssid="$1"
    local password="$2"
    local iface="wlan0"
    
    if [ -z "$ssid" ]; then
        echo "Usage: wifi_manager.sh connect <ssid> [password]"
        return 1
    fi
    
    log "Connecting to: $ssid"
    
    # Try wpa_supplicant
    if command -v wpa_supplicant >/dev/null 2>&1; then
        # Create wpa config
        local wpa_conf="/tmp/wpa_supplicant.conf"
        
        if [ -n "$password" ]; then
            cat > "$wpa_conf" << EOF
ctrl_interface=/var/run/wpa_supplicant
ap_scan=1

network={
    ssid="$ssid"
    psk="$password"
    key_mgmt=WPA-PSK
}
EOF
        else
            cat > "$wpa_conf" << EOF
ctrl_interface=/var/run/wpa_supplicant
ap_scan=1

network={
    ssid="$ssid"
    key_mgmt=NONE
}
EOF
        fi
        
        # Kill existing wpa_supplicant
        killall wpa_supplicant 2>/dev/null
        
        # Start wpa_supplicant
        wpa_supplicant -B -i "$iface" -c "$wpa_conf" 2>/dev/null
        
        # Wait for connection
        sleep 3
        
        # Get IP via DHCP
        if command -v udhcpc >/dev/null 2>&1; then
            udhcpc -i "$iface" -b -q 2>/dev/null
        elif command -v dhclient >/dev/null 2>&1; then
            dhclient "$iface" 2>/dev/null
        fi
        
        # Check if connected
        local ip=$(ip addr show "$iface" 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d/ -f1)
        
        if [ -n "$ip" ]; then
            log "Connected to $ssid ($ip)"
            echo "Connected to $ssid"
            echo "IP: $ip"
            
            # Save network
            save_network "$ssid" "$password"
        else
            log "Failed to connect to $ssid"
            echo "Failed to connect"
        fi
    else
        echo "wpa_supplicant not found"
    fi
}

# ── Disconnect ─────────────────────────────────────────────────────────
disconnect() {
    local iface="wlan0"
    
    killall wpa_supplicant 2>/dev/null
    ifconfig "$iface" down 2>/dev/null
    
    log "Disconnected"
    echo "Disconnected"
}

# ── Save network ───────────────────────────────────────────────────────
save_network() {
    local ssid="$1"
    local password="$2"
    local networks_file="$WIFI_DIR/networks.conf"
    
    # Check if already saved
    if grep -q "^$ssid|" "$networks_file" 2>/dev/null; then
        return
    fi
    
    # Add network
    echo "$ssid|$password" >> "$networks_file"
    log "Saved network: $ssid"
}

# ── List saved networks ────────────────────────────────────────────────
list_saved() {
    local networks_file="$WIFI_DIR/networks.conf"
    
    if [ ! -f "$networks_file" ]; then
        echo "No saved networks"
        return
    fi
    
    echo "Saved networks:"
    echo "---------------"
    cut -d'|' -f1 "$networks_file"
}

# ── Main ──────────────────────────────────────────────────────────────
case "${1:-}" in
    status)
        get_status
        ;;
    scan)
        scan_networks
        ;;
    connect)
        connect_network "$2" "$3"
        ;;
    disconnect)
        disconnect
        ;;
    saved)
        list_saved
        ;;
    *)
        echo "WiFi Manager"
        echo "============"
        echo ""
        echo "Status: $(get_status)"
        echo ""
        echo "Usage: wifi_manager.sh {status|scan|connect|disconnect|saved} [args]" >&2
        echo "" >&2
        echo "Commands:" >&2
        echo "  status              - Show WiFi status" >&2
        echo "  scan                - Scan for networks" >&2
        echo "  connect <ssid> [pw] - Connect to network" >&2
        echo "  disconnect          - Disconnect" >&2
        echo "  saved               - List saved networks" >&2
        exit 1
        ;;
esac
