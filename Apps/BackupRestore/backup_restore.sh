#!/bin/sh
# Apps/BackupRestore/backup_restore.sh
# Backup & Restore - Backup and restore saves, settings, and themes

BACKUP_DIR="/mnt/SDCARD/trimui/backups"
SD_ROOT="/mnt/SDCARD"
LOG_FILE="/tmp/backup_restore.log"

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Logging
log() {
    echo "$(date '+%H:%M:%S') [backup] $1" >> "$LOG_FILE"
}

# ── Create backup ──────────────────────────────────────────────────────
create_backup() {
    local name="${1:-backup_$(date +%Y%m%d_%H%M%S)}"
    local backup_path="$BACKUP_DIR/$name"
    
    mkdir -p "$backup_path"
    
    echo "Creating backup: $name"
    echo ""
    
    # Backup saves
    echo "Backing up saves..."
    if [ -d "$SD_ROOT/Saves" ]; then
        cp -r "$SD_ROOT/Saves" "$backup_path/" 2>/dev/null
        echo "  ✓ Saves"
    fi
    
    # Backup states
    echo "Backing up states..."
    if [ -d "$SD_ROOT/States" ]; then
        cp -r "$SD_ROOT/States" "$backup_path/" 2>/dev/null
        echo "  ✓ States"
    fi
    
    # Backup BIOS
    echo "Backing up BIOS..."
    if [ -d "$SD_ROOT/BIOS" ]; then
        cp -r "$SD_ROOT/BIOS" "$backup_path/" 2>/dev/null
        echo "  ✓ BIOS"
    fi
    
    # Backup RetroArch config
    echo "Backing up RetroArch config..."
    if [ -d "$SD_ROOT/RetroArch/.retroarch" ]; then
        mkdir -p "$backup_path/RetroArch"
        cp -r "$SD_ROOT/RetroArch/.retroarch/retroarch.cfg" "$backup_path/RetroArch/" 2>/dev/null
        cp -r "$SD_ROOT/RetroArch/.retroarch/autoconfig" "$backup_path/RetroArch/" 2>/dev/null
        echo "  ✓ RetroArch config"
    fi
    
    # Backup profiles
    echo "Backing up profiles..."
    if [ -d "$SD_ROOT/Profiles" ]; then
        cp -r "$SD_ROOT/Profiles" "$backup_path/" 2>/dev/null
        echo "  ✓ Profiles"
    fi
    
    # Backup themes
    echo "Backing up themes..."
    if [ -d "$SD_ROOT/Themes" ]; then
        cp -r "$SD_ROOT/Themes" "$backup_path/" 2>/dev/null
        echo "  ✓ Themes"
    fi
    
    # Backup favorites
    echo "Backing up favorites..."
    if [ -d "$SD_ROOT/trimui/favorites" ]; then
        cp -r "$SD_ROOT/trimui/favorites" "$backup_path/" 2>/dev/null
        echo "  ✓ Favorites"
    fi
    
    # Backup play time
    echo "Backing up play time..."
    if [ -d "$SD_ROOT/trimui/playtime" ]; then
        cp -r "$SD_ROOT/trimui/playtime" "$backup_path/" 2>/dev/null
        echo "  ✓ Play time"
    fi
    
    # Create manifest
    echo ""
    echo "Creating manifest..."
    find "$backup_path" -type f | sort > "$backup_path/manifest.txt"
    
    # Calculate size
    local size=$(du -sh "$backup_path" 2>/dev/null | awk '{print $1}')
    
    log "Backup created: $name ($size)"
    echo ""
    echo "✓ Backup complete: $name"
    echo "  Size: $size"
    echo "  Location: $backup_path"
}

# ── Restore backup ─────────────────────────────────────────────────────
restore_backup() {
    local name="$1"
    local backup_path="$BACKUP_DIR/$name"
    
    if [ ! -d "$backup_path" ]; then
        echo "Backup not found: $name"
        return 1
    fi
    
    echo "Restoring backup: $name"
    echo ""
    echo "WARNING: This will overwrite current data!"
    echo "Press 'y' to continue, any other key to cancel."
    read -r confirm
    
    if [ "$confirm" != "y" ]; then
        echo "Cancelled"
        return
    fi
    
    # Restore saves
    if [ -d "$backup_path/Saves" ]; then
        echo "Restoring saves..."
        cp -r "$backup_path/Saves" "$SD_ROOT/" 2>/dev/null
        echo "  ✓ Saves"
    fi
    
    # Restore states
    if [ -d "$backup_path/States" ]; then
        echo "Restoring states..."
        cp -r "$backup_path/States" "$SD_ROOT/" 2>/dev/null
        echo "  ✓ States"
    fi
    
    # Restore BIOS
    if [ -d "$backup_path/BIOS" ]; then
        echo "Restoring BIOS..."
        cp -r "$backup_path/BIOS" "$SD_ROOT/" 2>/dev/null
        echo "  ✓ BIOS"
    fi
    
    # Restore RetroArch config
    if [ -d "$backup_path/RetroArch" ]; then
        echo "Restoring RetroArch config..."
        mkdir -p "$SD_ROOT/RetroArch/.retroarch"
        cp -r "$backup_path/RetroArch/"* "$SD_ROOT/RetroArch/.retroarch/" 2>/dev/null
        echo "  ✓ RetroArch config"
    fi
    
    # Restore profiles
    if [ -d "$backup_path/Profiles" ]; then
        echo "Restoring profiles..."
        cp -r "$backup_path/Profiles" "$SD_ROOT/" 2>/dev/null
        echo "  ✓ Profiles"
    fi
    
    # Restore themes
    if [ -d "$backup_path/Themes" ]; then
        echo "Restoring themes..."
        cp -r "$backup_path/Themes" "$SD_ROOT/" 2>/dev/null
        echo "  ✓ Themes"
    fi
    
    # Restore favorites
    if [ -d "$backup_path/favorites" ]; then
        echo "Restoring favorites..."
        mkdir -p "$SD_ROOT/trimui/favorites"
        cp -r "$backup_path/favorites/"* "$SD_ROOT/trimui/favorites/" 2>/dev/null
        echo "  ✓ Favorites"
    fi
    
    # Restore play time
    if [ -d "$backup_path/playtime" ]; then
        echo "Restoring play time..."
        mkdir -p "$SD_ROOT/trimui/playtime"
        cp -r "$backup_path/playtime/"* "$SD_ROOT/trimui/playtime/" 2>/dev/null
        echo "  ✓ Play time"
    fi
    
    log "Backup restored: $name"
    echo ""
    echo "✓ Restore complete!"
    echo "  Please restart for changes to take effect."
}

# ── List backups ───────────────────────────────────────────────────────
list_backups() {
    echo "Available backups:"
    echo ""
    
    local count=0
    
    for backup in "$BACKUP_DIR"/*/; do
        [ -d "$backup" ] || continue
        
        local name=$(basename "$backup")
        local size=$(du -sh "$backup" 2>/dev/null | awk '{print $1}')
        local date=$(stat -c "%y" "$backup" 2>/dev/null | cut -d. -f1)
        
        echo "  $name"
        echo "    Size: $size"
        echo "    Date: $date"
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
    local name="$1"
    local backup_path="$BACKUP_DIR/$name"
    
    if [ ! -d "$backup_path" ]; then
        echo "Backup not found: $name"
        return 1
    fi
    
    echo "Delete backup: $name? (y/n)"
    read -r confirm
    
    if [ "$confirm" = "y" ]; then
        rm -rf "$backup_path"
        log "Deleted backup: $name"
        echo "Deleted: $name"
    else
        echo "Cancelled"
    fi
}

# ── Export backup ──────────────────────────────────────────────────────
export_backup() {
    local name="$1"
    local export_dir="${2:-/mnt/SDCARD}"
    local backup_path="$BACKUP_DIR/$name"
    
    if [ ! -d "$backup_path" ]; then
        echo "Backup not found: $name"
        return 1
    fi
    
    local export_file="$export_dir/${name}.tar.gz"
    
    echo "Exporting backup: $name"
    tar -czf "$export_file" -C "$BACKUP_DIR" "$name" 2>/dev/null
    
    if [ -f "$export_file" ]; then
        local size=$(du -sh "$export_file" 2>/dev/null | awk '{print $1}')
        log "Exported backup: $name ($size)"
        echo "✓ Exported to: $export_file"
        echo "  Size: $size"
    else
        echo "Export failed"
    fi
}

# ── Import backup ──────────────────────────────────────────────────────
import_backup() {
    local import_file="$1"
    
    if [ ! -f "$import_file" ]; then
        echo "File not found: $import_file"
        return 1
    fi
    
    echo "Importing backup..."
    tar -xzf "$import_file" -C "$BACKUP_DIR" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        local name=$(tar -tzf "$import_file" 2>/dev/null | head -1 | cut -d/ -f1)
        log "Imported backup: $name"
        echo "✓ Imported: $name"
    else
        echo "Import failed"
    fi
}

# ── Main ──────────────────────────────────────────────────────────────
case "${1:-}" in
    create|backup)
        create_backup "$2"
        ;;
    restore)
        restore_backup "$2"
        ;;
    list|ls)
        list_backups
        ;;
    delete)
        delete_backup "$2"
        ;;
    export)
        export_backup "$2" "$3"
        ;;
    import)
        import_backup "$2"
        ;;
    *)
        echo "Backup & Restore"
        echo "================"
        echo ""
        echo "Usage: backup_restore.sh {command} [args]" >&2
        echo "" >&2
        echo "Commands:" >&2
        echo "  create [name]    - Create new backup" >&2
        echo "  restore <name>   - Restore backup" >&2
        echo "  list             - List all backups" >&2
        echo "  delete <name>    - Delete backup" >&2
        echo "  export <name>    - Export backup to file" >&2
        echo "  import <file>    - Import backup from file" >&2
        exit 1
        ;;
esac
