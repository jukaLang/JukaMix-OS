#!/bin/sh
# Shader Selector - Controller-based menu for JukaMix Shader Manager
# Uses D-Pad and A/B buttons - no keyboard required

SCRIPTS="/mnt/SDCARD/System/usr/trimui/scripts"
SHADER_MGR="$SCRIPTS/shader_manager.sh"
INPUT_DEVICE="/dev/input/event0"

# Check if shader manager exists
if [ ! -f "$SHADER_MGR" ]; then
    "$SCRIPTS/infoscreen.sh" -i "/mnt/SDCARD/System/resources/error.png" -t "Shader Manager not found" -d 2000
    exit 1
fi

# Button codes (TrimUI)
BTN_A=304
BTN_B=305
BTN_UP=17
BTN_DOWN=18
BTN_LEFT=19
BTN_RIGHT=20
BTN_MENU=139

# Current selection
current_selection=1
max_selection=8

# Show menu via infoscreen
show_menu() {
    MENU_TEXT="JukaMix Shader Selector\n"
    MENU_TEXT+="\n"
    MENU_TEXT+="UP/DOWN: Navigate\n"
    MENU_TEXT+="A: Select  B: Back\n"
    MENU_TEXT+="\n"
    MENU_TEXT+="[1] List available shaders\n"
    MENU_TEXT+="[2] Apply shader to all systems\n"
    MENU_TEXT+="[3] Apply shader to specific system\n"
    MENU_TEXT+="[4] Create per-system presets\n"
    MENU_TEXT+="[5] Apply device optimizations\n"
    MENU_TEXT+="[6] Check current shader\n"
    MENU_TEXT+="[7] Reset to default\n"
    MENU_TEXT+="[8] Exit"
    
    "$SCRIPTS/infoscreen.sh" -i "/mnt/SDCARD/System/resources/JukaMix.png" -t "$MENU_TEXT" -d 999999
}

# Wait for button press
wait_for_button() {
    if [ -f "$SCRIPTS/evtest" ]; then
        timeout 5 "$SCRIPTS/evtest" "$INPUT_DEVICE" 2>/dev/null | while IFS= read -r line; do
            if echo "$line" | grep -q "EV_KEY.*value 1"; then
                code=$(echo "$line" | grep -o "code [0-9]*" | cut -d' ' -f2)
                echo "$code"
                return 0
            fi
        done
    fi
    echo "0"
}

# Handle selection
handle_selection() {
    selection="$1"
    
    case "$selection" in
        1)
            # List shaders
            "$SHADER_MGR" list > /tmp/shader_list.txt 2>/dev/null
            LIST=$(cat /tmp/shader_list.txt 2>/dev/null)
            "$SCRIPTS/infoscreen.sh" -i "/mnt/SDCARD/System/resources/info.png" -t "$LIST" -d 5000
            ;;
        2)
            # Apply to all - use default crt_ntsc
            "$SHADER_MGR" apply crt_ntsc
            "$SCRIPTS/infoscreen.sh" -i "/mnt/SDCARD/System/resources/success.png" -t "Applied: CRT NTSC to all systems" -d 2000
            ;;
        3)
            # Apply to specific system - cycle through systems
            SYSTEMS="NES SNES GB GBA GEN PSX N64 PSP NDS ARCADE"
            SYS_INDEX=1
            for sys in $SYSTEMS; do
                [ "$SYS_INDEX" -eq "$current_selection" ] && break
                SYS_INDEX=$((SYS_INDEX + 1))
            done
            "$SHADER_MGR" apply crt_ntsc "$sys"
            "$SCRIPTS/infoscreen.sh" -i "/mnt/SDCARD/System/resources/success.png" -t "Applied: CRT NTSC to $sys" -d 2000
            ;;
        4)
            # Create presets
            "$SHADER_MGR" create-presets
            "$SCRIPTS/infoscreen.sh" -i "/mnt/SDCARD/System/resources/success.png" -t "Per-system presets created" -d 2000
            ;;
        5)
            # Device optimize
            "$SHADER_MGR" device-optimize
            "$SCRIPTS/infoscreen.sh" -i "/mnt/SDCARD/System/resources/success.png" -t "Device optimizations applied" -d 2000
            ;;
        6)
            # Check current
            CURRENT=$("$SHADER_MGR" status all 2>/dev/null)
            "$SCRIPTS/infoscreen.sh" -i "/mnt/SDCARD/System/resources/info.png" -t "$CURRENT" -d 3000
            ;;
        7)
            # Reset
            "$SHADER_MGR" reset all
            "$SCRIPTS/infoscreen.sh" -i "/mnt/SDCARD/System/resources/success.png" -t "Shaders reset to default" -d 2000
            ;;
        8)
            # Exit
            return 1
            ;;
    esac
    
    return 0
}

# Main controller loop
main() {
    show_menu
    
    while true; do
        button=$(wait_for_button)
        
        case "$button" in
            "$BTN_UP")
                current_selection=$((current_selection - 1))
                [ "$current_selection" -lt 1 ] && current_selection=$max_selection
                show_menu
                ;;
            "$BTN_DOWN")
                current_selection=$((current_selection + 1))
                [ "$current_selection" -gt "$max_selection" ] && current_selection=1
                show_menu
                ;;
            "$BTN_A")
                handle_selection "$current_selection"
                [ $? -eq 0 ] || break
                show_menu
                ;;
            "$BTN_B")
                break
                ;;
            "$BTN_MENU")
                break
                ;;
        esac
    done
    
    killall sdl2imgshow 2>/dev/null
}

main
