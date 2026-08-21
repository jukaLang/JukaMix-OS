#!/bin/sh
# osd_launcher.sh - Launch OSD with device-specific configuration
#
# Usage:
#   . /mnt/SDCARD/System/usr/trimui/osd/osd_launcher.sh
#   launch_osd [message]

OSD_DIR="/mnt/SDCARD/System/usr/trimui/osd"

# Get device code
DEVICE_CODE="unknown"
if [ -r /etc/trimui_device.txt ]; then
    DEVICE_CODE=$(tr -d '[:space:]' < /etc/trimui_device.txt 2>/dev/null | head -n 1)
fi

launch_osd() {
    local message="$1"
    
    # Select OSD configuration based on device
    local osd_config=""
    local osd_bg=""
    
    case "$DEVICE_CODE" in
        tg5050)
            # TG5050: Higher resolution, different layout
            osd_config="$OSD_DIR/osdlayout.json"
            osd_bg="$OSD_DIR/bg.png"
            ;;
        tsp)
            # TSP: Standard layout
            osd_config="$OSD_DIR/osdlayout.json"
            osd_bg="$OSD_DIR/bg.png"
            ;;
        brick)
            # Brick: Vertical screen, different layout
            osd_config="$OSD_DIR/osdlayout.json"
            osd_bg="$OSD_DIR/bg.png"
            ;;
        brick_pro|brickpro)
            # Brick Pro: Same as TSP (same SoC)
            osd_config="$OSD_DIR/osdlayout.json"
            osd_bg="$OSD_DIR/bg.png"
            ;;
        *)
            # Default
            osd_config="$OSD_DIR/osdlayout.json"
            osd_bg="$OSD_DIR/bg.png"
            ;;
    esac
    
    # Ensure OSD directory exists
    mkdir -p /tmp/trimui_osd
    
    # Copy OSD assets if needed
    if [ ! -f /tmp/trimui_osd/osdlayout.json ]; then
        cp "$osd_config" /tmp/trimui_osd/ 2>/dev/null || true
    fi
    
    # Launch OSD daemon if not running
    if ! pgrep -f trimui_osdd >/dev/null 2>&1; then
        cd "$OSD_DIR"
        ./trimui_osdd &
        sleep 0.5
    fi
    
    # Send message if provided
    if [ -n "$message" ]; then
        show_info_msg "$message"
    fi
}

show_info_msg() {
    local msg="$1"
    local msg_json="{\"type\":\"default\",\"id\":\"com.trimui.osd.msg.default\",\"duration\":1000,\"size\":1,\"x\":340,\"y\":500,\"w\":300,\"h\":80,\"message\":\"$msg\",\"font\":\"\",\"bg\":\"\",\"icon\":\"\",\"fontsize\":24,\"fontcolor\":\"FFFFFFFF\"}"
    echo -e "$msg_json" > /tmp/trimui_osd/osd_toast_ms2
}

show_volume_msg() {
    local vol="$1"
    local vol_json="{\"type\":\"default\",\"id\":\"com.trimui.osd.msg.volume\",\"duration\":1000,\"size\":1,\"x\":340,\"y\":500,\"w\":300,\"h\":80,\"message\":\"Volume: $vol\",\"font\":\"\",\"bg\":\"\",\"icon\":\"\",\"fontsize\":24,\"fontcolor\":\"FFFFFFFF\"}"
    echo -e "$vol_json" > /tmp/trimui_osd/osd_toast_ms2
}

show_battery_msg() {
    local level="$1"
    local charging="$2"
    local battery_json="{\"type\":\"default\",\"id\":\"com.trimui.osd.msg.battery\",\"duration\":1000,\"size\":1,\"x\":340,\"y\":500,\"w\":300,\"h\":80,\"message\":\"Battery: $level%\",\"font\":\"\",\"bg\":\"\",\"icon\":\"\",\"fontsize\":24,\"fontcolor\":\"FFFFFFFF\"}"
    echo -e "$battery_json" > /tmp/trimui_osd/osd_toast_ms2
}

# Auto-launch if sourced with --launch flag
if [ "$1" = "--launch" ]; then
    launch_osd "$2"
fi
