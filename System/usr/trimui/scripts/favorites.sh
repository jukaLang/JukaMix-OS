#!/bin/sh
# System/usr/trimui/scripts/favorites.sh
# Favorites system - mark and list favorite games

# ── Safeguards ────────────────────────────────────────────────────────
# Ensure required directories exist
mkdir -p /tmp 2>/dev/null
mkdir -p /mnt/SDCARD/trimui 2>/dev/null

FAVORITES_DIR="/mnt/SDCARD/trimui/favorites"
LOG_FILE="/tmp/favorites.log"

# Create favorites directory
mkdir -p "$FAVORITES_DIR" 2>/dev/null

# ── Logging ───────────────────────────────────────────────────────────
log() {
    echo "$(date '+%H:%M:%S') [favorites] $1" >> "$LOG_FILE" 2>/dev/null
}

# ── Add game to favorites ──────────────────────────────────────────────
add_favorite() {
    local game_path="$1"
    local game_name=$(basename "$game_path")
    local game_id=$(echo "$game_name" | md5sum 2>/dev/null | cut -d' ' -f1)
    
    if [ -z "$game_id" ]; then
        # Fallback if md5sum not available
        game_id=$(echo "$game_name" | wc -c)
    fi
    
    local fav_file="$FAVORITES_DIR/${game_id}.fav"
    
    if [ -f "$fav_file" ]; then
        echo "Already in favorites: $game_name"
        return 0
    fi
    
    # Save game info
    cat > "$fav_file" << EOF
path=$game_path
name=$game_name
added=$(date +%s)
EOF
    
    log "Added: $game_name"
    echo "Added to favorites: $game_name"
    return 0
}

# ── Remove game from favorites ─────────────────────────────────────────
remove_favorite() {
    local game_path="$1"
    local game_name=$(basename "$game_path")
    local game_id=$(echo "$game_name" | md5sum 2>/dev/null | cut -d' ' -f1)
    
    if [ -z "$game_id" ]; then
        game_id=$(echo "$game_name" | wc -c)
    fi
    
    local fav_file="$FAVORITES_DIR/${game_id}.fav"
    
    if [ ! -f "$fav_file" ]; then
        echo "Not in favorites: $game_name"
        return 1
    fi
    
    rm -f "$fav_file"
    log "Removed: $game_name"
    echo "Removed from favorites: $game_name"
    return 0
}

# ── Toggle favorite status ─────────────────────────────────────────────
toggle_favorite() {
    local game_path="$1"
    local game_name=$(basename "$game_path")
    local game_id=$(echo "$game_name" | md5sum 2>/dev/null | cut -d' ' -f1)
    
    if [ -z "$game_id" ]; then
        game_id=$(echo "$game_name" | wc -c)
    fi
    
    local fav_file="$FAVORITES_DIR/${game_id}.fav"
    
    if [ -f "$fav_file" ]; then
        remove_favorite "$game_path"
    else
        add_favorite "$game_path"
    fi
}

# ── Check if game is favorite ──────────────────────────────────────────
is_favorite() {
    local game_path="$1"
    local game_name=$(basename "$game_path")
    local game_id=$(echo "$game_name" | md5sum 2>/dev/null | cut -d' ' -f1)
    
    if [ -z "$game_id" ]; then
        game_id=$(echo "$game_name" | wc -c)
    fi
    
    local fav_file="$FAVORITES_DIR/${game_id}.fav"
    
    [ -f "$fav_file" ]
}

# ── List all favorites ─────────────────────────────────────────────────
list_favorites() {
    local count=0
    
    for fav_file in "$FAVORITES_DIR"/*.fav; do
        [ -f "$fav_file" ] || continue
        
        local name=$(grep "^name=" "$fav_file" | cut -d= -f2-)
        local path=$(grep "^path=" "$fav_file" | cut -d= -f2-)
        local added=$(grep "^added=" "$fav_file" | cut -d= -f2-)
        
        if [ -n "$name" ]; then
            echo "$name"
            count=$((count + 1))
        fi
    done
    
    echo ""
    echo "Total favorites: $count"
}

# ── Export favorites ───────────────────────────────────────────────────
export_favorites() {
    local export_file="${1:-/mnt/SDCARD/favorites_export.txt}"
    
    echo "# JukaMix OS Favorites Export" > "$export_file"
    echo "# Date: $(date)" >> "$export_file"
    echo "" >> "$export_file"
    
    for fav_file in "$FAVORITES_DIR"/*.fav; do
        [ -f "$fav_file" ] || continue
        cat "$fav_file" >> "$export_file"
        echo "" >> "$export_file"
    done
    
    echo "Favorites exported to: $export_file"
}

# ── Import favorites ───────────────────────────────────────────────────
import_favorites() {
    local import_file="$1"
    
    if [ ! -f "$import_file" ]; then
        echo "File not found: $import_file"
        return 1
    fi
    
    # Parse import file
    local count=0
    while IFS= read -r line; do
        case "$line" in
            path=*) 
                local path="${line#path=}"
                if [ -f "$path" ]; then
                    add_favorite "$path"
                    count=$((count + 1))
                fi
                ;;
        esac
    done < "$import_file"
    
    echo "Imported $count favorites"
}

# ── Main ──────────────────────────────────────────────────────────────
case "${1:-}" in
    add)
        add_favorite "$2"
        ;;
    remove)
        remove_favorite "$2"
        ;;
    toggle)
        toggle_favorite "$2"
        ;;
    check)
        is_favorite "$2" && echo "Yes" || echo "No"
        ;;
    list)
        list_favorites
        ;;
    export)
        export_favorites "$2"
        ;;
    import)
        import_favorites "$2"
        ;;
    count)
        ls "$FAVORITES_DIR"/*.fav 2>/dev/null | wc -l
        ;;
    *)
        echo "Usage: favorites.sh {add|remove|toggle|check|list|export|import|count} [game_path]" >&2
        echo "" >&2
        echo "Commands:" >&2
        echo "  add <path>     - Add game to favorites" >&2
        echo "  remove <path>  - Remove game from favorites" >&2
        echo "  toggle <path>  - Toggle favorite status" >&2
        echo "  check <path>   - Check if game is favorite" >&2
        echo "  list           - List all favorites" >&2
        echo "  export [file]  - Export favorites to file" >&2
        echo "  import <file>  - Import favorites from file" >&2
        echo "  count          - Count total favorites" >&2
        exit 1
        ;;
esac
