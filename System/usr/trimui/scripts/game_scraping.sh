#!/bin/sh
# game_scraping.sh - Game Scraping System for JukaMix
# Downloads metadata, artwork, and screenshots for ROMs

ROMS_DIR="/mnt/SDCARD/Roms"
IMAGES_DIR="/mnt/SDCARD/Imgs"
METADATA_DIR="/mnt/SDCARD/trimui/metadata"
LOG_FILE="/tmp/game_scraping.log"
API_URL="https://www.screenscraper.fr/api"

# Create directories
mkdir -p "$IMAGES_DIR" "$METADATA_DIR" 2>/dev/null

# ── Logging ────────────────────────────────────────────────────────────
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [scrape] $1" >> "$LOG_FILE" 2>/dev/null
}

# ── Get system name from path ──────────────────────────────────────────
get_system_from_path() {
    path="$1"
    
    # Extract system name from ROM path
    case "$path" in
        *NES*|*nes*) echo "nes" ;;
        *SNES*|*snes*) echo "snes" ;;
        *GB*|*gb*) echo "gb" ;;
        *GBC*|*gbc*) echo "gbc" ;;
        *GBA*|*gba*) echo "gba" ;;
        *GENESIS*|*genesis*|*MEGA*|*mega*) echo "genesis" ;;
        *PSX*|*psx*|*PS1*|*ps1*) echo "psx" ;;
        *N64*|*n64*) echo "n64" ;;
        *PSP*|*psp*) echo "psp" ;;
        *NDS*|*nds*) echo "nds" ;;
        *ARCADE*|*arcade*|*FBNeo*|*fbneo*) echo "arcade" ;;
        *) echo "unknown" ;;
    esac
}

# ── Get game name from filename ────────────────────────────────────────
get_game_name() {
    filename="$1"
    
    # Remove extension and clean up name
    name=$(basename "$filename" | sed 's/\.[^.]*$//')
    
    # Replace underscores and dashes with spaces
    name=$(echo "$name" | sed 's/_/ /g; s/-/ /g')
    
    # Remove region tags
    name=$(echo "$name" | sed 's/(USA)//g; s/(Europe)//g; s/(Japan)//g; s/(World)//g')
    name=$(echo "$name" | sed 's/\[U\]//g; s/\[E\]//g; s/\[J\]//g; s/\[W\]//g')
    
    # Remove version tags
    name=$(echo "$name" | sed 's/v[0-9.]*//g')
    
    # Trim whitespace
    name=$(echo "$name" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
    
    echo "$name"
}

# ── Calculate ROM hash ────────────────────────────────────────────────
calculate_hash() {
    rom_file="$1"
    
    if command -v md5sum >/dev/null 2>&1; then
        md5sum "$rom_file" 2>/dev/null | cut -d' ' -f1
    elif command -v md5 >/dev/null 2>&1; then
        md5 -q "$rom_file" 2>/dev/null
    else
        # Fallback to filename hash
        echo "$rom_file" | cksum | cut -d' ' -f1
    fi
}

# ── Search for game metadata ──────────────────────────────────────────
search_game() {
    game_name="$1"
    system="$2"
    
    # URL encode the game name
    encoded_name=$(echo "$game_name" | sed 's/ /%20/g; s/&/%26/g')
    
    # Try to search using API
    if command -v curl >/dev/null 2>&1; then
        result=$(curl -sS "$API_URL/jeuRecherche.php?recherche=$encoded_name&systeme=$system" 2>/dev/null)
        echo "$result"
    elif command -v wget >/dev/null 2>&1; then
        result=$(wget -q -O - "$API_URL/jeuRecherche.php?recherche=$encoded_name&systeme=$system" 2>/dev/null)
        echo "$result"
    fi
}

# ── Download artwork ──────────────────────────────────────────────────
download_artwork() {
    game_name="$1"
    system="$2"
    game_id="$3"
    
    # Create system image directory
    system_img_dir="$IMAGES_DIR/$system"
    mkdir -p "$system_img_dir" 2>/dev/null
    
    # Image types to download
    for img_type in "box2d" "screen" "wheel" "fanart"; do
        url="$API_URL/media.php?media=$img_type&gameId=$game_id"
        output="$system_img_dir/${game_name}_${img_type}.png"
        
        if [ ! -f "$output" ]; then
            if command -v curl >/dev/null 2>&1; then
                curl -sS -L --fail -o "$output" "$url" 2>/dev/null
            elif command -v wget >/dev/null 2>&1; then
                wget -q -O "$output" "$url" 2>/dev/null
            fi
            
            if [ -f "$output" ]; then
                log "Downloaded: $img_type for $game_name"
            fi
        fi
    done
}

# ── Save metadata ──────────────────────────────────────────────────────
save_metadata() {
    game_name="$1"
    system="$2"
    game_id="$3"
    metadata="$4"
    
    metadata_file="$METADATA_DIR/${system}_${game_name}.json"
    
    echo "$metadata" > "$metadata_file" 2>/dev/null
    
    log "Saved metadata for: $game_name"
}

# ── Scrape single game ────────────────────────────────────────────────
scrape_game() {
    rom_file="$1"
    
    game_name=$(get_game_name "$rom_file")
    system=$(get_system_from_path "$rom_file")
    
    echo "Scraping: $game_name ($system)"
    
    # Search for game
    search_result=$(search_game "$game_name" "$system")
    
    if [ -n "$search_result" ]; then
        # Extract game ID from search result
        game_id=$(echo "$search_result" | grep -o '"id":"[0-9]*"' | head -1 | cut -d'"' -f4)
        
        if [ -n "$game_id" ]; then
            # Download artwork
            download_artwork "$game_name" "$system" "$game_id"
            
            # Save metadata
            save_metadata "$game_name" "$system" "$game_id" "$search_result"
            
            echo "  [OK] $game_name"
            return 0
        fi
    fi
    
    echo "  [SKIP] $game_name (not found)"
    return 1
}

# ── Scrape system ──────────────────────────────────────────────────────
scrape_system() {
    system_dir="$1"
    
    system=$(basename "$system_dir")
    echo "Scraping system: $system"
    
    scraped=0
    skipped=0
    
    find "$system_dir" -type f \( -name "*.zip" -o -name "*.rom" -o -name "*.bin" -o -name "*.iso" -o -name "*.cue" -o -name "*.gba" -o -name "*.nes" -o -name "*.sfc" -o -name "*.smc" -o -name "*.gen" -o -name "*.md" -o -name "*.psp" -o -name "*.nds" -o -name "*.n64" \) 2>/dev/null | while read -r rom; do
        if scrape_game "$rom"; then
            scraped=$((scraped + 1))
        else
            skipped=$((skipped + 1))
        fi
        
        # Rate limiting
        sleep 1
    done
    
    echo ""
    echo "System: $system"
    echo "Scraped: $scraped"
    echo "Skipped: $skipped"
}

# ── Scrape all systems ────────────────────────────────────────────────
scrape_all() {
    echo "Scraping all systems..."
    echo ""
    
    total_scraped=0
    total_skipped=0
    
    for system_dir in "$ROMS_DIR"/*/; do
        [ -d "$system_dir" ] || continue
        
        system=$(basename "$system_dir")
        echo "Processing: $system"
        
        # Scrape this system
        scraped=0
        skipped=0
        
        find "$system_dir" -type f \( -name "*.zip" -o -name "*.rom" -o -name "*.bin" -o -name "*.iso" -o -name "*.cue" -o -name "*.gba" -o -name "*.nes" -o -name "*.sfc" -o -name "*.smc" -o -name "*.gen" -o -name "*.md" -o -name "*.psp" -o -name "*.nds" -o -name "*.n64" \) 2>/dev/null | while read -r rom; do
            if scrape_game "$rom"; then
                scraped=$((scraped + 1))
            else
                skipped=$((skipped + 1))
            fi
            
            # Rate limiting
            sleep 1
        done
        
        total_scraped=$((total_scraped + scraped))
        total_skipped=$((total_skipped + skipped))
        
        echo "  $system: $scraped scraped, $skipped skipped"
    done
    
    echo ""
    echo "Total Scraped: $total_scraped"
    echo "Total Skipped: $total_skipped"
    
    log "Scraping complete: $total_scraped scraped, $total_skipped skipped"
}

# ── Generate game list ────────────────────────────────────────────────
generate_game_list() {
    system="${1:-all}"
    
    echo "Generating game list..."
    
    game_list="$METADATA_DIR/game_list.txt"
    > "$game_list" 2>/dev/null
    
    if [ "$system" = "all" ]; then
        roms_dir="$ROMS_DIR"
    else
        roms_dir="$ROMS_DIR/$system"
    fi
    
    find "$roms_dir" -type f \( -name "*.zip" -o -name "*.rom" -o -name "*.bin" -o -name "*.iso" -o -name "*.cue" -o -name "*.gba" -o -name "*.nes" -o -name "*.sfc" -o -name "*.smc" -o -name "*.gen" -o -name "*.md" -o -name "*.psp" -o -name "*.nds" -o -name "*.n64" \) 2>/dev/null | while read -r rom; do
        game_name=$(get_game_name "$rom")
        game_system=$(get_system_from_path "$rom")
        
        echo "$game_name|$game_system|$rom" >> "$game_list"
    done
    
    # Sort and count
    sort -u "$game_list" -o "$game_list"
    count=$(wc -l < "$game_list" 2>/dev/null || echo "0")
    
    echo "Generated game list with $count games"
    log "Generated game list: $count games"
}

# ── Show scraping status ──────────────────────────────────────────────
show_status() {
    echo "Scraping Status:"
    echo "================"
    echo ""
    
    # Count scraped games
    total_images=$(find "$IMAGES_DIR" -name "*.png" 2>/dev/null | wc -l)
    total_metadata=$(find "$METADATA_DIR" -name "*.json" 2>/dev/null | wc -l)
    
    echo "Artwork: $total_images images"
    echo "Metadata: $total_metadata entries"
    echo ""
    
    # Show per-system status
    for system_dir in "$ROMS_DIR"/*/; do
        [ -d "$system_dir" ] || continue
        
        system=$(basename "$system_dir")
        rom_count=$(find "$system_dir" -type f \( -name "*.zip" -o -name "*.rom" -o -name "*.bin" \) 2>/dev/null | wc -l)
        img_count=$(find "$IMAGES_DIR/$system" -name "*.png" 2>/dev/null | wc -l)
        
        echo "  $system: $rom_count ROMs, $img_count images"
    done
}

# ── Main ───────────────────────────────────────────────────────────────
case "${1:-}" in
    game)
        scrape_game "${2:-}"
        ;;
    system)
        scrape_system "${2:-$ROMS_DIR/NES}"
        ;;
    all)
        scrape_all
        ;;
    list)
        generate_game_list "${2:-all}"
        ;;
    status)
        show_status
        ;;
    *)
        echo "Game Scraping System"
        echo "Usage: game_scraping.sh {game|system|all|list|status}"
        echo ""
        echo "Commands:"
        echo "  game <rom>        - Scrape single game"
        echo "  system <dir>      - Scrape entire system"
        echo "  all               - Scrape all systems"
        echo "  list [system]     - Generate game list"
        echo "  status            - Show scraping status"
        ;;
esac
