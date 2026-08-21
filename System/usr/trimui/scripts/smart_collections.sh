#!/bin/sh
# smart_collections.sh - Smart Collections Generator
# Creates dynamic game categories based on play history and metadata
#
# Usage: smart_collections.sh [command]

ROMS_DIR="/mnt/SDCARD/Roms"
COLLECTIONS_DIR="/mnt/SDCARD/trimui/collections"
HISTORY_FILE="/mnt/SDCARD/trimui/play_history.csv"
FAVORITES_FILE="/mnt/SDCARD/trimui/favorites.txt"
LOG_FILE="/tmp/smart_collections.log"

# Create directories
mkdir -p "$COLLECTIONS_DIR" 2>/dev/null

# ── Logging ────────────────────────────────────────────────────────────
log() {
    echo "$(date '+%H:%M:%S') [collections] $1" >> "$LOG_FILE" 2>/dev/null
}

# ── Get game info ──────────────────────────────────────────────────────
get_game_system() {
    rom_path="$1"
    # Extract system from path: /mnt/SDCARD/Roms/SYSTEM/game.rom
    echo "$rom_path" | sed 's|.*/Roms/||; s|/.*||'
}

get_game_name() {
    rom_path="$1"
    basename "$rom_path" | sed 's/\.[^.]*$//'
}

# ── Recently played ────────────────────────────────────────────────────
generate_recently_played() {
    output="$COLLECTIONS_DIR/recently_played.collection"
    
    echo "# Recently Played Games" > "$output"
    echo "# Generated: $(date)" >> "$output"
    echo "" >> "$output"
    
    # Get last 20 played games from history
    if [ -f "$HISTORY_FILE" ]; then
        tail -20 "$HISTORY_FILE" | sort -t'|' -k2 -r | while IFS='|' read -r timestamp game system; do
            if [ -f "$ROMS_DIR/$system/$game" ]; then
                echo "$ROMS_DIR/$system/$game" >> "$output"
            fi
        done
    fi
    
    log "Generated recently_played collection"
    echo "Created: recently_played.collection"
}

# ── Never played ───────────────────────────────────────────────────────
generate_never_played() {
    output="$COLLECTIONS_DIR/never_played.collection"
    
    echo "# Never Played Games" > "$output"
    echo "# Generated: $(date)" >> "$output"
    echo "" >> "$output"
    
    # Find games not in history
    find "$ROMS_DIR" -type f \( -name "*.nes" -o -name "*.sfc" -o -name "*.smc" -o \
        -name "*.gb" -o -name "*.gbc" -o -name "*.gba" -o -name "*.gen" -o \
        -name "*.md" -o -name "*.psx" -o -name "*.iso" -o -name "*.bin" \) 2>/dev/null | \
    while read -r rom; do
        game=$(get_game_name "$rom")
        system=$(get_game_system "$rom")
        
        # Check if game was played
        if [ -f "$HISTORY_FILE" ] && grep -q "$game" "$HISTORY_FILE" 2>/dev/null; then
            continue
        fi
        
        echo "$rom" >> "$output"
    done | head -50  # Limit to 50 games
    
    log "Generated never_played collection"
    echo "Created: never_played.collection"
}

# ── Favorites ──────────────────────────────────────────────────────────
generate_favorites() {
    output="$COLLECTIONS_DIR/favorites.collection"
    
    echo "# Favorite Games" > "$output"
    echo "# Generated: $(date)" >> "$output"
    echo "" >> "$output"
    
    if [ -f "$FAVORITES_FILE" ]; then
        while IFS= read -r game; do
            # Find the game file
            find "$ROMS_DIR" -name "$game" -type f 2>/dev/null | head -1
        done < "$FAVORITES_FILE" >> "$output"
    fi
    
    log "Generated favorites collection"
    echo "Created: favorites.collection"
}

# ── Short games (under 30 min) ────────────────────────────────────────
generate_short_games() {
    output="$COLLECTIONS_DIR/short_games.collection"
    
    echo "# Short Games (Under 30 Minutes)" > "$output"
    echo "# Generated: $(date)" >> "$output"
    echo "" >> "$output"
    
    # These systems typically have shorter games
    short_systems="GB GBC NES SMS GG"
    
    for system in $short_systems; do
        if [ -d "$ROMS_DIR/$system" ]; then
            find "$ROMS_DIR/$system" -type f \( -name "*.nes" -o -name "*.gb" -o -name "*.gbc" -o -name "*.sms" -o -name "*.gg" \) 2>/dev/null
        fi
    done >> "$output"
    
    log "Generated short_games collection"
    echo "Created: short_games.collection"
}

# ── Multiplayer games ──────────────────────────────────────────────────
generate_multiplayer() {
    output="$COLLECTIONS_DIR/multiplayer.collection"
    
    echo "# Multiplayer Games" > "$output"
    echo "# Generated: $(date)" >> "$output"
    echo "" >> "$output"
    
    # Common multiplayer systems
    mp_systems="NES SNES GBA GEN MD"
    
    for system in $mp_systems; do
        if [ -d "$ROMS_DIR/$system" ]; then
            # Look for common multiplayer patterns in filenames
            find "$ROMS_DIR/$system" -type f \( -iname "*2p*" -o -iname "*multi*" -o \
                -iname "*party*" -o -iname "*battle*" -o -iname "*vs*" \) 2>/dev/null
        fi
    done >> "$output"
    
    log "Generated multiplayer collection"
    echo "Created: multiplayer.collection"
}

# ── Homebrew games ─────────────────────────────────────────────────────
generate_homebrew() {
    output="$COLLECTIONS_DIR/homebrew.collection"
    
    echo "# Homebrew Games" > "$output"
    echo "# Generated: $(date)" >> "$output"
    echo "" >> "$output"
    
    # Common homebrew directories
    for system_dir in "$ROMS_DIR"/*/; do
        [ -d "$system_dir" ] || continue
        
        # Look for homebrew directories
        find "$system_dir" -type d \( -iname "*homebrew*" -o -iname "*hb*" -o -iname "*indie*" \) 2>/dev/null | \
        while read -r hb_dir; do
            find "$hb_dir" -type f \( -name "*.nes" -o -name "*.sfc" -o -name "*.gba" -o -name "*.gen" \) 2>/dev/null
        done
    done >> "$output"
    
    log "Generated homebrew collection"
    echo "Created: homebrew.collection"
}

# ── Works perfectly (from compatibility DB) ────────────────────────────
generate_perfect_games() {
    output="$COLLECTIONS_DIR/works_perfectly.collection"
    
    echo "# Works Perfectly Games" > "$output"
    echo "# Generated: $(date)" >> "$output"
    echo "" >> "$output"
    
    # Read from compatibility database
    compat_db="/mnt/SDCARD/System/usr/trimui/compatibility-db.txt"
    if [ -f "$compat_db" ]; then
        grep "perfect" "$compat_db" 2>/dev/null | cut -d'|' -f1 | while read -r game; do
            find "$ROMS_DIR" -name "$game" -type f 2>/dev/null | head -1
        done >> "$output"
    fi
    
    log "Generated works_perfectly collection"
    echo "Created: works_perfectly.collection"
}

# ── Random game ────────────────────────────────────────────────────────
generate_random_game() {
    output="$COLLECTIONS_DIR/random_game.collection"
    
    echo "# Random Game" > "$output"
    echo "# Generated: $(date)" >> "$output"
    echo "# Select one game at random each time this is opened" >> "$output"
    echo "" >> "$output"
    
    # Get all games
    find "$ROMS_DIR" -type f \( -name "*.nes" -o -name "*.sfc" -o -name "*.smc" -o \
        -name "*.gb" -o -name "*.gbc" -o -name "*.gba" -o -name "*.gen" -o \
        -name "*.md" -o -name "*.psx" -o -name "*.iso" -o -name "*.bin" \) 2>/dev/null | \
    shuf -n 1 >> "$output"
    
    log "Generated random_game collection"
    echo "Created: random_game.collection"
}

# ── Device optimized ───────────────────────────────────────────────────
generate_device_optimized() {
    output="$COLLECTIONS_DIR/device_optimized.collection"
    
    echo "# Device Optimized Games" > "$output"
    echo "# Generated: $(date)" >> "$output"
    echo "" >> "$output"
    
    device=$(cat /etc/trimui_device.txt 2>/dev/null || echo "tsp")
    
    # Read from compatibility database for this device
    compat_db="/mnt/SDCARD/System/usr/trimui/compatibility-db.txt"
    if [ -f "$compat_db" ]; then
        grep "$device" "$compat_db" 2>/dev/null | grep "perfect\|good" | cut -d'|' -f1 | while read -r game; do
            find "$ROMS_DIR" -name "$game" -type f 2>/dev/null | head -1
        done >> "$output"
    fi
    
    log "Generated device_optimized collection for $device"
    echo "Created: device_optimized.collection"
}

# ── Generate all collections ───────────────────────────────────────────
generate_all() {
    echo "Generating smart collections..."
    
    generate_recently_played
    generate_never_played
    generate_favorites
    generate_short_games
    generate_multiplayer
    generate_homebrew
    generate_perfect_games
    generate_random_game
    generate_device_optimized
    
    echo ""
    echo "All collections generated in: $COLLECTIONS_DIR"
}

# ── List collections ───────────────────────────────────────────────────
list_collections() {
    echo "Available Smart Collections:"
    echo ""
    
    for collection in "$COLLECTIONS_DIR"/*.collection; do
        [ -f "$collection" ] || continue
        name=$(basename "$collection" .collection)
        count=$(grep -v "^#" "$collection" | grep -v "^$" | wc -l)
        echo "  $name ($count games)"
    done
}

# ── Usage ──────────────────────────────────────────────────────────────
usage() {
    echo "Usage: smart_collections.sh [command]"
    echo ""
    echo "Commands:"
    echo "  generate          Generate all smart collections"
    echo "  list              List available collections"
    echo "  <collection>      Generate specific collection"
    echo ""
    echo "Collections:"
    echo "  recently_played   Last 20 played games"
    echo "  never_played      Games never played"
    echo "  favorites         Favorited games"
    echo "  short_games       Games under 30 minutes"
    echo "  multiplayer       Multiplayer games"
    echo "  homebrew          Homebrew games"
    echo "  works_perfectly   Games rated as perfect"
    echo "  random_game       One random game"
    echo "  device_optimized  Optimized for your device"
}

# ── Main ───────────────────────────────────────────────────────────────
if [ $# -eq 0 ]; then
    usage
    exit 0
fi

command="$1"

case "$command" in
    generate)
        generate_all
        ;;
    list)
        list_collections
        ;;
    recently_played)
        generate_recently_played
        ;;
    never_played)
        generate_never_played
        ;;
    favorites)
        generate_favorites
        ;;
    short_games)
        generate_short_games
        ;;
    multiplayer)
        generate_multiplayer
        ;;
    homebrew)
        generate_homebrew
        ;;
    works_perfectly)
        generate_perfect_games
        ;;
    random_game)
        generate_random_game
        ;;
    device_optimized)
        generate_device_optimized
        ;;
    *)
        echo "Unknown command: $command"
        usage
        exit 1
        ;;
esac
