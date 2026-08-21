#!/bin/sh
# System/usr/trimui/scripts/autoresume.sh
# Autoresume - restore last game session on boot

# ── Safeguards ────────────────────────────────────────────────────────
# Ensure required directories exist
mkdir -p /tmp 2>/dev/null
mkdir -p /mnt/SDCARD/trimui 2>/dev/null

SCRIPTS_DIR="/mnt/SDCARD/System/usr/trimui/scripts"
RESUME_DIR="/mnt/SDCARD/trimui/autosave"
SESSION_FILE="$RESUME_DIR/last_session.txt"
LOG_FILE="/tmp/autoresume.log"

# Create resume directory
mkdir -p "$RESUME_DIR" 2>/dev/null

# ── Logging ───────────────────────────────────────────────────────────
log() {
    echo "$(date '+%H:%M:%S') [autoresume] $1" >> "$LOG_FILE" 2>/dev/null
}

# ── Check if autoresume is enabled ────────────────────────────────────
is_enabled() {
    config="/mnt/SDCARD/System/etc/jukamix.json"
    if [ -f "$config" ]; then
        enabled=$(grep -o '"AUTORESUME"[[:space:]]*:[[:space:]]*"[^"]*"' "$config" 2>/dev/null | head -1 | sed 's/.*"\([^"]*\)"$/\1/')
        [ "$enabled" != "disabled" ]
    else
        return 0  # Enabled by default
    fi
}

# ── Get last session info ─────────────────────────────────────────────
get_last_session() {
    if [ ! -f "$SESSION_FILE" ]; then
        return 1
    fi
    
    # Check if session is recent (within last 5 minutes)
    session_time=$(grep "^timestamp=" "$SESSION_FILE" 2>/dev/null | cut -d= -f2)
    current_time=$(date +%s)
    
    # Validate timestamp
    if [ -z "$session_time" ] || ! echo "$session_time" | grep -q '^[0-9]*$'; then
        return 1
    fi
    
    age=$((current_time - session_time))
    
    # 5 minutes = 300 seconds
    if [ "$age" -gt 300 ]; then
        log "Session too old ($age seconds), skipping autoresume"
        return 1
    fi
    
    return 0
}

# ── Get last game info ────────────────────────────────────────────────
get_last_game() {
    emulator_dir=""
    game_file=""
    
    # Check each emulator's autosave directory
    for emu in retroarch ppsspp drastic; do
        last_game="$RESUME_DIR/$emu/last_game.txt"
        if [ -f "$last_game" ]; then
            emulator_dir="$emu"
            game_file="$last_game"
            break
        fi
    done
    
    if [ -z "$game_file" ]; then
        return 1
    fi
    
    # Get game path from the emulator's last_game.txt
    game_path=$(grep "^game=" "$game_file" 2>/dev/null | cut -d= -f2-)
    timestamp=$(grep "^timestamp=" "$game_file" 2>/dev/null | cut -d= -f2)
    
    # Validate game path
    if [ -z "$game_path" ]; then
        return 1
    fi
    
    # Check if game is recent
    current_time=$(date +%s)
    
    # Validate timestamp
    if [ -n "$timestamp" ] && echo "$timestamp" | grep -q '^[0-9]*$'; then
        age=$((current_time - timestamp))
        
        if [ "$age" -gt 300 ]; then
            log "Game too old ($age seconds), skipping"
            return 1
        fi
    fi
    
    echo "$emulator_dir|$game_path"
}

# ── Resume game ───────────────────────────────────────────────────────
resume_game() {
    game_info="$1"
    emulator=$(echo "$game_info" | cut -d'|' -f1)
    game_path=$(echo "$game_info" | cut -d'|' -f2)
    
    # Validate game path exists
    if [ -z "$game_path" ] || [ ! -f "$game_path" ]; then
        log "Game not found: $game_path"
        return 1
    fi
    
    # Validate emulator directory exists
    emu_dir=""
    case "$emulator" in
        retroarch) emu_dir="$SCRIPTS_DIR/../../Emus" ;;
        ppsspp)    emu_dir="$SCRIPTS_DIR/../../Emus/PSP" ;;
        drastic)   emu_dir="$SCRIPTS_DIR/../../Emus/NDS" ;;
    esac
    
    if [ -n "$emu_dir" ] && [ ! -d "$emu_dir" ]; then
        log "Emulator directory not found: $emu_dir"
        return 1
    fi
    
    log "Resuming: $game_path via $emulator"
    
    # Show resume message ONLY if infoscreen exists and we're not in a loop
    if [ -f "$SCRIPTS_DIR/infoscreen.sh" ] && [ ! -f "/tmp/resume_in_progress" ]; then
        touch "/tmp/resume_in_progress" 2>/dev/null
        "$SCRIPTS_DIR/infoscreen.sh" -m "Resuming: $(basename "$game_path")" -t 2 2>/dev/null &
        sleep 1
    fi
    
    # Launch game with proper error handling
    launch_result=1
    case "$emulator" in
        retroarch)
            # Find appropriate launcher based on file extension
            ext="${game_path##*.}"
            case "$ext" in
                smc|sfc|fig)  [ -f "$SCRIPTS_DIR/../../Emus/SNES/launch.sh" ] && "$SCRIPTS_DIR/../../Emus/SNES/launch.sh" "$game_path" 2>/dev/null && launch_result=0 ;;
                gb|gbc)       [ -f "$SCRIPTS_DIR/../../Emus/GBC/launch.sh" ] && "$SCRIPTS_DIR/../../Emus/GBC/launch.sh" "$game_path" 2>/dev/null && launch_result=0 ;;
                gba)          [ -f "$SCRIPTS_DIR/../../Emus/GBA/launch.sh" ] && "$SCRIPTS_DIR/../../Emus/GBA/launch.sh" "$game_path" 2>/dev/null && launch_result=0 ;;
                nes)          [ -f "$SCRIPTS_DIR/../../Emus/NES/launch.sh" ] && "$SCRIPTS_DIR/../../Emus/NES/launch.sh" "$game_path" 2>/dev/null && launch_result=0 ;;
                nds)          [ -f "$SCRIPTS_DIR/../../Emus/NDS/launch.sh" ] && "$SCRIPTS_DIR/../../Emus/NDS/launch.sh" "$game_path" 2>/dev/null && launch_result=0 ;;
                *)            [ -f "$SCRIPTS_DIR/../../Emus/GenericRetroArch/launch.sh" ] && "$SCRIPTS_DIR/../../Emus/GenericRetroArch/launch.sh" "$game_path" 2>/dev/null && launch_result=0 ;;
            esac
            ;;
        ppsspp)
            [ -f "$SCRIPTS_DIR/../../Emus/PSP/launch.sh" ] && "$SCRIPTS_DIR/../../Emus/PSP/launch.sh" "$game_path" 2>/dev/null && launch_result=0
            ;;
        drastic)
            [ -f "$SCRIPTS_DIR/../../Emus/NDS/launch.sh" ] && "$SCRIPTS_DIR/../../Emus/NDS/launch.sh" "$game_path" 2>/dev/null && launch_result=0
            ;;
    esac
    
    # Clean up
    rm -f "/tmp/resume_in_progress" 2>/dev/null
    
    if [ $launch_result -ne 0 ]; then
        log "Failed to launch game: $game_path"
    fi
    
    return $launch_result
}

# ── Main ──────────────────────────────────────────────────────────────
main() {
    log "Autoresume check started"
    
    # Check if enabled
    if ! is_enabled; then
        log "Autoresume disabled in config"
        return 0
    fi
    
    # Check for recent session
    if ! get_last_session; then
        log "No recent session to resume"
        return 0
    fi
    
    # Get last game
    game_info=$(get_last_game)
    if [ -z "$game_info" ]; then
        log "No game to resume"
        return 0
    fi
    
    log "Found game to resume: $game_info"
    
    # Resume game
    resume_game "$game_info"
}

# Run if called directly
if [ "${1:-}" != "--background" ]; then
    main
else
    main &
fi

exit 0
