#!/bin/sh
# System/usr/trimui/scripts/screenshot_manager.sh
# Screenshot Manager - Take and manage screenshots

SCREENSHOTS_DIR="/mnt/SDCARD/Pictures/screenshots"
THUMBNAILS_DIR="/mnt/SDCARD/trimui/thumbnails"
LOG_FILE="/tmp/screenshot.log"

# Create directories
mkdir -p "$SCREENSHOTS_DIR" "$THUMBNAILS_DIR"

# Logging
log() {
    echo "$(date '+%H:%M:%S') [screenshot] $1" >> "$LOG_FILE"
}

# ── Take screenshot ────────────────────────────────────────────────────
take_screenshot() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local filename="screenshot_${timestamp}.png"
    local filepath="$SCREENSHOTS_DIR/$filename"
    
    # Try different screenshot methods
    if command -v screencap >/dev/null 2>&1; then
        screencap -p "$filepath" 2>/dev/null
    elif [ -d /tmp/trimui_osd ]; then
        # Use OSD screenshot if available
        echo "{\"type\":\"screenshot\",\"path\":\"$filepath\"}" > /tmp/trimui_osd/screenshot
        sleep 1
    else
        echo "Screenshot not available"
        return 1
    fi
    
    if [ -f "$filepath" ]; then
        log "Screenshot saved: $filename"
        echo "Screenshot saved: $filename"
        
        # Create thumbnail
        create_thumbnail "$filepath"
        
        # Show preview
        show_preview "$filepath"
    else
        echo "Failed to take screenshot"
        return 1
    fi
}

# ── Create thumbnail ───────────────────────────────────────────────────
create_thumbnail() {
    local image="$1"
    local filename=$(basename "$image")
    local thumbnail="$THUMBNAILS_DIR/$filename"
    
    # Try ImageMagick
    if command -v convert >/dev/null 2>&1; then
        convert "$image" -resize 160x120 "$thumbnail" 2>/dev/null
    # Try ffmpeg
    elif command -v ffmpeg >/dev/null 2>&1; then
        ffmpeg -i "$image" -vf "scale=160:120" "$thumbnail" -y 2>/dev/null
    else
        # Just copy the file
        cp "$image" "$thumbnail" 2>/dev/null
    fi
}

# ── Show preview ───────────────────────────────────────────────────────
show_preview() {
    local image="$1"
    local filename=$(basename "$image")
    
    echo "Screenshot taken: $filename"
    echo "Location: $image"
    echo ""
    echo "Press any button to continue..."
    # Wait for any button press (controller-compatible)
    timeout 3 /mnt/SDCARD/System/usr/trimui/scripts/evtest /dev/input/event0 2>/dev/null | head -1 > /dev/null 2>&1
}

# ── List screenshots ───────────────────────────────────────────────────
list_screenshots() {
    echo "Screenshots:"
    echo ""
    
    ls -lt "$SCREENSHOTS_DIR"/*.png 2>/dev/null | head -20 | while read -r line; do
        local filename=$(echo "$line" | awk '{print $NF}')
        local size=$(echo "$line" | awk '{print $5}')
        local date=$(echo "$line" | awk '{print $6, $7, $8}')
        echo "  $filename ($size bytes) - $date"
    done
    
    local count=$(ls "$SCREENSHOTS_DIR"/*.png 2>/dev/null | wc -l)
    echo ""
    echo "Total: $count screenshots"
}

# ── Delete screenshot ──────────────────────────────────────────────────
delete_screenshot() {
    local filename="$1"
    local filepath="$SCREENSHOTS_DIR/$filename"
    local thumbnail="$THUMBNAILS_DIR/$filename"
    
    if [ ! -f "$filepath" ]; then
        echo "Screenshot not found: $filename"
        return 1
    fi
    
    rm -f "$filepath" "$thumbnail"
    log "Deleted: $filename"
    echo "Deleted: $filename"
}

# ── Delete all screenshots ─────────────────────────────────────────────
delete_all() {
    local count=$(ls "$SCREENSHOTS_DIR"/*.png 2>/dev/null | wc -l)
    
    if [ "$count" -eq 0 ]; then
        echo "No screenshots to delete"
        return
    fi
    
    # Auto-delete without confirmation (no keyboard on device)
    rm -f "$SCREENSHOTS_DIR"/*.png "$THUMBNAILS_DIR"/*.png 2>/dev/null
    log "Deleted all screenshots"
    echo "Deleted all screenshots"
}

# ── Export screenshots ─────────────────────────────────────────────────
export_screenshots() {
    local export_dir="${1:-/mnt/SDCARD/screenshots_export}"
    
    mkdir -p "$export_dir"
    cp "$SCREENSHOTS_DIR"/*.png "$export_dir" 2>/dev/null
    
    echo "Exported to: $export_dir"
}

# ── Main ──────────────────────────────────────────────────────────────
case "${1:-}" in
    take|shot|capture)
        take_screenshot
        ;;
    list|ls)
        list_screenshots
        ;;
    delete)
        delete_screenshot "$2"
        ;;
    deleteall)
        delete_all
        ;;
    export)
        export_screenshots "$2"
        ;;
    *)
        echo "Screenshot Manager"
        echo "=================="
        echo ""
        echo "Usage: screenshot_manager.sh {command} [args]" >&2
        echo "" >&2
        echo "Commands:" >&2
        echo "  take/shot    - Take a screenshot" >&2
        echo "  list         - List all screenshots" >&2
        echo "  delete <fn>  - Delete a screenshot" >&2
        echo "  deleteall    - Delete all screenshots" >&2
        echo "  export [dir] - Export screenshots" >&2
        exit 1
        ;;
esac
