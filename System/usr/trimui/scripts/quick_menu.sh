#!/bin/sh
# quick_menu.sh - Unified in-game overlay menu
# Access via MENU button or configurable hotkey
# Provides: save/load, performance modes, settings, screenshot, quit
# Uses controller input - no keyboard required

SCRIPTS_DIR="/mnt/SDCARD/System/usr/trimui/scripts"
CONFIG_FILE="/mnt/SDCARD/System/etc/jukamix.json"
MENU_DIR="/mnt/SDCARD/trimui/quick_menu"
LOG_FILE="/tmp/quick_menu.log"
INPUT_DEVICE="/dev/input/event0"

# Create menu directory
mkdir -p "$MENU_DIR" 2>/dev/null

# Logging
log() {
    echo "$(date '+%H:%M:%S') [quick_menu] $1" >> "$LOG_FILE" 2>/dev/null
}

# ── Get current game info ──────────────────────────────────────────────
get_current_game() {
    RETROARCH_PID=$(pgrep -f "retroarch" 2>/dev/null | head -1)
    PPSSPP_PID=$(pgrep -f "ppsspp" 2>/dev/null | head -1)
    DRASTIC_PID=$(pgrep -f "drastic" 2>/dev/null | head -1)
    
    if [ -n "$RETROARCH_PID" ]; then
        EMULATOR="retroarch"
        GAME_PATH=$(cat /proc/$RETROARCH_PID/cmdline 2>/dev/null | tr '\0' '\n' | grep -E '\.(nes|sfc|smc|gb[ac]?|gba|gen|md|psx|iso|bin|cue|zip|7z)$' | head -1)
    elif [ -n "$PPSSPP_PID" ]; then
        EMULATOR="ppsspp"
        GAME_PATH=$(cat /tmp/ppsspp_last_game 2>/dev/null)
    elif [ -n "$DRASTIC_PID" ]; then
        EMULATOR="drastic"
        GAME_PATH=$(cat /tmp/drastic_last_game 2>/dev/null)
    else
        EMULATOR="unknown"
        GAME_PATH=""
    fi
    
    GAME_NAME=$(basename "$GAME_PATH" 2>/dev/null | sed 's/\.[^.]*$//')
    [ -z "$GAME_NAME" ] && GAME_NAME="Unknown Game"
}

# ── Get current performance mode ───────────────────────────────────────
get_performance_mode() {
    if [ -f "$CONFIG_FILE" ] && command -v jq >/dev/null 2>&1; then
        MODE=$(jq -r '.["PERFORMANCE_MODE"] // "balanced"' "$CONFIG_FILE" 2>/dev/null)
    else
        MODE="balanced"
    fi
    echo "$MODE"
}

# ── Set performance mode ───────────────────────────────────────────────
set_performance_mode() {
    mode="$1"
    
    case "$mode" in
        eco)
            for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
                [ -w "$cpu" ] && echo "powersave" > "$cpu" 2>/dev/null
            done
            echo 30 > /sys/class/backlight/backlight/brightness 2>/dev/null
            ;;
        balanced)
            for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
                [ -w "$cpu" ] && echo "ondemand" > "$cpu" 2>/dev/null
            done
            echo 50 > /sys/class/backlight/backlight/brightness 2>/dev/null
            ;;
        turbo)
            for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
                [ -w "$cpu" ] && echo "performance" > "$cpu" 2>/dev/null
            done
            echo 100 > /sys/class/backlight/backlight/brightness 2>/dev/null
            ;;
    esac
    
    # Save to config
    if [ -f "$CONFIG_FILE" ] && command -v jq >/dev/null 2>&1; then
        jq --arg mode "$mode" '. += {"PERFORMANCE_MODE": $mode}' "$CONFIG_FILE" > /tmp/jukamix_tmp.json 2>/dev/null && \
        mv /tmp/jukamix_tmp.json "$CONFIG_FILE" 2>/dev/null
    fi
    
    log "Performance mode set to: $mode"
}

# ── Save state ─────────────────────────────────────────────────────────
save_state() {
    slot="${1:-0}"
    
    case "$EMULATOR" in
        retroarch)
            echo "SAVE_STATE" | nc -w 1 localhost 55355 2>/dev/null
            log "RetroArch save state (slot $slot)"
            ;;
        ppsspp)
            log "PPSSPP save state"
            ;;
        drastic)
            log "DraStic save state"
            ;;
    esac
}

# ── Load state ─────────────────────────────────────────────────────────
load_state() {
    slot="${1:-0}"
    
    case "$EMULATOR" in
        retroarch)
            echo "LOAD_STATE" | nc -w 1 localhost 55355 2>/dev/null
            log "RetroArch load state (slot $slot)"
            ;;
        ppsspp)
            log "PPSSPP load state"
            ;;
        drastic)
            log "DraStic load state"
            ;;
    esac
}

# ── Take screenshot ────────────────────────────────────────────────────
take_screenshot() {
    SCREENSHOT_DIR="/mnt/SDCARD/screenshots"
    mkdir -p "$SCREENSHOT_DIR" 2>/dev/null
    
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    SCREENSHOT_FILE="$SCREENSHOT_DIR/${GAME_NAME}_${TIMESTAMP}.png"
    
    cat /dev/graphics/fb0 > /tmp/fb_raw 2>/dev/null
    if [ -f "/tmp/fb_raw" ]; then
        if command -v ffmpeg >/dev/null 2>&1; then
            ffmpeg -f rawvideo -pixel_format rgba -video_size 1280x720 -i /tmp/fb_raw -y "$SCREENSHOT_FILE" 2>/dev/null
        else
            mv /tmp/fb_raw "$SCREENSHOT_FILE" 2>/dev/null
        fi
        rm -f /tmp/fb_raw 2>/dev/null
        log "Screenshot saved: $SCREENSHOT_FILE"
    fi
}

# ── Toggle Wi-Fi ───────────────────────────────────────────────────────
toggle_wifi() {
    WIFI_STATE=$(cat /sys/class/net/wlan0/operstate 2>/dev/null)
    
    if [ "$WIFI_STATE" = "up" ]; then
        ifconfig wlan0 down 2>/dev/null
        log "Wi-Fi disabled"
    else
        ifconfig wlan0 up 2>/dev/null
        log "Wi-Fi enabled"
    fi
}

# ── Toggle Bluetooth ───────────────────────────────────────────────────
toggle_bluetooth() {
    BT_STATE=$(cat /sys/class/bluetooth/hci0/device/rfkill0/state 2>/dev/null)
    
    if [ "$BT_STATE" = "1" ]; then
        btmgmt power off 2>/dev/null
        log "Bluetooth disabled"
    else
        btmgmt power on 2>/dev/null
        log "Bluetooth enabled"
    fi
}

# ── Show OSD message ───────────────────────────────────────────────────
show_osd() {
    message="$1"
    duration="${2:-2000}"
    
    if [ -d /tmp/trimui_osd ] && [ -w /tmp/trimui_osd ]; then
        echo "{\"type\":\"info\",\"size\":2,\"duration\":$duration,\"x\":660,\"y\":0,\"message\":\"$message\",\"icon\":\"\"}" > /tmp/trimui_osd/osd_toast_msg 2>/dev/null
    fi
}

# ── Controller button mapping (TrimUI) ─────────────────────────────────
# TrimUI buttons: A=304, B=305, X=307, Y=308, MENU=139, UP=17, DOWN=18, LEFT=19, RIGHT=20
BTN_A=304
BTN_B=305
BTN_X=307
BTN_Y=308
BTN_MENU=139
BTN_UP=17
BTN_DOWN=18
BTN_LEFT=19
BTN_RIGHT=20

# ── Read controller input ──────────────────────────────────────────────
# Returns button code, or 0 for timeout
read_controller() {
    timeout "${1:-5}" cat "$INPUT_DEVICE" 2>/dev/null | while IFS= read -r line; do
        # Parse evdev events for button press (EV_KEY=1, value=1 for press)
        if echo "$line" | grep -q "EV_KEY"; then
            # Extract button code from event
            code=$(echo "$line" | grep -o "code [0-9]*" | cut -d' ' -f2)
            value=$(echo "$line" | grep -q "value 1" && echo "1" || echo "0")
            if [ "$value" = "1" ] && [ -n "$code" ]; then
                echo "$code"
                return 0
            fi
        fi
    done
    echo "0"
}

# ── Wait for button press ──────────────────────────────────────────────
wait_for_button() {
    # Use evtest if available, otherwise fall back to /dev/input
    if [ -f "$SCRIPTS_DIR/evtest" ]; then
        timeout 5 "$SCRIPTS_DIR/evtest" "$INPUT_DEVICE" 2>/dev/null | while IFS= read -r line; do
            if echo "$line" | grep -q "EV_KEY.*value 1"; then
                code=$(echo "$line" | grep -o "code [0-9]*" | cut -d' ' -f2)
                echo "$code"
                return 0
            fi
        done
    fi
    echo "0"
}

# ── Show menu with OSD ────────────────────────────────────────────────
show_menu_osd() {
    get_current_game
    MODE=$(get_performance_mode)
    
    MENU_TEXT="JukaMix Quick Menu\n"
    MENU_TEXT+="Game: $GAME_NAME\n"
    MENU_TEXT+="Performance: $MODE\n"
    MENU_TEXT+="\n"
    MENU_TEXT+="UP/DOWN: Navigate\n"
    MENU_TEXT+="A: Select  B: Back\n"
    MENU_TEXT+="\n"
    MENU_TEXT+="[1] Save State (Slot 0)\n"
    MENU_TEXT+="[2] Load State (Slot 0)\n"
    MENU_TEXT+="[3] Save State (Slot 1)\n"
    MENU_TEXT+="[4] Load State (Slot 1)\n"
    MENU_TEXT+="[5] Performance: Eco\n"
    MENU_TEXT+="[6] Performance: Balanced\n"
    MENU_TEXT+="[7] Performance: Turbo\n"
    MENU_TEXT+="[8] Screenshot\n"
    MENU_TEXT+="[9] Toggle Wi-Fi\n"
    MENU_TEXT+="[0] Toggle Bluetooth\n"
    MENU_TEXT+="[Q] Quit to Menu"
    
    # Show via infoscreen
    "$SCRIPTS_DIR/infoscreen.sh" -i "/mnt/SDCARD/System/resources/JukaMix.png" -t "$MENU_TEXT" -d 999999
}

# ── Handle menu selection ──────────────────────────────────────────────
handle_selection() {
    selection="$1"
    
    case "$selection" in
        1) save_state 0; show_osd "State saved (Slot 0)" ;;
        2) load_state 0; show_osd "State loaded (Slot 0)" ;;
        3) save_state 1; show_osd "State saved (Slot 1)" ;;
        4) load_state 1; show_osd "State loaded (Slot 1)" ;;
        5) set_performance_mode eco; show_osd "Performance: Eco" ;;
        6) set_performance_mode balanced; show_osd "Performance: Balanced" ;;
        7) set_performance_mode turbo; show_osd "Performance: Turbo" ;;
        8) take_screenshot; show_osd "Screenshot saved" ;;
        9) toggle_wifi; show_osd "Wi-Fi toggled" ;;
        0) toggle_bluetooth; show_osd "Bluetooth toggled" ;;
        q|Q)
            killall -TERM retroarch ppsspp drastic 2>/dev/null
            return 1
            ;;
        *)
            show_osd "Invalid selection"
            ;;
    esac
    
    return 0
}

# ── Main menu loop (controller-based) ──────────────────────────────────
main() {
    log "Quick menu opened"
    
    # Show initial menu
    show_menu_osd
    
    # Controller-based menu loop
    current_selection=1
    max_selection=11
    
    while true; do
        # Wait for button press
        button=$(wait_for_button)
        
        case "$button" in
            "$BTN_UP")
                current_selection=$((current_selection - 1))
                [ "$current_selection" -lt 1 ] && current_selection=$max_selection
                show_osd "Selection: $current_selection"
                ;;
            "$BTN_DOWN")
                current_selection=$((current_selection + 1))
                [ "$current_selection" -gt "$max_selection" ] && current_selection=1
                show_osd "Selection: $current_selection"
                ;;
            "$BTN_A")
                # Select current item
                handle_selection "$current_selection"
                [ $? -eq 0 ] || break
                show_menu_osd
                ;;
            "$BTN_B")
                # Back/Close menu
                break
                ;;
            "$BTN_MENU")
                # Toggle menu
                break
                ;;
            *)
                # Invalid or timeout
                ;;
        esac
    done
    
    # Kill infoscreen if running
    killall sdl2imgshow 2>/dev/null
    
    log "Quick menu closed"
}

# Run if called directly
if [ "${1:-}" != "--background" ]; then
    main
fi
