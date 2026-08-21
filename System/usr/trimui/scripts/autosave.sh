#!/bin/sh
# System/usr/trimui/scripts/autosave.sh
# Autosave game state for running emulators on shutdown
# Called by kill_apps.sh before shutdown

SCRIPTS_DIR="/mnt/SDCARD/System/usr/trimui/scripts"
SAVE_DIR="/mnt/SDCARD/trimui/autosave"
LOG_FILE="/tmp/autosave.log"

# Logging
log() {
    echo "$(date '+%H:%M:%S') [autosave] $1" >> "$LOG_FILE"
    echo "$(date '+%H:%M:%S') [autosave] $1"
}

# Create save directory
mkdir -p "$SAVE_DIR"

log "Starting autosave..."

# ── RetroArch autosave ─────────────────────────────────────────────────
save_retroarch() {
    local pid
    pid=$(pgrep -f "retroarch" | head -1)
    [ -z "$pid" ] && return 1
    
    log "RetroArch detected (PID: $pid)"
    
    # Find the game being played
    local game_name=""
    local core_name=""
    
    # Try to get info from /proc
    local cmdline=$(tr '\0' ' ' < /proc/$pid/cmdline 2>/dev/null)
    
    # Extract core and game from command line
    if echo "$cmdline" | grep -q "\-L"; then
        core_name=$(echo "$cmdline" | grep -oP '\-L \K[^ ]+' | xargs basename 2>/dev/null)
        game_name=$(echo "$cmdline" | grep -oP '\-L [^ ]+ \K[^ ]+' | xargs basename 2>/dev/null)
    fi
    
    [ -z "$game_name" ] && game_name="unknown_game"
    [ -z "$core_name" ] && core_name="unknown_core"
    
    log "Game: $game_name Core: $core_name"
    
    # Create save state directory
    local state_dir="$SAVE_DIR/retroarch"
    mkdir -p "$state_dir"
    
    # Save current game info for resume
    cat > "$state_dir/last_game.txt" << EOF
core=$core_name
game=$game_name
timestamp=$(date +%s)
EOF
    
    # Try to trigger save state via RetroArch's network command
    # RetroArch listens on port 55355 by default
    if command -v nc >/dev/null 2>&1; then
        echo "SAVE_STATE" | nc -w 1 127.0.0.1 55355 2>/dev/null
        log "Sent SAVE_STATE command to RetroArch"
    fi
    
    return 0
}

# ── PPSSPP autosave ────────────────────────────────────────────────────
save_ppsspp() {
    local pid
    pid=$(pgrep -f "PPSSPPSDL" | head -1)
    [ -z "$pid" ] && return 1
    
    log "PPSSPP detected (PID: $pid)"
    
    local state_dir="$SAVE_DIR/ppsspp"
    mkdir -p "$state_dir"
    
    # Get game info from command line
    local cmdline=$(tr '\0' ' ' < /proc/$pid/cmdline 2>/dev/null)
    local game_name=$(echo "$cmdline" | grep -oP '\.iso|\.cso' | head -1 | xargs basename 2>/dev/null)
    
    [ -z "$game_name" ] && game_name="unknown_game"
    
    log "Game: $game_name"
    
    # Save current game info for resume
    cat > "$state_dir/last_game.txt" << EOF
game=$game_name
timestamp=$(date +%s)
EOF
    
    # PPSSPP saves state automatically when using Select+R2
    # We just need to record what was being played
    
    return 0
}

# ── DraStic autosave ───────────────────────────────────────────────────
save_drastic() {
    local pid
    pid=$(pgrep -f "drastic" | head -1)
    [ -z "$pid" ] && return 1
    
    log "DraStic detected (PID: $pid)"
    
    local state_dir="$SAVE_DIR/drastic"
    mkdir -p "$state_dir"
    
    # DraStic has its own autosave mechanism
    # Just record what was being played
    local cmdline=$(tr '\0' ' ' < /proc/$pid/cmdline 2>/dev/null)
    local game_name=$(echo "$cmdline" | grep -oP '\.nds' | head -1 | xargs basename 2>/dev/null)
    
    [ -z "$game_name" ] && game_name="unknown_game"
    
    cat > "$state_dir/last_game.txt" << EOF
game=$game_name
timestamp=$(date +%s)
EOF
    
    return 0
}

# ── Main ──────────────────────────────────────────────────────────────

# Check each emulator
save_retroarch
save_ppsspp
save_drastic

# Save overall state
cat > "$SAVE_DIR/last_session.txt" << EOF
timestamp=$(date +%s)
date=$(date)
EOF

log "Autosave completed"
sync
