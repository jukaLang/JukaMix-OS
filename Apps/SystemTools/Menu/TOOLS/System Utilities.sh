#!/bin/sh
# System Utilities Menu - Controller-based menu for JukaMix system tools
# Uses D-Pad and A/B buttons - no keyboard required

SCRIPTS="/mnt/SDCARD/System/usr/trimui/scripts"
INPUT_DEVICE="/dev/input/event0"

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
max_selection=9

# Show menu via infoscreen
show_menu() {
    MENU_TEXT="JukaMix System Utilities\n"
    MENU_TEXT+="\n"
    MENU_TEXT+="UP/DOWN: Navigate\n"
    MENU_TEXT+="A: Select  B: Back\n"
    MENU_TEXT+="\n"
    MENU_TEXT+="[1] System Health Check\n"
    MENU_TEXT+="[2] Backup Settings\n"
    MENU_TEXT+="[3] Restore Settings\n"
    MENU_TEXT+="[4] Storage Cleanup\n"
    MENU_TEXT+="[5] Update Emulator Cores\n"
    MENU_TEXT+="[6] Performance Profiles\n"
    MENU_TEXT+="[7] Parental Controls\n"
    MENU_TEXT+="[8] System Information\n"
    MENU_TEXT+="[9] Exit"
    
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
            # System Health Check
            "$SCRIPTS/system_health.sh" check > /tmp/health_result.txt 2>/dev/null
            RESULT=$(cat /tmp/health_result.txt 2>/dev/null)
            "$SCRIPTS/infoscreen.sh" -i "/mnt/SDCARD/System/resources/info.png" -t "$RESULT" -d 5000
            ;;
        2)
            # Backup Settings
            "$SCRIPTS/backup_restore.sh" backup manual > /tmp/backup_result.txt 2>/dev/null
            RESULT=$(cat /tmp/backup_result.txt 2>/dev/null)
            "$SCRIPTS/infoscreen.sh" -i "/mnt/SDCARD/System/resources/success.png" -t "$RESULT" -d 3000
            ;;
        3)
            # Restore Settings - list backups first
            "$SCRIPTS/backup_restore.sh" list > /tmp/backup_list.txt 2>/dev/null
            RESULT=$(cat /tmp/backup_list.txt 2>/dev/null)
            "$SCRIPTS/infoscreen.sh" -i "/mnt/SDCARD/System/resources/info.png" -t "$RESULT" -d 5000
            ;;
        4)
            # Storage Cleanup
            "$SCRIPTS/storage_cleaner.sh" full > /tmp/cleanup_result.txt 2>/dev/null
            RESULT=$(cat /tmp/cleanup_result.txt 2>/dev/null)
            "$SCRIPTS/infoscreen.sh" -i "/mnt/SDCARD/System/resources/success.png" -t "$RESULT" -d 3000
            ;;
        5)
            # Update Emulator Cores
            "$SCRIPTS/core_updater.sh" list > /tmp/core_list.txt 2>/dev/null
            RESULT=$(cat /tmp/core_list.txt 2>/dev/null)
            "$SCRIPTS/infoscreen.sh" -i "/mnt/SDCARD/System/resources/info.png" -t "$RESULT" -d 5000
            ;;
        6)
            # Performance Profiles
            "$SCRIPTS/performance_profiles.sh" list > /tmp/perf_list.txt 2>/dev/null
            RESULT=$(cat /tmp/perf_list.txt 2>/dev/null)
            "$SCRIPTS/infoscreen.sh" -i "/mnt/SDCARD/System/resources/info.png" -t "$RESULT" -d 5000
            ;;
        7)
            # Parental Controls
            "$SCRIPTS/parental_controls.sh" settings > /tmp/parental_result.txt 2>/dev/null
            RESULT=$(cat /tmp/parental_result.txt 2>/dev/null)
            "$SCRIPTS/infoscreen.sh" -i "/mnt/SDCARD/System/resources/info.png" -t "$RESULT" -d 5000
            ;;
        8)
            # System Information
            DEVICE=$(cat /etc/trimui_device.txt 2>/dev/null || echo "Unknown")
            FIRMWARE=$(cat /sys/firmware/devicetree/base/product 2>/dev/null || echo "Unknown")
            KERNEL=$(uname -r 2>/dev/null || echo "Unknown")
            UPTIME=$(uptime 2>/dev/null || echo "Unknown")
            
            SYSINFO="System Information\n"
            SYSINFO+="\n"
            SYSINFO+="Device: $DEVICE\n"
            SYSINFO+="Firmware: $FIRMWARE\n"
            SYSINFO+="Kernel: $KERNEL\n"
            SYSINFO+="Uptime: $UPTIME\n"
            
            "$SCRIPTS/infoscreen.sh" -i "/mnt/SDCARD/System/resources/info.png" -t "$SYSINFO" -d 5000
            ;;
        9)
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
