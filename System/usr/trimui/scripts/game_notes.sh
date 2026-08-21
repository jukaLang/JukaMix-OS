#!/bin/sh
# System/usr/trimui/scripts/game_notes.sh
# Game Notes - Add notes to games

NOTES_DIR="/mnt/SDCARD/trimui/game_notes"
LOG_FILE="/tmp/game_notes.log"

# Create notes directory
mkdir -p "$NOTES_DIR"

# Logging
log() {
    echo "$(date '+%H:%M:%S') [notes] $1" >> "$LOG_FILE"
}

# ── Get game ID ────────────────────────────────────────────────────────
get_game_id() {
    local game_path="$1"
    local game_name=$(basename "$game_path")
    local game_id=$(echo "$game_name" | md5sum 2>/dev/null | cut -d' ' -f1)
    
    if [ -z "$game_id" ]; then
        game_id=$(echo "$game_name" | wc -c)
    fi
    
    echo "$game_id"
}

# ── Add note ───────────────────────────────────────────────────────────
add_note() {
    local game_path="$1"
    local note="$2"
    local game_id=$(get_game_id "$game_path")
    local game_name=$(basename "$game_path")
    local notes_file="$NOTES_DIR/${game_id}.notes"
    
    # Add note with timestamp
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $note" >> "$notes_file"
    
    log "Added note for: $game_name"
    echo "Note added for: $game_name"
}

# ── View notes ─────────────────────────────────────────────────────────
view_notes() {
    local game_path="$1"
    local game_id=$(get_game_id "$game_path")
    local game_name=$(basename "$game_path")
    local notes_file="$NOTES_DIR/${game_id}.notes"
    
    echo "Notes for: $game_name"
    echo "===================="
    echo ""
    
    if [ ! -f "$notes_file" ]; then
        echo "No notes yet"
        return
    fi
    
    cat "$notes_file"
}

# ── Clear notes ────────────────────────────────────────────────────────
clear_notes() {
    local game_path="$1"
    local game_id=$(get_game_id "$game_path")
    local game_name=$(basename "$game_path")
    local notes_file="$NOTES_DIR/${game_id}.notes"
    
    if [ ! -f "$notes_file" ]; then
        echo "No notes to clear"
        return
    fi
    
    # Auto-clear without confirmation (no keyboard on device)
    rm -f "$notes_file"
    log "Cleared notes for: $game_name"
    echo "Notes cleared for: $game_name"
}

# ── List games with notes ──────────────────────────────────────────────
list_notes() {
    echo "Games with notes:"
    echo ""
    
    local count=0
    
    for notes_file in "$NOTES_DIR"/*.notes; do
        [ -f "$notes_file" ] || continue
        
        local game_id=$(basename "$notes_file" .notes)
        local note_count=$(wc -l < "$notes_file")
        local last_note=$(tail -1 "$notes_file" | sed 's/^\[.*\] //')
        
        echo "  Game ID: $game_id"
        echo "  Notes: $note_count"
        echo "  Last: $last_note"
        echo ""
        
        count=$((count + 1))
    done
    
    if [ "$count" -eq 0 ]; then
        echo "  No notes found"
    else
        echo "Total: $count games with notes"
    fi
}

# ── Export notes ────────────────────────────────────────────────────────
export_notes() {
    local export_file="${1:-/mnt/SDCARD/game_notes_export.txt}"
    
    echo "# JukaMix Game Notes Export" > "$export_file"
    echo "# Date: $(date)" >> "$export_file"
    echo "" >> "$export_file"
    
    for notes_file in "$NOTES_DIR"/*.notes; do
        [ -f "$notes_file" ] || continue
        
        local game_id=$(basename "$notes_file" .notes)
        echo "=== Game: $game_id ===" >> "$export_file"
        cat "$notes_file" >> "$export_file"
        echo "" >> "$export_file"
    done
    
    echo "Notes exported to: $export_file"
}

# ── Main ──────────────────────────────────────────────────────────────
case "${1:-}" in
    add)
        add_note "$2" "$3"
        ;;
    view)
        view_notes "$2"
        ;;
    clear)
        clear_notes "$2"
        ;;
    list)
        list_notes
        ;;
    export)
        export_notes "$2"
        ;;
    *)
        echo "Game Notes"
        echo "=========="
        echo ""
        echo "Usage: game_notes.sh {command} [args]" >&2
        echo "" >&2
        echo "Commands:" >&2
        echo "  add <game> <note>   - Add note to game" >&2
        echo "  view <game>         - View notes for game" >&2
        echo "  clear <game>        - Clear notes for game" >&2
        echo "  list                - List all games with notes" >&2
        echo "  export [file]       - Export all notes" >&2
        exit 1
        ;;
esac
