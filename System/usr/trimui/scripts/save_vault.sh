#!/bin/sh
# save_vault.sh - Save Vault Manager for JukaMix
# Manages save files with backups, history, and export
# POSIX-compatible, no bashisms, works on TrimUI devices

SAVE_DIR="/mnt/SDCARD/saves"
BACKUP_DIR="/mnt/SDCARD/trimui/save_vault/backups"
HISTORY_DIR="/mnt/SDCARD/trimui/save_vault/history"
LOG_FILE="/tmp/save_vault.log"

# Create directories
mkdir -p "$SAVE_DIR" "$BACKUP_DIR" "$HISTORY_DIR" 2>/dev/null

# ── Logging ────────────────────────────────────────────────────────────
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [vault] $1" >> "$LOG_FILE" 2>/dev/null
}

# ── Safe file info helpers ─────────────────────────────────────────────
get_file_size() {
    file="$1"
    if [ -f "$file" ]; then
        ls -lh "$file" 2>/dev/null | awk '{print $5}'
    else
        echo "?"
    fi
}

get_file_date() {
    file="$1"
    if [ -f "$file" ]; then
        stat -c '%Y' "$file" 2>/dev/null || stat -f '%m' "$file" 2>/dev/null
    else
        echo "0"
    fi
}

format_timestamp() {
    ts="$1"
    if [ -n "$ts" ]; then
        date -d "@$ts" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date -r "$ts" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "$ts"
    else
        echo "?"
    fi
}

# ── Validate save file ─────────────────────────────────────────────────
validate_save() {
    file="$1"
    [ -f "$file" ] || return 1
    [ -s "$file" ] || return 1  # Not empty
    [ -r "$file" ] || return 1  # Readable
    return 0
}

# ── List saves ─────────────────────────────────────────────────────────
list_saves() {
    system="${1:-all}"

    echo "╔══════════════════════════════════════╗"
    echo "║         JukaMix Save Vault           ║"
    echo "╠══════════════════════════════════════╣"

    if [ "$system" = "all" ]; then
        # Check if save directory exists and has contents
        if [ ! -d "$SAVE_DIR" ] || [ -z "$(find "$SAVE_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null)" ]; then
            echo "║ No saves found"
            echo "╚══════════════════════════════════════╝"
            return 0
        fi

        # List all systems
        find "$SAVE_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort | while read -r sys_dir; do
            sys_name=$(basename "$sys_dir")
            sav_count=0
            state_count=0
            find "$sys_dir" -name "*.sav" 2>/dev/null | while read -r f; do sav_count=$((sav_count + 1)); done
            find "$sys_dir" -name "*.state" 2>/dev/null | while read -r f; do state_count=$((state_count + 1)); done
            total=$((sav_count + state_count))
            if [ "$total" -gt 0 ]; then
                echo "║ $sys_name: $total saves"
            fi
        done
    else
        # List specific system
        sys_dir="$SAVE_DIR/$system"
        if [ ! -d "$sys_dir" ]; then
            echo "║ System not found: $system"
            echo "╚══════════════════════════════════════╝"
            return 1
        fi

        found=0
        find "$sys_dir" -name "*.sav" -o -name "*.state" 2>/dev/null | while read -r save; do
            [ -f "$save" ] || continue
            game=$(basename "$save" | sed 's/\.[^.]*$//')
            size=$(get_file_size "$save")
            ts=$(get_file_date "$save")
            date_str=$(format_timestamp "$ts")
            echo "║ $game ($size) - $date_str"
            found=$((found + 1))
        done

        if [ "$found" -eq 0 ]; then
            echo "║ No saves for $system"
        fi
    fi

    echo "╚══════════════════════════════════════╝"
}

# ── Backup save ────────────────────────────────────────────────────────
backup_save() {
    save_file="$1"

    if [ -z "$save_file" ]; then
        echo "Usage: save_vault.sh backup <save_file>"
        return 1
    fi

    if ! validate_save "$save_file"; then
        echo "Error: Save file not found, empty, or unreadable"
        return 1
    fi

    game=$(basename "$save_file" | sed 's/\.[^.]*$//')
    # Detect system from path
    # e.g. /mnt/SDCARD/saves/GBA/game.sav -> GBA
    system=$(echo "$save_file" | sed "s|${SAVE_DIR}/||" | cut -d'/' -f1)
    [ -z "$system" ] && system="unknown"
    timestamp=$(date +%Y%m%d_%H%M%S)

    # Create backup
    backup_file="$BACKUP_DIR/$system/${game}_${timestamp}.sav"
    mkdir -p "$(dirname "$backup_file")" 2>/dev/null

    if cp "$save_file" "$backup_file" 2>/dev/null; then
        # Record in history
        mkdir -p "$HISTORY_DIR" 2>/dev/null
        echo "${timestamp}|${game}|${system}|${backup_file}" >> "$HISTORY_DIR/${game}.history" 2>/dev/null

        log "Backed up: $game -> $backup_file"
        echo "Backup created: $(basename "$backup_file")"
        return 0
    else
        echo "Error: Failed to create backup"
        return 1
    fi
}

# ── Restore save ───────────────────────────────────────────────────────
restore_save() {
    game="$1"
    backup_file="$2"

    if [ -z "$game" ]; then
        echo "Usage: save_vault.sh restore <game> [backup_file]"
        return 1
    fi

    if [ -z "$backup_file" ]; then
        # Show available backups
        echo "Available backups for $game:"
        echo "============================"

        found=0
        find "$BACKUP_DIR" -name "${game}_*.sav" 2>/dev/null | sort -r | while read -r backup; do
            [ -f "$backup" ] || continue
            size=$(get_file_size "$backup")
            ts=$(get_file_date "$backup")
            date_str=$(format_timestamp "$ts")
            echo "  $(basename "$backup") ($size) - $date_str"
            found=$((found + 1))
        done

        echo ""
        echo "To restore: save_vault.sh restore $game <backup_file>"
        return 0
    fi

    if ! validate_save "$backup_file"; then
        echo "Error: Backup file not found or empty"
        return 1
    fi

    # Find current save location
    current_save=""
    find "$SAVE_DIR" -name "${game}.*" -type f 2>/dev/null | while read -r f; do
        case "$f" in
            *.sav|*.state) current_save="$f"; break ;;
        esac
    done

    # If we found a save via find in a subshell, re-find it
    if [ -z "$current_save" ]; then
        # Try common extensions
        for ext in sav state; do
            found=$(find "$SAVE_DIR" -name "${game}.${ext}" -type f 2>/dev/null | head -1)
            if [ -n "$found" ] && [ -f "$found" ]; then
                current_save="$found"
                break
            fi
        done
    fi

    if [ -z "$current_save" ]; then
        # If no existing save, place it in the first system directory
        first_sys=$(find "$SAVE_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | head -1)
        if [ -n "$first_sys" ]; then
            current_save="$first_sys/${game}.sav"
        else
            echo "Error: No save directory found for $game"
            return 1
        fi
    fi

    # Backup current save before restoring
    if validate_save "$current_save"; then
        echo "Backing up current save before restore..."
        backup_save "$current_save"
    fi

    # Restore
    mkdir -p "$(dirname "$current_save")" 2>/dev/null
    if cp "$backup_file" "$current_save" 2>/dev/null; then
        log "Restored: $backup_file -> $current_save"
        echo "Restored: $game -> $(basename "$current_save")"
        return 0
    else
        echo "Error: Failed to restore save"
        return 1
    fi
}

# ── Show history ───────────────────────────────────────────────────────
show_history() {
    game="$1"

    if [ -z "$game" ]; then
        echo "Usage: save_vault.sh history <game>"
        return 1
    fi

    history_file="$HISTORY_DIR/${game}.history"

    if [ ! -f "$history_file" ]; then
        echo "No history for $game"
        return 0
    fi

    echo "Save history for $game:"
    echo "========================"

    # Read last 20 entries, format timestamps
    tail -20 "$history_file" | while IFS='|' read -r timestamp game_name system backup; do
        [ -z "$timestamp" ] && continue
        date_str=$(format_timestamp "$timestamp")
        exists="  "
        [ -f "$backup" ] && exists="OK"
        echo "  [$exists] $date_str - $system"
    done
}

# ── Export saves ────────────────────────────────────────────────────────
export_saves() {
    game="$1"
    output="${2:-/mnt/SDCARD/${game}_saves.zip}"

    if [ -z "$game" ]; then
        echo "Usage: save_vault.sh export <game> [output_file]"
        return 1
    fi

    if ! command -v zip >/dev/null 2>&1; then
        echo "Error: zip not available"
        return 1
    fi

    # Create temporary directory
    temp_dir=$(mktemp -d 2>/dev/null || echo "/tmp/sv_export_$$")
    mkdir -p "$temp_dir" 2>/dev/null

    if [ ! -d "$temp_dir" ]; then
        echo "Error: Cannot create temp directory"
        return 1
    fi

    # Find saves for this game
    found=0
    find "$SAVE_DIR" -name "${game}.*" -type f 2>/dev/null | while read -r save; do
        case "$save" in
            *.sav|*.state)
                cp "$save" "$temp_dir/" 2>/dev/null && found=$((found + 1))
                ;;
        esac
    done

    # Find backups
    find "$BACKUP_DIR" -name "${game}_*.sav" 2>/dev/null | while read -r backup; do
        cp "$backup" "$temp_dir/" 2>/dev/null && found=$((found + 1))
    done

    # Check if we have anything to export
    file_count=$(find "$temp_dir" -name "*.sav" -o -name "*.state" 2>/dev/null | wc -l)
    if [ "$file_count" -eq 0 ]; then
        echo "No saves found for $game"
        rm -rf "$temp_dir"
        return 1
    fi

    # Create ZIP
    old_dir=$(pwd)
    cd "$temp_dir" || { rm -rf "$temp_dir"; return 1; }
    if zip -r "$output" . >/dev/null 2>&1; then
        cd "$old_dir"
        log "Exported: $game -> $output ($file_count files)"
        echo "Exported: $output ($file_count files)"
        rm -rf "$temp_dir"
        return 0
    else
        cd "$old_dir"
        echo "Error: Failed to create ZIP"
        rm -rf "$temp_dir"
        return 1
    fi
}

# ── Import saves ────────────────────────────────────────────────────────
import_saves() {
    archive="$1"

    if [ -z "$archive" ]; then
        echo "Usage: save_vault.sh import <archive_file>"
        return 1
    fi

    if ! validate_save "$archive"; then
        echo "Error: Archive not found or empty"
        return 1
    fi

    # Create temporary directory
    temp_dir=$(mktemp -d 2>/dev/null || echo "/tmp/sv_import_$$")
    mkdir -p "$temp_dir" 2>/dev/null

    if [ ! -d "$temp_dir" ]; then
        echo "Error: Cannot create temp directory"
        return 1
    fi

    # Extract archive
    extracted=0
    case "$archive" in
        *.zip)
            if command -v unzip >/dev/null 2>&1; then
                unzip -o "$archive" -d "$temp_dir" >/dev/null 2>&1 && extracted=1
            fi
            ;;
        *.7z|*.7z)
            if command -v 7z >/dev/null 2>&1; then
                7z x "$archive" -o"$temp_dir" >/dev/null 2>&1 && extracted=1
            elif command -v 7zz >/dev/null 2>&1; then
                7zz x "$archive" -o"$temp_dir" >/dev/null 2>&1 && extracted=1
            fi
            ;;
        *.tar.gz|*.tgz)
            if command -v tar >/dev/null 2>&1; then
                tar -xzf "$archive" -C "$temp_dir" 2>/dev/null && extracted=1
            fi
            ;;
        *)
            # Try unzip as fallback
            if command -v unzip >/dev/null 2>&1; then
                unzip -o "$archive" -d "$temp_dir" >/dev/null 2>&1 && extracted=1
            fi
            ;;
    esac

    if [ "$extracted" -eq 0 ]; then
        echo "Error: Cannot extract archive (no tool available or bad archive)"
        rm -rf "$temp_dir"
        return 1
    fi

    # Import saves
    imported=0
    find "$temp_dir" -name "*.sav" -o -name "*.state" 2>/dev/null | while read -r save; do
        [ -f "$save" ] || continue
        game=$(basename "$save" | sed 's/\.[^.]*$//')

        # Find matching save location
        current_save=""
        for ext in sav state; do
            found=$(find "$SAVE_DIR" -name "${game}.${ext}" -type f 2>/dev/null | head -1)
            if [ -n "$found" ] && [ -f "$found" ]; then
                current_save="$found"
                break
            fi
        done

        if [ -n "$current_save" ]; then
            # Backup current save
            backup_save "$current_save" >/dev/null 2>&1

            # Import
            if cp "$save" "$current_save" 2>/dev/null; then
                imported=$((imported + 1))
                echo "Imported: $game"
            fi
        fi
    done

    rm -rf "$temp_dir"

    log "Imported $imported saves from $(basename "$archive")"
    echo ""
    echo "Import complete: $imported saves"
}

# ── Cleanup old backups ────────────────────────────────────────────────
cleanup_backups() {
    days="${1:-30}"

    if ! echo "$days" | grep -q '^[0-9]*$'; then
        echo "Error: days must be a number"
        return 1
    fi

    echo "Cleaning backups older than $days days..."

    removed=0
    find "$BACKUP_DIR" -name "*.sav" -mtime "+${days}" -type f 2>/dev/null | while read -r backup; do
        rm -f "$backup" 2>/dev/null
        echo "  Removed: $(basename "$backup")"
        removed=$((removed + 1))
    done

    log "Cleanup complete (removed backups older than $days days)"
    echo "Cleanup complete"
}

# ── Auto-backup all saves ──────────────────────────────────────────────
auto_backup() {
    echo "Running automatic save backup..."

    backed_up=0
    find "$SAVE_DIR" -name "*.sav" -type f 2>/dev/null | while read -r save; do
        [ -f "$save" ] || continue
        backup_save "$save" >/dev/null 2>&1 && backed_up=$((backed_up + 1))
    done

    log "Auto-backup complete"
    echo "Auto-backup complete"
}

# ── Show vault status ──────────────────────────────────────────────────
show_status() {
    echo "Save Vault Status:"
    echo "=================="
    echo ""

    # Count saves
    sav_count=0
    state_count=0
    if [ -d "$SAVE_DIR" ]; then
        sav_count=$(find "$SAVE_DIR" -name "*.sav" -type f 2>/dev/null | wc -l)
        state_count=$(find "$SAVE_DIR" -name "*.state" -type f 2>/dev/null | wc -l)
    fi
    echo "Saves: $sav_count .sav files, $state_count .state files"

    # Count backups
    backup_count=0
    backup_size=0
    if [ -d "$BACKUP_DIR" ]; then
        backup_count=$(find "$BACKUP_DIR" -name "*.sav" -type f 2>/dev/null | wc -l)
        backup_size=$(du -sh "$BACKUP_DIR" 2>/dev/null | awk '{print $1}')
    fi
    echo "Backups: $backup_count files ($backup_size)"

    # Count history entries
    history_count=0
    if [ -d "$HISTORY_DIR" ]; then
        history_count=$(find "$HISTORY_DIR" -name "*.history" -type f 2>/dev/null | wc -l)
    fi
    echo "History: $history_count games tracked"

    echo ""
    echo "Directories:"
    echo "  Saves:     $SAVE_DIR"
    echo "  Backups:   $BACKUP_DIR"
    echo "  History:   $HISTORY_DIR"
}

# ── Main ───────────────────────────────────────────────────────────────
case "${1:-}" in
    list)
        shift
        list_saves "$@"
        ;;
    backup)
        shift
        backup_save "$@"
        ;;
    restore)
        shift
        restore_save "$@"
        ;;
    history)
        shift
        show_history "$@"
        ;;
    export)
        shift
        export_saves "$@"
        ;;
    import)
        shift
        import_saves "$@"
        ;;
    cleanup)
        shift
        cleanup_backups "$@"
        ;;
    auto-backup)
        auto_backup
        ;;
    status)
        show_status
        ;;
    *)
        echo "JukaMix Save Vault"
        echo "Usage: save_vault.sh <command> [args]"
        echo ""
        echo "Commands:"
        echo "  list [system]           List saves (all or specific system)"
        echo "  backup <save_file>      Backup a save file"
        echo "  restore <game> [backup] Restore a save"
        echo "  history <game>          Show save history"
        echo "  export <game> [output]  Export saves to ZIP"
        echo "  import <archive>        Import saves from ZIP"
        echo "  cleanup [days]          Cleanup old backups (default: 30 days)"
        echo "  auto-backup             Backup all saves"
        echo "  status                  Show vault status"
        ;;
esac
