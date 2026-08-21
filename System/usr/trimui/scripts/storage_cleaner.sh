#!/bin/sh
# storage_cleaner.sh - Storage Cleanup and Optimization for JukaMix
# Cleans temporary files, caches, and optimizes storage

LOG_FILE="/tmp/storage_cleaner.log"
CACHE_DIR="/tmp"
SDCARD="/mnt/SDCARD"

# ── Logging ────────────────────────────────────────────────────────────
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [cleaner] $1" >> "$LOG_FILE" 2>/dev/null
}

# ── Get storage info ───────────────────────────────────────────────────
get_storage_info() {
    mount_point="${1:-$SDCARD}"
    
    if mountpoint -q "$mount_point" 2>/dev/null; then
        total=$(df "$mount_point" 2>/dev/null | tail -1 | awk '{print $2}')
        used=$(df "$mount_point" 2>/dev/null | tail -1 | awk '{print $3}')
        available=$(df "$mount_point" 2>/dev/null | tail -1 | awk '{print $4}')
        
        # Convert to MB
        total_mb=$((total / 1024))
        used_mb=$((used / 1024))
        available_mb=$((available / 1024))
        
        echo "Storage: ${used_mb}MB used / ${total_mb}MB total (${available_mb}MB free)"
    else
        echo "Storage: Not mounted"
    fi
}

# ── Clean temporary files ──────────────────────────────────────────────
clean_temp_files() {
    echo "Cleaning temporary files..."
    
    # System temp files
    cleaned=0
    
    # Clean /tmp (keep important files)
    for file in "$CACHE_DIR"/*; do
        [ -f "$file" ] || continue
        
        # Don't clean important files
        case "$(basename "$file")" in
            boot_in_progress|infoscreen_disabled|infoscreen.pid)
                continue
                ;;
        esac
        
        # Clean old temp files (older than 1 day)
        if [ -f "$file" ]; then
            file_age=$(find "$file" -mtime +1 2>/dev/null)
            if [ -n "$file_age" ]; then
                rm -f "$file" 2>/dev/null
                cleaned=$((cleaned + 1))
            fi
        fi
    done
    
    # Clean RetroArch temp files
    rm -f "$CACHE_DIR"/retroarch_* 2>/dev/null
    
    # Clean PPSSPP temp files
    rm -f "$CACHE_DIR"/ppsspp_* 2>/dev/null
    
    log "Cleaned $cleaned temporary files"
    echo "Cleaned $cleaned temporary files"
}

# ── Clean caches ────────────────────────────────────────────────────────
clean_caches() {
    echo "Cleaning caches..."
    
    cleaned=0
    
    # Clean application caches
    find "$SDCARD" -name "*.cache" -type f -mtime +7 2>/dev/null | while read -r cache; do
        rm -f "$cache" 2>/dev/null
        cleaned=$((cleaned + 1))
    done
    
    # Clean browser cache (if exists)
    rm -rf "$SDCARD"/trimui/browser/cache/* 2>/dev/null
    
    # Clean package cache
    rm -rf "$SDCARD"/trimui/opkg/cache/* 2>/dev/null
    
    # Clean thumbnail cache (older than 30 days)
    find "$SDCARD" -name "*.thumb" -type f -mtime +30 2>/dev/null | while read -r thumb; do
        rm -f "$thumb" 2>/dev/null
        cleaned=$((cleaned + 1))
    done
    
    log "Cleaned caches"
    echo "Caches cleaned"
}

# ── Clean logs ──────────────────────────────────────────────────────────
clean_logs() {
    echo "Cleaning logs..."
    
    cleaned=0
    
    # Clean system logs (older than 7 days)
    find "$SDCARD" -name "*.log" -type f -mtime +7 2>/dev/null | while read -r log_file; do
        rm -f "$log_file" 2>/dev/null
        cleaned=$((cleaned + 1))
    done
    
    # Clean RetroArch logs
    rm -f "$SDCARD"/RetroArch/.retroarch/logs/* 2>/dev/null
    
    # Clean crash dumps (older than 30 days)
    find "$SDCARD" -name "core.*" -type f -mtime +30 2>/dev/null | while read -r dump; do
        rm -f "$dump" 2>/dev/null
        cleaned=$((cleaned + 1))
    done
    
    log "Cleaned $cleaned log files"
    echo "Cleaned $cleaned log files"
}

# ── Clean duplicates ────────────────────────────────────────────────────
clean_duplicates() {
    echo "Checking for duplicate files..."
    
    # Find duplicate ROMs (same name, different locations)
    find "$SDCARD/Roms" -type f \( -name "*.zip" -o -name "*.rom" -o -name "*.bin" \) 2>/dev/null | while read -r rom; do
        rom_name=$(basename "$rom")
        
        # Find other files with same name
        duplicates=$(find "$SDCARD/Roms" -name "$rom_name" -type f 2>/dev/null | wc -l)
        
        if [ "$duplicates" -gt 1 ]; then
            log "Duplicate found: $rom_name ($duplicates copies)"
        fi
    done
    
    echo "Duplicate check complete"
}

# ── Optimize storage ────────────────────────────────────────────────────
optimize_storage() {
    echo "Optimizing storage..."
    
    # Defragment if possible (for ext4)
    if command -v e4defrag >/dev/null 2>&1; then
        e4defrag "$SDCARD" 2>/dev/null
    fi
    
    # Sync filesystem
    sync
    
    log "Storage optimized"
    echo "Storage optimized"
}

# ── Show storage breakdown ──────────────────────────────────────────────
show_breakdown() {
    echo "Storage Breakdown:"
    echo "=================="
    echo ""
    
    # Calculate sizes for major directories
    for dir in Roms BIOS saves states screenshots RetroArch; do
        if [ -d "$SDCARD/$dir" ]; then
            size=$(du -sh "$SDCARD/$dir" 2>/dev/null | cut -f1)
            echo "  $dir: $size"
        fi
    done
    
    echo ""
    get_storage_info
}

# ── Full cleanup ────────────────────────────────────────────────────────
full_cleanup() {
    echo "Running full cleanup..."
    echo ""
    
    # Get initial size
    initial_size=$(du -sh "$SDCARD" 2>/dev/null | cut -f1)
    echo "Initial size: $initial_size"
    echo ""
    
    # Run all cleanup tasks
    clean_temp_files
    clean_caches
    clean_logs
    
    echo ""
    
    # Get final size
    final_size=$(du -sh "$SDCARD" 2>/dev/null | cut -f1)
    echo "Final size: $final_size"
    echo ""
    
    # Calculate saved space
    echo "Cleanup complete!"
    get_storage_info
    
    log "Full cleanup completed"
}

# ── Main ───────────────────────────────────────────────────────────────
case "${1:-}" in
    temp)
        clean_temp_files
        ;;
    cache)
        clean_caches
        ;;
    logs)
        clean_logs
        ;;
    duplicates)
        clean_duplicates
        ;;
    optimize)
        optimize_storage
        ;;
    breakdown)
        show_breakdown
        ;;
    full)
        full_cleanup
        ;;
    status)
        get_storage_info
        ;;
    *)
        echo "Storage Cleanup and Optimization"
        echo "Usage: storage_cleaner.sh {temp|cache|logs|duplicates|optimize|breakdown|full|status}"
        echo ""
        echo "Commands:"
        echo "  temp        - Clean temporary files"
        echo "  cache       - Clean application caches"
        echo "  logs        - Clean log files"
        echo "  duplicates  - Check for duplicate files"
        echo "  optimize    - Optimize storage"
        echo "  breakdown   - Show storage breakdown"
        echo "  full        - Run full cleanup"
        echo "  status      - Show storage status"
        ;;
esac
