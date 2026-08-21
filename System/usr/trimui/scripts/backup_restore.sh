#!/bin/sh
# backup_restore.sh - Backup and Restore System for JukaMix
# Backs up and restores user settings, saves, and configurations

BACKUP_DIR="/mnt/SDCARD/trimui/backups"
CONFIG_DIR="/mnt/SDCARD/System/etc"
SAVE_DIR="/mnt/SDCARD/trimui"
LOG_FILE="/tmp/backup_restore.log"

# Create backup directory
mkdir -p "$BACKUP_DIR" 2>/dev/null

# ── Logging ────────────────────────────────────────────────────────────
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [backup] $1" >> "$LOG_FILE" 2>/dev/null
}

# ── Get device info ────────────────────────────────────────────────────
get_device_info() {
    device=$(cat /etc/trimui_device.txt 2>/dev/null || echo "unknown")
    serial=$(cat /sys/firmware/devicetree/base/serial-number 2>/dev/null || echo "unknown")
    echo "${device}_${serial}"
}

# ── Create backup ──────────────────────────────────────────────────────
create_backup() {
    backup_name="${1:-manual}"
    timestamp=$(date +%Y%m%d_%H%M%S)
    device_info=$(get_device_info)
    backup_file="$BACKUP_DIR/${device_info}_${backup_name}_${timestamp}.tar.gz"
    
    log "Creating backup: $backup_file"
    echo "Creating backup..."
    
    # Create temporary file list
    file_list=$(mktemp)
    
    # Add configuration files
    [ -f "$CONFIG_DIR/jukamix.json" ] && echo "$CONFIG_DIR/jukamix.json" >> "$file_list"
    [ -d "$CONFIG_DIR/profiles" ] && find "$CONFIG_DIR/profiles" -type f >> "$file_list"
    [ -f "$CONFIG_DIR/keyremap.conf" ] && echo "$CONFIG_DIR/keyremap.conf" >> "$file_list"
    [ -f "$CONFIG_DIR/button_mapping.conf" ] && echo "$CONFIG_DIR/button_mapping.conf" >> "$file_list"
    
    # Add user data
    [ -d "$SAVE_DIR/autosave" ] && find "$SAVE_DIR/autosave" -type f >> "$file_list"
    [ -d "$SAVE_DIR/favorites" ] && find "$SAVE_DIR/favorites" -type f >> "$file_list"
    [ -d "$SAVE_DIR/game_notes" ] && find "$SAVE_DIR/game_notes" -type f >> "$file_list"
    [ -d "$SAVE_DIR/play_history" ] && find "$SAVE_DIR/play_history" -type f >> "$file_list"
    [ -d "$SAVE_DIR/quick_menu" ] && find "$SAVE_DIR/quick_menu" -type f >> "$file_list"
    
    # Add theme customizations
    [ -d "$SAVE_DIR/theme" ] && find "$SAVE_DIR/theme" -type f >> "$file_list"
    
    # Create backup archive
    if [ -s "$file_list" ]; then
        tar -czf "$backup_file" -T "$file_list" 2>/dev/null
        
        if [ $? -eq 0 ] && [ -f "$backup_file" ]; then
            backup_size=$(du -h "$backup_file" | cut -f1)
            log "Backup created: $backup_file ($backup_size)"
            echo "Backup created successfully!"
            echo "File: $backup_file"
            echo "Size: $backup_size"
            
            # Create backup info file
            cat > "$backup_file.info" << EOF
Device: $device_info
Date: $(date)
Backup: $backup_name
Size: $backup_size
Files: $(wc -l < "$file_list")
EOF
            
            rm -f "$file_list"
            return 0
        else
            log "Backup failed"
            echo "Backup failed!"
            rm -f "$file_list"
            return 1
        fi
    else
        log "No files to backup"
        echo "No files to backup"
        rm -f "$file_list"
        return 1
    fi
}

# ── Restore backup ─────────────────────────────────────────────────────
restore_backup() {
    backup_file="$1"
    
    if [ ! -f "$backup_file" ]; then
        log "Backup file not found: $backup_file"
        echo "Backup file not found!"
        return 1
    fi
    
    log "Restoring from: $backup_file"
    echo "Restoring from backup..."
    
    # Show backup info
    if [ -f "$backup_file.info" ]; then
        echo "Backup Info:"
        cat "$backup_file.info"
        echo ""
    fi
    
    # Create restore point
    restore_point="$BACKUP_DIR/pre_restore_$(date +%Y%m%d_%H%M%S).tar.gz"
    create_backup "pre_restore"
    
    # Restore files
    tar -xzf "$backup_file" -C / 2>/dev/null
    
    if [ $? -eq 0 ]; then
        log "Restore completed successfully"
        echo "Restore completed successfully!"
        
        # Apply restored configurations
        if [ -f "$CONFIG_DIR/jukamix.json" ]; then
            echo "Applying restored configurations..."
            # Reapply button mappings
            /mnt/SDCARD/System/usr/trimui/scripts/button_mapper.sh apply 2>/dev/null
        fi
        
        return 0
    else
        log "Restore failed"
        echo "Restore failed!"
        
        # Offer to restore from pre-restore point
        echo "A restore point was created before this attempt."
        echo "You can restore from: $restore_point"
        return 1
    fi
}

# ── List backups ────────────────────────────────────────────────────────
list_backups() {
    echo "Available Backups:"
    echo "=================="
    echo ""
    
    count=0
    for backup in "$BACKUP_DIR"/*.tar.gz; do
        [ -f "$backup" ] || continue
        
        backup_name=$(basename "$backup")
        backup_size=$(du -h "$backup" | cut -f1)
        backup_date=$(stat -c %y "$backup" 2>/dev/null | cut -d' ' -f1,2 | cut -d'.' -f1)
        
        echo "  [$((count + 1))] $backup_name"
        echo "      Size: $backup_size"
        echo "      Date: $backup_date"
        echo ""
        
        count=$((count + 1))
    done
    
    if [ "$count" -eq 0 ]; then
        echo "  No backups found"
    else
        echo "Total: $count backups"
    fi
}

# ── Delete backup ──────────────────────────────────────────────────────
delete_backup() {
    backup_file="$1"
    
    if [ ! -f "$backup_file" ]; then
        echo "Backup file not found!"
        return 1
    fi
    
    backup_name=$(basename "$backup_file")
    rm -f "$backup_file" "$backup_file.info" 2>/dev/null
    
    log "Deleted backup: $backup_name"
    echo "Deleted backup: $backup_name"
    return 0
}

# ── Auto backup ────────────────────────────────────────────────────────
auto_backup() {
    # Check if auto backup is enabled
    if [ -f "$CONFIG_DIR/jukamix.json" ] && command -v jq >/dev/null 2>&1; then
        enabled=$(jq -r '.["AUTO_BACKUP"] // "false"' "$CONFIG_DIR/jukamix.json" 2>/dev/null)
        if [ "$enabled" != "true" ]; then
            return 0
        fi
    fi
    
    # Check when last backup was made
    last_backup=$(ls -t "$BACKUP_DIR"/*.tar.gz 2>/dev/null | head -1)
    if [ -n "$last_backup" ]; then
        last_date=$(stat -c %Y "$last_backup" 2>/dev/null || echo "0")
        now=$(date +%s)
        days_old=$(( (now - last_date) / 86400 ))
        
        # Backup if older than 7 days
        if [ "$days_old" -lt 7 ]; then
            return 0
        fi
    fi
    
    echo "Running automatic backup..."
    create_backup "auto"
}

# ── Export to USB ───────────────────────────────────────────────────────
export_to_usb() {
    usb_mount="/mnt/USB"
    
    # Try to find USB device
    for dev in /dev/sd*; do
        if mountpoint -q "$usb_mount" 2>/dev/null; then
            break
        fi
        mount "$dev" "$usb_mount" 2>/dev/null
    done
    
    if ! mountpoint -q "$usb_mount" 2>/dev/null; then
        echo "No USB device found"
        return 1
    fi
    
    # Copy latest backup
    latest_backup=$(ls -t "$BACKUP_DIR"/*.tar.gz 2>/dev/null | head -1)
    if [ -n "$latest_backup" ]; then
        cp "$latest_backup" "$usb_mount/" 2>/dev/null
        cp "$latest_backup.info" "$usb_mount/" 2>/dev/null
        
        echo "Backup exported to USB"
        echo "File: $(basename "$latest_backup")"
        
        umount "$usb_mount" 2>/dev/null
        return 0
    else
        echo "No backup to export"
        umount "$usb_mount" 2>/dev/null
        return 1
    fi
}

# ── Main ───────────────────────────────────────────────────────────────
case "${1:-}" in
    backup)
        create_backup "${2:-manual}"
        ;;
    restore)
        if [ -n "${2:-}" ]; then
            restore_backup "$2"
        else
            echo "Usage: backup_restore.sh restore <backup_file>"
        fi
        ;;
    list)
        list_backups
        ;;
    delete)
        if [ -n "${2:-}" ]; then
            delete_backup "$2"
        else
            echo "Usage: backup_restore.sh delete <backup_file>"
        fi
        ;;
    auto)
        auto_backup
        ;;
    export)
        export_to_usb
        ;;
    *)
        echo "Backup and Restore System"
        echo "Usage: backup_restore.sh {backup|restore|list|delete|auto|export}"
        echo ""
        echo "Commands:"
        echo "  backup [name]     - Create a backup"
        echo "  restore <file>    - Restore from backup"
        echo "  list              - List available backups"
        echo "  delete <file>     - Delete a backup"
        echo "  auto              - Run automatic backup"
        echo "  export            - Export backup to USB"
        ;;
esac
