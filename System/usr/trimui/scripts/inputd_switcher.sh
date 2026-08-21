#!/usr/bin/env sh
PATH="/mnt/SDCARD/System/bin:/mnt/SDCARD/System/usr/trimui/scripts:$PATH"
export LD_LIBRARY_PATH="/mnt/SDCARD/System/lib:/usr/trimui/lib:$LD_LIBRARY_PATH"

# ── Safeguards ────────────────────────────────────────────────────────
# Ensure required directories exist
mkdir -p /mnt/SDCARD/trimui/app 2>/dev/null
mkdir -p /mnt/SDCARD/System/etc 2>/dev/null
mkdir -p /tmp 2>/dev/null

# ── Get script name and polling rate ──────────────────────────────────
script_name=$(basename "$0" .sh)
if [ "$script_name" = "inputd_switcher" ]; then
    # Get polling rate from config, default to 16ms if not set
    json_file="/mnt/SDCARD/System/etc/jukamix.json"
    polling_rate=""
    
    if [ -f "$json_file" ] && command -v jq >/dev/null 2>&1; then
        polling_rate=$(jq -r '.["POLLING RATE"] // empty' "$json_file" 2>/dev/null)
    fi
    
    # Default to 16ms (stock) if not configured or jq not available
    polling_rate="${polling_rate:-16ms}"
else
    polling_rate="$script_name"
fi

# Validate polling rate
case "$polling_rate" in
    "1ms"|"8ms"|"16ms") ;;  # Valid
    *) polling_rate="16ms" ;;  # Default to 16ms for invalid values
esac

bin_dir="/mnt/SDCARD/trimui/app"

# ── Get device type ───────────────────────────────────────────────────
# Default device if file not found
device="tsp"  # Default to TSP (safest default)
if [ -f /etc/trimui_device.txt ]; then
    read -r device < /etc/trimui_device.txt 2>/dev/null || device="tsp"
fi

# Sanitize device name
device=$(echo "$device" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')

# Brick and Brick Pro use the same inputd as TSP (horizontal layout)
case "$device" in
    brick|brick_pro)
        device="tsp"
        ;;
esac

# ── Find input daemon ─────────────────────────────────────────────────
# Use the device-specific input daemon when present; otherwise fall back to the
# Smart Pro (tsp) daemon.
src_inputd="/mnt/SDCARD/System/resources/${device}_inputd"
if [ ! -f "$src_inputd" ]; then
    src_inputd="/mnt/SDCARD/System/resources/tsp_inputd"
fi

# Last resort: try any available inputd
if [ ! -f "$src_inputd" ]; then
    src_inputd=$(ls /mnt/SDCARD/System/resources/*_inputd 2>/dev/null | head -1)
fi

if [ ! -f "$src_inputd" ]; then
    # Silently fail during boot
    if [ ! -f /tmp/boot_in_progress ]; then
        infoscreen -m "No input daemon available for device '$device'" -t 2 2>/dev/null
    fi
    exit 1
fi

# ── Install input daemon ──────────────────────────────────────────────
if [ -w "$bin_dir" ]; then
    cp "$src_inputd" "$bin_dir/trimui_inputd" 2>/dev/null
    if [ $? -eq 0 ]; then
        chmod +x "$bin_dir/trimui_inputd" 2>/dev/null
        sync
    else
        exit 1
    fi
else
    exit 1
fi

# ── Set polling rate ──────────────────────────────────────────────────
case "$polling_rate" in
    "1ms")
        echo 1000 > "$bin_dir/inputd_polling_rate.cfg" 2>/dev/null
        ;;
    "8ms")
        echo 8000 > "$bin_dir/inputd_polling_rate.cfg" 2>/dev/null
        ;;
    "16ms")
        rm -f "$bin_dir/inputd_polling_rate.cfg" 2>/dev/null
        ;;
esac

sync

# ── Update configuration ──────────────────────────────────────────────
json_file="/mnt/SDCARD/System/etc/jukamix.json"
if [ ! -f "$json_file" ]; then
    echo '{}' > "$json_file" 2>/dev/null
fi

# Update jukamix.json with polling rate
if command -v jq >/dev/null 2>&1 && [ -w "$json_file" ]; then
    jq --arg polling_rate "$polling_rate" '. += {"POLLING RATE": $polling_rate}' "$json_file" > "/tmp/json_file.tmp" 2>/dev/null && \
    mv "/tmp/json_file.tmp" "$json_file" 2>/dev/null
fi

# Update System Tools database
if [ -f "/mnt/SDCARD/System/usr/trimui/scripts/mainui_state_update.sh" ]; then
    /mnt/SDCARD/System/usr/trimui/scripts/mainui_state_update.sh "POLLING RATE" "$polling_rate" 2>/dev/null
fi

# ── Apply changes (only when NOT during boot) ─────────────────────────
# During boot, the caller handles this via boot_in_progress flag
# Also respect infoscreen_disabled flag set during boot sequence
if [ -f /tmp/boot_in_progress ] || [ -f /tmp/infoscreen_disabled ]; then
    # During boot or infoscreen disabled, just apply silently
    echo "Applying $polling_rate polling rate (boot mode)..."
else
    # Show message with timeout
    /mnt/SDCARD/System/usr/trimui/scripts/infoscreen.sh -m "Applying $polling_rate polling rate..." -t 1 2>/dev/null
    
    # Restart input daemon
    pkill trimui_inputd 2>/dev/null
    
    # Only kill MainUI if we're not in boot mode
    sleep 1
    pkill -KILL MainUI 2>/dev/null
fi

exit 0
