#!/bin/sh
# System/usr/trimui/scripts/playtime_tracker.sh
# Track play time per game and show statistics

# ── Safeguards ────────────────────────────────────────────────────────
# Ensure required directories exist
mkdir -p /tmp 2>/dev/null
mkdir -p /mnt/SDCARD/trimui 2>/dev/null

PLAYTIME_DIR="/mnt/SDCARD/trimui/playtime"
LOG_FILE="/tmp/playtime.log"

# Create playtime directory
mkdir -p "$PLAYTIME_DIR" 2>/dev/null

# ── Logging ───────────────────────────────────────────────────────────
log() {
    echo "$(date '+%H:%M:%S') [playtime] $1" >> "$LOG_FILE" 2>/dev/null
}

# ── Start tracking ─────────────────────────────────────────────────────
start_tracking() {
    local game_path="$1"
    local emulator="$2"
    local game_name=$(basename "$game_path")
    local game_id=$(echo "$game_name" | md5sum 2>/dev/null | cut -d' ' -f1)
    
    if [ -z "$game_id" ]; then
        game_id=$(echo "$game_name" | wc -c)
    fi
    
    local tracking_file="$PLAYTIME_DIR/${game_id}.track"
    
    # Save tracking info
    cat > "$tracking_file" << EOF
path=$game_path
name=$game_name
emulator=$emulator
start_time=$(date +%s)
EOF
    
    log "Started tracking: $game_name ($emulator)"
    echo "$game_id"
}

# ── Stop tracking ──────────────────────────────────────────────────────
stop_tracking() {
    local game_id="$1"
    local tracking_file="$PLAYTIME_DIR/${game_id}.track"
    
    if [ ! -f "$tracking_file" ]; then
        return 1
    fi
    
    local start_time=$(grep "^start_time=" "$tracking_file" | cut -d= -f2)
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Get game info
    local game_path=$(grep "^path=" "$tracking_file" | cut -d= -f2-)
    local game_name=$(grep "^name=" "$tracking_file" | cut -d= -f2-)
    local emulator=$(grep "^emulator=" "$tracking_file" | cut -d= -f2)
    
    # Update playtime file
    local playtime_file="$PLAYTIME_DIR/${game_id}.time"
    local total_time=0
    
    if [ -f "$playtime_file" ]; then
        total_time=$(grep "^total_seconds=" "$playtime_file" | cut -d= -f2)
    fi
    
    total_time=$((total_time + duration))
    
    # Save updated playtime
    cat > "$playtime_file" << EOF
path=$game_path
name=$game_name
emulator=$emulator
total_seconds=$total_time
last_played=$(date +%s)
sessions=$(( $(grep "^sessions=" "$playtime_file" 2>/dev/null | cut -d= -f2 || echo "0") + 1 ))
EOF
    
    # Remove tracking file
    rm -f "$tracking_file"
    
    log "Stopped tracking: $game_name (${duration}s this session, ${total_time}s total)"
    return 0
}

# ── Get play time ──────────────────────────────────────────────────────
get_playtime() {
    local game_id="$1"
    local playtime_file="$PLAYTIME_DIR/${game_id}.time"
    
    if [ ! -f "$playtime_file" ]; then
        echo "0"
        return
    fi
    
    grep "^total_seconds=" "$playtime_file" | cut -d= -f2
}

# ── Format time ────────────────────────────────────────────────────────
format_time() {
    local seconds="$1"
    
    if [ "$seconds" -ge 3600 ]; then
        local hours=$((seconds / 3600))
        local mins=$(( (seconds % 3600) / 60 ))
        echo "${hours}h ${mins}m"
    elif [ "$seconds" -ge 60 ]; then
        local mins=$((seconds / 60))
        local secs=$((seconds % 60))
        echo "${mins}m ${secs}s"
    else
        echo "${seconds}s"
    fi
}

# ── Show game stats ────────────────────────────────────────────────────
show_game_stats() {
    local game_id="$1"
    local playtime_file="$PLAYTIME_DIR/${game_id}.time"
    
    if [ ! -f "$playtime_file" ]; then
        echo "No play time recorded"
        return
    fi
    
    local name=$(grep "^name=" "$playtime_file" | cut -d= -f2-)
    local total=$(grep "^total_seconds=" "$playtime_file" | cut -d= -f2)
    local sessions=$(grep "^sessions=" "$playtime_file" | cut -d= -f2)
    local last=$(grep "^last_played=" "$playtime_file" | cut -d= -f2)
    
    echo "Game: $name"
    echo "Total Play Time: $(format_time $total)"
    echo "Sessions: $sessions"
    echo "Last Played: $(date -d "@$last" '+%Y-%m-%d %H:%M' 2>/dev/null || date -r "$last" '+%Y-%m-%d %H:%M' 2>/dev/null || echo 'Unknown')"
}

# ── Show all stats ─────────────────────────────────────────────────────
show_all_stats() {
    echo "=== JukaMix Play Time Statistics ==="
    echo ""
    
    local total_time=0
    local total_games=0
    local total_sessions=0
    
    for playtime_file in "$PLAYTIME_DIR"/*.time; do
        [ -f "$playtime_file" ] || continue
        
        local name=$(grep "^name=" "$playtime_file" | cut -d= -f2-)
        local total=$(grep "^total_seconds=" "$playtime_file" | cut -d= -f2)
        local sessions=$(grep "^sessions=" "$playtime_file" | cut -d= -f2)
        
        if [ -n "$name" ] && [ -n "$total" ]; then
            printf "%-30s %8s  %d sessions\n" "$name" "$(format_time $total)" "$sessions"
            total_time=$((total_time + total))
            total_games=$((total_games + 1))
            total_sessions=$((total_sessions + sessions))
        fi
    done
    
    echo ""
    echo "====================================="
    echo "Total Games: $total_games"
    echo "Total Sessions: $total_sessions"
    echo "Total Play Time: $(format_time $total_time)"
}

# ── Show top games ─────────────────────────────────────────────────────
show_top_games() {
    local limit="${1:-10}"
    
    echo "=== Top $limit Games by Play Time ==="
    echo ""
    
    # Collect and sort
    for playtime_file in "$PLAYTIME_DIR"/*.time; do
        [ -f "$playtime_file" ] || continue
        
        local name=$(grep "^name=" "$playtime_file" | cut -d= -f2-)
        local total=$(grep "^total_seconds=" "$playtime_file" | cut -d= -f2)
        
        if [ -n "$name" ] && [ -n "$total" ]; then
            echo "$total $name"
        fi
    done | sort -rn | head -$limit | while read -r total name; do
        printf "%8s  %s\n" "$(format_time $total)" "$name"
    done
}

# ── Main ──────────────────────────────────────────────────────────────
case "${1:-}" in
    start)
        start_tracking "$2" "$3"
        ;;
    stop)
        stop_tracking "$2"
        ;;
    time)
        get_playtime "$2"
        ;;
    stats)
        show_game_stats "$2"
        ;;
    all)
        show_all_stats
        ;;
    top)
        show_top_games "${2:-10}"
        ;;
    *)
        echo "Usage: playtime_tracker.sh {start|stop|time|stats|all|top} [args]" >&2
        echo "" >&2
        echo "Commands:" >&2
        echo "  start <game> [emulator] - Start tracking play time" >&2
        echo "  stop <game_id>          - Stop tracking and save" >&2
        echo "  time <game_id>          - Get total play time" >&2
        echo "  stats <game_id>         - Show game statistics" >&2
        echo "  all                     - Show all statistics" >&2
        echo "  top [n]                 - Show top N games" >&2
        exit 1
        ;;
esac
