#!/bin/sh
# multiplayer_manager.sh - Multiplayer/Netplay Manager for JukaMix
# Manages local and network multiplayer gaming

LOG_FILE="/tmp/multiplayer.log"
CONFIG_FILE="/mnt/SDCARD/System/etc/jukamix.json"
NETPLAY_DIR="/mnt/SDCARD/trimui/netplay"

# Create directories
mkdir -p "$NETPLAY_DIR" 2>/dev/null

# ── Logging ────────────────────────────────────────────────────────────
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [multi] $1" >> "$LOG_FILE" 2>/dev/null
}

# ── Get device IP ──────────────────────────────────────────────────────
get_ip() {
    ip addr show wlan0 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d'/' -f1
}

# ── Start netplay host ────────────────────────────────────────────────
start_netplay_host() {
    game_file="$1"
    port="${2:-55355}"
    
    if [ ! -f "$game_file" ]; then
        echo "Game file not found: $game_file"
        return 1
    fi
    
    ip=$(get_ip)
    if [ -z "$ip" ]; then
        echo "Wi-Fi not connected"
        return 1
    fi
    
    echo "Starting netplay host..."
    echo "Game: $(basename "$game_file")"
    echo "IP: $ip"
    echo "Port: $port"
    echo ""
    echo "Share this info with other players:"
    echo "  IP: $ip"
    echo "  Port: $port"
    
    # Start RetroArch with netplay
    if command -v retroarch >/dev/null 2>&1; then
        retroarch -L "$(get_core_for_game "$game_file")" "$game_file" \
            --netplay --netplay_mode 1 --netplay_port "$port" \
            --netplay_ip_mask "" --netplay_delay_frames 0 \
            > /dev/null 2>&1 &
        
        NETPLAY_PID=$!
        echo "$NETPLAY_PID" > "$NETPLAY_DIR/host.pid"
        
        log "Netplay host started (PID: $NETPLAY_PID)"
        echo "Netplay host started!"
        
        return 0
    else
        echo "RetroArch not found"
        return 1
    fi
}

# ── Start netplay client ───────────────────────────────────────────────
start_netplay_client() {
    game_file="$1"
    host_ip="$2"
    port="${3:-55355}"
    
    if [ ! -f "$game_file" ]; then
        echo "Game file not found: $game_file"
        return 1
    fi
    
    if [ -z "$host_ip" ]; then
        echo "Host IP required"
        return 1
    fi
    
    echo "Connecting to host..."
    echo "Host: $host_ip:$port"
    echo "Game: $(basename "$game_file")"
    
    # Start RetroArch as netplay client
    if command -v retroarch >/dev/null 2>&1; then
        retroarch -L "$(get_core_for_game "$game_file")" "$game_file" \
            --netplay --netplay_mode 0 --netplay_port "$port" \
            --netplay_ip_address "$host_ip" \
            > /dev/null 2>&1 &
        
        NETPLAY_PID=$!
        echo "$NETPLAY_PID" > "$NETPLAY_DIR/client.pid"
        
        log "Netplay client started (PID: $NETPLAY_PID)"
        echo "Netplay client started!"
        
        return 0
    else
        echo "RetroArch not found"
        return 1
    fi
}

# ── Stop netplay ───────────────────────────────────────────────────────
stop_netplay() {
    # Stop host
    if [ -f "$NETPLAY_DIR/host.pid" ]; then
        host_pid=$(cat "$NETPLAY_DIR/host.pid" 2>/dev/null)
        if [ -n "$host_pid" ]; then
            kill "$host_pid" 2>/dev/null
            rm -f "$NETPLAY_DIR/host.pid"
        fi
    fi
    
    # Stop client
    if [ -f "$NETPLAY_DIR/client.pid" ]; then
        client_pid=$(cat "$NETPLAY_DIR/client.pid" 2>/dev/null)
        if [ -n "$client_pid" ]; then
            kill "$client_pid" 2>/dev/null
            rm -f "$NETPLAY_DIR/client.pid"
        fi
    fi
    
    log "Netplay stopped"
    echo "Netplay stopped"
}

# ── Check netplay status ──────────────────────────────────────────────
check_netplay_status() {
    echo "Netplay Status:"
    echo "==============="
    echo ""
    
    ip=$(get_ip)
    echo "Your IP: ${ip:-Not connected}"
    echo ""
    
    # Check host
    if [ -f "$NETPLAY_DIR/host.pid" ]; then
        host_pid=$(cat "$NETPLAY_DIR/host.pid" 2>/dev/null)
        if [ -n "$host_pid" ] && kill -0 "$host_pid" 2>/dev/null; then
            echo "Host: Running (PID: $host_pid)"
        else
            echo "Host: Not running"
        fi
    else
        echo "Host: Not running"
    fi
    
    # Check client
    if [ -f "$NETPLAY_DIR/client.pid" ]; then
        client_pid=$(cat "$NETPLAY_DIR/client.pid" 2>/dev/null)
        if [ -n "$client_pid" ] && kill -0 "$client_pid" 2>/dev/null; then
            echo "Client: Running (PID: $client_pid)"
        else
            echo "Client: Not running"
        fi
    else
        echo "Client: Not running"
    fi
}

# ── Scan for hosts ─────────────────────────────────────────────────────
scan_for_hosts() {
    echo "Scanning for netplay hosts..."
    echo ""
    
    # Get local network
    ip=$(get_ip)
    if [ -z "$ip" ]; then
        echo "Wi-Fi not connected"
        return 1
    fi
    
    network=$(echo "$ip" | sed 's/\.[0-9]*$/.0/254')
    
    # Scan common ports
    for host_ip in $(seq 1 254); do
        test_ip=$(echo "$network" | sed "s/\.0$/.${host_ip}/")
        
        # Try to connect to netplay port
        if timeout 1 bash -c "echo > /dev/tcp/$test_ip/55355" 2>/dev/null; then
            echo "Found host: $test_ip:55355"
        fi
    done
    
    echo ""
    echo "Scan complete"
}

# ── Setup local multiplayer ────────────────────────────────────────────
setup_local_multiplayer() {
    game_file="$1"
    players="${2:-2}"
    
    echo "Setting up local multiplayer..."
    echo "Game: $(basename "$game_file")"
    echo "Players: $players"
    echo ""
    
    # Check for multiple controllers
    controllers=$(ls /dev/input/event* 2>/dev/null | wc -l)
    
    if [ "$controllers" -lt "$players" ]; then
        echo "Warning: Only $controllers controller(s) detected"
        echo "Need $players players"
        echo ""
    fi
    
    echo "Instructions:"
    echo "1. Connect controllers via USB/Bluetooth"
    echo "2. Press START on each controller to join"
    echo "3. Game will start when all players are ready"
    echo ""
    
    # Start game with multiplayer
    if command -v retroarch >/dev/null 2>&1; then
        retroarch -L "$(get_core_for_game "$game_file")" "$game_file" \
            > /dev/null 2>&1 &
        
        MULTI_PID=$!
        echo "$MULTI_PID" > "$NETPLAY_DIR/multi.pid"
        
        log "Local multiplayer started (PID: $MULTI_PID)"
        echo "Multiplayer started!"
        
        return 0
    else
        echo "RetroArch not found"
        return 1
    fi
}

# ── Get core for game ──────────────────────────────────────────────────
get_core_for_game() {
    game_file="$1"
    game_ext="${game_file##*.}"
    
    case "$game_ext" in
        nes|rom) echo "fceumm_libretro.so" ;;
        sfc|smc) echo "snes9x_libretro.so" ;;
        gb|gbc|gba) echo "mgba_libretro.so" ;;
        gen|md) echo "genesis_plus_gx_libretro.so" ;;
        psx|iso|bin|cue) echo "pcsx_rearmed_libretro.so" ;;
        n64|z64) echo "mupen64plus_next_libretro.so" ;;
        psp|iso) echo "ppsspp_libretro.so" ;;
        nds) echo "melonds_libretro.so" ;;
        *) echo "fbneo_libretro.so" ;;
    esac
}

# ── Show multiplayer options ───────────────────────────────────────────
show_options() {
    echo "Multiplayer Options:"
    echo "===================="
    echo ""
    echo "Local Multiplayer:"
    echo "  - Connect controllers via USB/Bluetooth"
    echo "  - Launch game from menu"
    echo "  - Each player presses START to join"
    echo ""
    echo "Network Multiplayer (Netplay):"
    echo "  - Host: Start netplay and share IP"
    echo "  - Client: Connect to host IP"
    echo "  - Both players need same game ROM"
    echo ""
    echo "Supported Systems for Netplay:"
    echo "  - NES (fceumm)"
    echo "  - SNES (snes9x)"
    echo "  - Game Boy/GBA (mgba)"
    echo "  - Genesis (genesis_plus_gx)"
    echo "  - Arcade (fbneo)"
}

# ── Main ───────────────────────────────────────────────────────────────
case "${1:-}" in
    host)
        start_netplay_host "${2:-}" "${3:-55355}"
        ;;
    join)
        start_netplay_client "${2:-}" "${3:-}" "${4:-55355}"
        ;;
    stop)
        stop_netplay
        ;;
    status)
        check_netplay_status
        ;;
    scan)
        scan_for_hosts
        ;;
    local)
        setup_local_multiplayer "${2:-}" "${3:-2}"
        ;;
    options)
        show_options
        ;;
    *)
        echo "Multiplayer/Netplay Manager"
        echo "Usage: multiplayer_manager.sh {host|join|stop|status|scan|local|options}"
        echo ""
        echo "Commands:"
        echo "  host <game> [port]     - Start netplay host"
        echo "  join <game> <ip> [port] - Join netplay game"
        echo "  stop                   - Stop netplay"
        echo "  status                 - Check netplay status"
        echo "  scan                   - Scan for hosts"
        echo "  local <game> [players] - Setup local multiplayer"
        echo "  options                - Show multiplayer options"
        ;;
esac
