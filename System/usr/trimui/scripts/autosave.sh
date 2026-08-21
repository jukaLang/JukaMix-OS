#!/bin/sh
# System/usr/trimui/scripts/autosave.sh
# Autosave game state for running emulators on shutdown
# Called by kill_apps.sh before shutdown

# ── Safeguards ────────────────────────────────────────────────────────
# Ensure required directories exist
mkdir -p /tmp 2>/dev/null
mkdir -p /mnt/SDCARD/trimui 2>/dev/null

SCRIPTS_DIR="/mnt/SDCARD/System/usr/trimui/scripts"
SAVE_DIR="/mnt/SDCARD/trimui/autosave"
LOG_FILE="/tmp/autosave.log"

# Create save directory
mkdir -p "$SAVE_DIR" 2>/dev/null

# ── Logging ───────────────────────────────────────────────────────────
log() {
    echo "$(date '+%H:%M:%S') [autosave] $1" >> "$LOG_FILE" 2>/dev/null
}

log "Starting autosave..."

# ── RetroArch autosave ─────────────────────────────────────────────────
save_retroarch() {
    # Check if RetroArch is running
    pid=$(pgrep -f "retroarch" 2>/dev/null | head -1)
    [ -z "$pid" ] && return 1

    log "RetroArch detected (PID: $pid)"

    # Find the game being played
    game_name=""
    core_name=""

    # Try to get info from /proc
    if [ -f "/proc/$pid/cmdline" ]; then
        cmdline=$(tr '\0' ' ' < /proc/$pid/cmdline 2>/dev/null)
        
        # Extract core from -L argument
        if echo "$cmdline" | grep -q -- "-L"; then
            core_name=$(echo "$cmdline" | awk -F'-L ' '{print $2}' | awk '{print $1}' | xargs basename 2>/dev/null)
            game_name=$(echo "$cmdline" | awk -F'-L ' '{print $2}' | awk '{for(i=2;i<=NF;i++) printf "%s ", $i; print ""}' | awk '{print $1}' | xargs basename 2>/dev/null)
        fi
    fi

    [ -z "$game_name" ] && game_name="unknown_game"
    [ -z "$core_name" ] && core_name="unknown_core"

    log "Game: $game_name Core: $core_name"

    # Create save state directory
    state_dir="$SAVE_DIR/retroarch"
    mkdir -p "$state_dir" 2>/dev/null

    # Save current game info for resume
    cat > "$state_dir/last_game.txt" << EOF
core=$core_name
game=$game_name
timestamp=$(date +%s)
EOF

    # Try to trigger save state via RetroArch's network command
    if command -v nc >/dev/null 2>&1; then
        echo "SAVE_STATE" | nc -w 2 127.0.0.1 55355 2>/dev/null
        log "Sent SAVE_STATE command to RetroArch via nc"
    fi

    # Save in-slot state marker
    echo "$game_name" > "$state_dir/last_state_slot" 2>/dev/null

    return 0
}

# ── PPSSPP autosave ────────────────────────────────────────────────────
save_ppsspp() {
    # Check if PPSSPP is running
    pid=$(pgrep -f "PPSSPPSDL" 2>/dev/null | head -1)
    [ -z "$pid" ] && return 1

    log "PPSSPP detected (PID: $pid)"

    state_dir="$SAVE_DIR/ppsspp"
    mkdir -p "$state_dir" 2>/dev/null

    # Get game info from command line
    game_name=""
    if [ -f "/proc/$pid/cmdline" ]; then
        cmdline=$(tr '\0' ' ' < /proc/$pid/cmdline 2>/dev/null)
        # Extract game filename
        for ext in ".iso" ".cso" ".pbp"; do
            game_name=$(echo "$cmdline" | sed "s/.*[ ]//;s/\(${ext}\).*/\1/" | xargs basename 2>/dev/null)
            [ -n "$game_name" ] && break
        done
    fi

    [ -z "$game_name" ] && game_name="unknown_game"

    log "Game: $game_name"

    # Save current game info for resume
    cat > "$state_dir/last_game.txt" << EOF
game=$game_name
timestamp=$(date +%s)
EOF

    return 0
}

# ── DraStic autosave ───────────────────────────────────────────────────
save_drastic() {
    # Check if DraStic is running
    pid=$(pgrep -f "drastic" 2>/dev/null | head -1)
    [ -z "$pid" ] && return 1

    log "DraStic detected (PID: $pid)"

    state_dir="$SAVE_DIR/drastic"
    mkdir -p "$state_dir" 2>/dev/null

    # Get game info from command line
    game_name=""
    if [ -f "/proc/$pid/cmdline" ]; then
        cmdline=$(tr '\0' ' ' < /proc/$pid/cmdline 2>/dev/null)
        game_name=$(echo "$cmdline" | sed 's/.*[ ]//;s/\(.nds\).*/\1/' | xargs basename 2>/dev/null)
    fi

    [ -z "$game_name" ] && game_name="unknown_game"

    # Save current game info for resume
    cat > "$state_dir/last_game.txt" << EOF
game=$game_name
timestamp=$(date +%s)
EOF

    # Trigger DraStic's internal save by sending SIGUSR1
    kill -USR1 "$pid" 2>/dev/null && log "Sent SIGUSR1 to DraStic for autosave"

    return 0
}

# ── Auto-backup saves to vault ───────────────────────────────────────
auto_backup_saves() {
    vault_script="$SCRIPTS_DIR/save_vault.sh"
    if [ -x "$vault_script" ]; then
        log "Running save vault auto-backup"
        "$vault_script" auto-backup 2>/dev/null
    fi
}

# ── Main ──────────────────────────────────────────────────────────────

# Check each emulator
save_retroarch
save_ppsspp
save_drastic

# Auto-backup saves to vault
auto_backup_saves

# Save overall state
mkdir -p "$SAVE_DIR" 2>/dev/null
cat > "$SAVE_DIR/last_session.txt" << EOF
timestamp=$(date +%s)
date=$(date)
EOF

log "Autosave completed"
sync 2>/dev/null

exit 0
