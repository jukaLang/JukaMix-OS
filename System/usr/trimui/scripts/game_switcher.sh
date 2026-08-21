#!/bin/sh
# System/usr/trimui/scripts/game_switcher.sh
# Game Switcher - quickly switch between recent games

SCRIPTS_DIR="/mnt/SDCARD/System/usr/trimui/scripts"
SWITCHER_DIR="/mnt/SDCARD/trimui/game_switcher"
MAX_RECENT=10

# Create switcher directory
mkdir -p "$SWITCHER_DIR"

# ── Add game to recent list ───────────────────────────────────────────
add_recent() {
    local game_path="$1"
    local emulator="$2"
    local timestamp=$(date +%s)
    local game_name=$(basename "$game_path")
    
    # Create entry file
    local entry_file="$SWITCHER_DIR/${timestamp}_${game_name}.txt"
    cat > "$entry_file" << EOF
path=$game_path
emulator=$emulator
name=$game_name
timestamp=$timestamp
EOF
    
    # Trim old entries
    local count=$(ls -1 "$SWITCHER_DIR"/*.txt 2>/dev/null | wc -l)
    if [ "$count" -gt "$MAX_RECENT" ]; then
        ls -1t "$SWITCHER_DIR"/*.txt | tail -n +$((MAX_RECENT + 1)) | xargs rm -f
    fi
    
    sync
}

# ── Get recent games list ─────────────────────────────────────────────
get_recent() {
    ls -1t "$SWITCHER_DIR"/*.txt 2>/dev/null | head -n "$MAX_RECENT"
}

# ── Launch game from switcher ─────────────────────────────────────────
launch_game() {
    local entry_file="$1"
    
    if [ ! -f "$entry_file" ]; then
        echo "Invalid entry: $entry_file" >&2
        return 1
    fi
    
    local game_path=$(grep "^path=" "$entry_file" | cut -d= -f2-)
    local emulator=$(grep "^emulator=" "$entry_file" | cut -d= -f2-)
    
    if [ -z "$game_path" ] || [ ! -f "$game_path" ]; then
        echo "Game not found: $game_path" >&2
        return 1
    fi
    
    echo "Launching: $game_path via $emulator" >&2
    
    # Determine emulator directory and launch script
    case "$emulator" in
        retroarch|ra)
            # RetroArch - find the appropriate core
            local ext="${game_path##*.}"
            case "$ext" in
                smc|sfc|fig)  "$SCRIPTS_DIR/../../Emus/SNES/launch.sh" "$game_path" ;;
                gb|gbc)       "$SCRIPTS_DIR/../../Emus/GBC/launch.sh" "$game_path" ;;
                gba)          "$SCRIPTS_DIR/../../Emus/GBA/launch.sh" "$game_path" ;;
                nes)          "$SCRIPTS_DIR/../../Emus/NES/launch.sh" "$game_path" ;;
                *)            "$SCRIPTS_DIR/../../Emus/GenericRetroArch/launch.sh" "$game_path" ;;
            esac
            ;;
        ppsspp)
            "$SCRIPTS_DIR/../../Emus/PSP/launch.sh" "$game_path"
            ;;
        drastic)
            "$SCRIPTS_DIR/../../Emus/NDS/launch.sh" "$game_path"
            ;;
        *)
            echo "Unknown emulator: $emulator" >&2
            return 1
            ;;
    esac
}

# ── Show switcher menu ────────────────────────────────────────────────
show_menu() {
    local recent=$(get_recent)
    
    if [ -z "$recent" ]; then
        echo "No recent games" >&2
        return 1
    fi
    
    # Build menu options
    local options=""
    local entries=""
    local i=1
    
    for entry in $recent; do
        local name=$(grep "^name=" "$entry" | cut -d= -f2-)
        local emulator=$(grep "^emulator=" "$entry" | cut -d= -f2-)
        options="${options}${i}. ${name} (${emulator})\n"
        entries="${entries}${entry}\n"
        i=$((i + 1))
    done
    
    # Show selector
    local selected=$(echo -e "$options" | selector -t "Select a game to resume:" -fs 160)
    
    if [ -n "$selected" ]; then
        # Extract entry number
        local num=$(echo "$selected" | cut -d. -f1)
        local entry=$(echo -e "$entries" | sed -n "${num}p")
        
        if [ -n "$entry" ]; then
            launch_game "$entry"
        fi
    fi
}

# ── Main ──────────────────────────────────────────────────────────────
case "${1:-}" in
    add)
        add_recent "$2" "${3:-retroarch}"
        ;;
    show|menu)
        show_menu
        ;;
    list)
        get_recent
        ;;
    *)
        echo "Usage: game_switcher.sh {add|show|list} [game_path] [emulator]" >&2
        echo "  add <path> [emulator]  - Add game to recent list" >&2
        echo "  show                   - Show switcher menu" >&2
        echo "  list                   - List recent games" >&2
        exit 1
        ;;
esac
