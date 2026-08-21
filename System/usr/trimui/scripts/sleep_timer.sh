#!/bin/sh
# System/usr/trimui/scripts/sleep_timer.sh
# Sleep Timer - Automatic shutdown after timeout

TIMER_FILE="/tmp/sleep_timer.pid"
LOG_FILE="/tmp/sleep_timer.log"

# Logging
log() {
    echo "$(date '+%H:%M:%S') [timer] $1" >> "$LOG_FILE"
}

# ── Start timer ────────────────────────────────────────────────────────
start_timer() {
    local minutes="$1"
    
    if [ -z "$minutes" ] || [ "$minutes" -le 0 ]; then
        echo "Usage: sleep_timer.sh start <minutes>"
        return 1
    fi
    
    # Stop existing timer
    stop_timer 2>/dev/null
    
    local seconds=$((minutes * 60))
    
    log "Starting timer: $minutes minutes"
    
    # Start background timer
    (
        sleep "$seconds"
        log "Timer expired - shutting down"
        echo "Sleep timer expired - shutting down..."
        sync
        poweroff 2>/dev/null || shutdown -h now 2>/dev/null
    ) &
    
    local pid=$!
    echo "$pid" > "$TIMER_FILE"
    
    echo "Sleep timer set: $minutes minutes"
    echo "Shutdown at: $(date -d "+$minutes minutes" '+%H:%M:%S' 2>/dev/null || date -v+${minutes}M '+%H:%M:%S' 2>/dev/null || echo 'unknown')"
}

# ── Stop timer ─────────────────────────────────────────────────────────
stop_timer() {
    if [ -f "$TIMER_FILE" ]; then
        local pid=$(cat "$TIMER_FILE")
        
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null
            log "Timer stopped"
            echo "Sleep timer cancelled"
        fi
        
        rm -f "$TIMER_FILE"
    else
        echo "No timer running"
    fi
}

# ── Show timer status ──────────────────────────────────────────────────
show_status() {
    if [ ! -f "$TIMER_FILE" ]; then
        echo "No sleep timer running"
        return
    fi
    
    local pid=$(cat "$TIMER_FILE")
    
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
        # Get remaining time from /proc
        local start_time=$(stat -c "%Y" /proc/$pid 2>/dev/null)
        
        if [ -n "$start_time" ]; then
            local now=$(date +%s)
            local elapsed=$((now - start_time))
            local remaining=$(( (3600 - elapsed) / 60 ))
            
            echo "Sleep timer running"
            echo "Remaining: ~$remaining minutes"
            echo "PID: $pid"
        else
            echo "Sleep timer running (PID: $pid)"
        fi
    else
        echo "No sleep timer running"
        rm -f "$TIMER_FILE"
    fi
}

# ── Add time ───────────────────────────────────────────────────────────
add_time() {
    local minutes="$1"
    
    if [ -z "$minutes" ] || [ "$minutes" -le 0 ]; then
        echo "Usage: sleep_timer.sh add <minutes>"
        return 1
    fi
    
    # Stop current timer and restart with additional time
    stop_timer 2>/dev/null
    start_timer "$minutes"
}

# ── Preset timers ──────────────────────────────────────────────────────
preset_30() { start_timer 30; }
preset_60() { start_timer 60; }
preset_90() { start_timer 90; }
preset_120() { start_timer 120; }

# ── Main ──────────────────────────────────────────────────────────────
case "${1:-}" in
    start)
        start_timer "$2"
        ;;
    stop|cancel|off)
        stop_timer
        ;;
    status|show)
        show_status
        ;;
    add)
        add_time "$2"
        ;;
    30)
        preset_30
        ;;
    60)
        preset_60
        ;;
    90)
        preset_90
        ;;
    120|2h)
        preset_120
        ;;
    *)
        echo "Sleep Timer"
        echo "==========="
        echo ""
        show_status
        echo ""
        echo "Usage: sleep_timer.sh {command} [minutes]" >&2
        echo "" >&2
        echo "Commands:" >&2
        echo "  start <minutes>  - Set timer for X minutes" >&2
        echo "  stop             - Cancel timer" >&2
        echo "  status           - Show timer status" >&2
        echo "  add <minutes>    - Add time to current timer" >&2
        echo "" >&2
        echo "Presets:" >&2
        echo "  30               - 30 minutes" >&2
        echo "  60               - 1 hour" >&2
        echo "  90               - 1.5 hours" >&2
        echo "  120              - 2 hours" >&2
        exit 1
        ;;
esac
