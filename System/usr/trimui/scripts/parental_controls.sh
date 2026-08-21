#!/bin/sh
# parental_controls.sh - Parental Controls and Game Time Limiter for JukaMix
# Limits play time, restricts content, and provides usage reports

CONFIG_FILE="/mnt/SDCARD/System/etc/jukamix.json"
PARENTAL_DIR="/mnt/SDCARD/trimui/parental"
LOG_FILE="/tmp/parental_controls.log"
PLAYTIME_DIR="/mnt/SDCARD/trimui/play_history"

# Create directories
mkdir -p "$PARENTAL_DIR" 2>/dev/null

# ── Logging ────────────────────────────────────────────────────────────
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [parental] $1" >> "$LOG_FILE" 2>/dev/null
}

# ── Get current time in minutes since midnight ──────────────────────────
get_time_of_day() {
    hours=$(date +%H)
    minutes=$(date +%M)
    echo $((hours * 60 + minutes))
}

# ── Get total play time today ──────────────────────────────────────────
get_today_playtime() {
    today=$(date +%Y%m%d)
    playtime_file="$PLAYTIME_DIR/times_${today}.txt"
    
    if [ -f "$playtime_file" ]; then
        # Sum all play times
        total=0
        while IFS=: read -r game minutes; do
            total=$((total + minutes))
        done < "$playtime_file"
        echo "$total"
    else
        echo "0"
    fi
}

# ── Record play time ────────────────────────────────────────────────────
record_playtime() {
    game="$1"
    minutes="$2"
    
    today=$(date +%Y%m%d)
    playtime_file="$PLAYTIME_DIR/times_${today}.txt"
    
    # Update or add game time
    if [ -f "$playtime_file" ]; then
        # Check if game already recorded
        if grep -q "^${game}:" "$playtime_file" 2>/dev/null; then
            # Update existing entry
            sed -i "s/^${game}:.*/${game}:${minutes}/" "$playtime_file" 2>/dev/null
        else
            # Add new entry
            echo "${game}:${minutes}" >> "$playtime_file"
        fi
    else
        echo "${game}:${minutes}" > "$playtime_file"
    fi
    
    log "Recorded playtime: $game = $minutes minutes"
}

# ── Check if play is allowed ────────────────────────────────────────────
is_play_allowed() {
    # Check if parental controls are enabled
    if [ -f "$CONFIG_FILE" ] && command -v jq >/dev/null 2>&1; then
        enabled=$(jq -r '.["PARENTAL_CONTROLS"] // "false"' "$CONFIG_FILE" 2>/dev/null)
        if [ "$enabled" != "true" ]; then
            return 0  # Parental controls disabled, allow play
        fi
    else
        return 0  # No config, allow play
    fi
    
    # Check time restrictions
    time_restrictions=$(jq -r '.["TIME_RESTRICTIONS"] // {}' "$CONFIG_FILE" 2>/dev/null)
    if [ "$time_restrictions" != "{}" ]; then
        current_time=$(get_time_of_day)
        allowed_start=$(echo "$time_restrictions" | jq -r '.start // "0"' 2>/dev/null)
        allowed_end=$(echo "$time_restrictions" | jq -r '.end // "1440"' 2>/dev/null)
        
        # Convert to minutes
        allowed_start=$((allowed_start * 60))
        allowed_end=$((allowed_end * 60))
        
        if [ "$current_time" -lt "$allowed_start" ] || [ "$current_time" -gt "$allowed_end" ]; then
            log "Play blocked: Outside allowed hours"
            return 1
        fi
    fi
    
    # Check daily time limit
    daily_limit=$(jq -r '.["DAILY_TIME_LIMIT"] // "0"' "$CONFIG_FILE" 2>/dev/null)
    if [ "$daily_limit" -gt 0 ]; then
        today_playtime=$(get_today_playtime)
        if [ "$today_playtime" -ge "$daily_limit" ]; then
            log "Play blocked: Daily time limit reached ($today_playtime/$daily_limit minutes)"
            return 1
        fi
    fi
    
    return 0
}

# ── Show time remaining ─────────────────────────────────────────────────
show_time_remaining() {
    daily_limit=$(jq -r '.["DAILY_TIME_LIMIT"] // "0"' "$CONFIG_FILE" 2>/dev/null)
    
    if [ "$daily_limit" -eq 0 ]; then
        echo "No time limit set"
        return
    fi
    
    today_playtime=$(get_today_playtime)
    remaining=$((daily_limit - today_playtime))
    
    if [ "$remaining" -le 0 ]; then
        echo "Time limit reached!"
    else
        hours=$((remaining / 60))
        minutes=$((remaining % 60))
        echo "Time remaining: ${hours}h ${minutes}m"
    fi
}

# ── Set daily time limit ────────────────────────────────────────────────
set_daily_limit() {
    limit_minutes="$1"
    
    if [ -z "$limit_minutes" ]; then
        echo "Usage: parental_controls.sh set-limit <minutes>"
        return 1
    fi
    
    if [ -f "$CONFIG_FILE" ] && command -v jq >/dev/null 2>&1; then
        jq --arg limit "$limit_minutes" '. += {"DAILY_TIME_LIMIT": ($limit | tonumber)}' "$CONFIG_FILE" > /tmp/jukamix_tmp.json 2>/dev/null && \
        mv /tmp/jukamix_tmp.json "$CONFIG_FILE" 2>/dev/null
        
        log "Daily time limit set: $limit_minutes minutes"
        echo "Daily time limit set: $limit_minutes minutes"
    else
        echo "Cannot update config"
        return 1
    fi
}

# ── Set time restrictions ───────────────────────────────────────────────
set_time_restrictions() {
    start_hour="$1"
    end_hour="$2"
    
    if [ -z "$start_hour" ] || [ -z "$end_hour" ]; then
        echo "Usage: parental_controls.sh set-hours <start_hour> <end_hour>"
        echo "Example: parental_controls.sh set-hours 8 20  (8am to 8pm)"
        return 1
    fi
    
    if [ -f "$CONFIG_FILE" ] && command -v jq >/dev/null 2>&1; then
        jq --arg start "$start_hour" --arg end "$end_hour" \
            '. += {"TIME_RESTRICTIONS": {"start": ($start | tonumber), "end": ($end | tonumber)}}' \
            "$CONFIG_FILE" > /tmp/jukamix_tmp.json 2>/dev/null && \
        mv /tmp/jukamix_tmp.json "$CONFIG_FILE" 2>/dev/null
        
        log "Time restrictions set: $start_hour:00 to $end_hour:00"
        echo "Time restrictions set: $start_hour:00 to $end_hour:00"
    else
        echo "Cannot update config"
        return 1
    fi
}

# ── Enable parental controls ────────────────────────────────────────────
enable_controls() {
    if [ -f "$CONFIG_FILE" ] && command -v jq >/dev/null 2>&1; then
        jq '. += {"PARENTAL_CONTROLS": true}' "$CONFIG_FILE" > /tmp/jukamix_tmp.json 2>/dev/null && \
        mv /tmp/jukamix_tmp.json "$CONFIG_FILE" 2>/dev/null
        
        log "Parental controls enabled"
        echo "Parental controls enabled"
    else
        echo "Cannot update config"
        return 1
    fi
}

# ── Disable parental controls ───────────────────────────────────────────
disable_controls() {
    if [ -f "$CONFIG_FILE" ] && command -v jq >/dev/null 2>&1; then
        jq '. += {"PARENTAL_CONTROLS": false}' "$CONFIG_FILE" > /tmp/jukamix_tmp.json 2>/dev/null && \
        mv /tmp/jukamix_tmp.json "$CONFIG_FILE" 2>/dev/null
        
        log "Parental controls disabled"
        echo "Parental controls disabled"
    else
        echo "Cannot update config"
        return 1
    fi
}

# ── Show usage report ───────────────────────────────────────────────────
show_usage_report() {
    echo "Usage Report:"
    echo "============="
    echo ""
    
    # Show today's usage
    today=$(date +%Y%m%d)
    playtime_file="$PLAYTIME_DIR/times_${today}.txt"
    
    echo "Today's Play Time:"
    if [ -f "$playtime_file" ]; then
        total=0
        while IFS=: read -r game minutes; do
            hours=$((minutes / 60))
            mins=$((minutes % 60))
            echo "  $game: ${hours}h ${mins}m"
            total=$((total + minutes))
        done < "$playtime_file" | sort -t: -k2 -rn
        
        total_hours=$((total / 60))
        total_mins=$((total % 60))
        echo ""
        echo "Total: ${total_hours}h ${total_mins}m"
    else
        echo "  No play time recorded"
    fi
    
    echo ""
    
    # Show weekly summary
    echo "Weekly Summary:"
    for i in $(seq 6 -1 0); do
        day=$(date -d "$i days ago" +%Y%m%d 2>/dev/null || date -v-${i}d +%Y%m%d 2>/dev/null)
        dayname=$(date -d "$i days ago" +%A 2>/dev/null || date -v-${i}d +%A 2>/dev/null)
        
        day_file="$PLAYTIME_DIR/times_${day}.txt"
        if [ -f "$day_file" ]; then
            total=0
            while IFS=: read -r game minutes; do
                total=$((total + minutes))
            done < "$day_file"
            
            hours=$((total / 60))
            mins=$((total % 60))
            echo "  $dayname: ${hours}h ${mins}m"
        else
            echo "  $dayname: No play"
        fi
    done
}

# ── Show settings ───────────────────────────────────────────────────────
show_settings() {
    echo "Parental Control Settings:"
    echo "=========================="
    echo ""
    
    if [ -f "$CONFIG_FILE" ] && command -v jq >/dev/null 2>&1; then
        enabled=$(jq -r '.["PARENTAL_CONTROLS"] // "false"' "$CONFIG_FILE" 2>/dev/null)
        daily_limit=$(jq -r '.["DAILY_TIME_LIMIT"] // "0"' "$CONFIG_FILE" 2>/dev/null)
        time_restrictions=$(jq -r '.["TIME_RESTRICTIONS"] // {}' "$CONFIG_FILE" 2>/dev/null)
        
        echo "Enabled: $enabled"
        echo "Daily Limit: $daily_limit minutes"
        
        if [ "$time_restrictions" != "{}" ]; then
            start=$(echo "$time_restrictions" | jq -r '.start // "0"' 2>/dev/null)
            end=$(echo "$time_restrictions" | jq -r '.end // "24"' 2>/dev/null)
            echo "Allowed Hours: ${start}:00 to ${end}:00"
        else
            echo "Allowed Hours: No restrictions"
        fi
    else
        echo "No configuration found"
    fi
    
    echo ""
    show_time_remaining
}

# ── Main ───────────────────────────────────────────────────────────────
case "${1:-}" in
    check)
        if is_play_allowed; then
            echo "Play allowed"
            return 0
        else
            echo "Play not allowed"
            return 1
        fi
        ;;
    record)
        record_playtime "${2:-unknown}" "${3:-0}"
        ;;
    remaining)
        show_time_remaining
        ;;
    set-limit)
        set_daily_limit "${2:-}"
        ;;
    set-hours)
        set_time_restrictions "${2:-}" "${3:-}"
        ;;
    enable)
        enable_controls
        ;;
    disable)
        disable_controls
        ;;
    report)
        show_usage_report
        ;;
    settings)
        show_settings
        ;;
    *)
        echo "Parental Controls and Game Time Limiter"
        echo "Usage: parental_controls.sh {check|record|remaining|set-limit|set-hours|enable|disable|report|settings}"
        echo ""
        echo "Commands:"
        echo "  check              - Check if play is allowed"
        echo "  record <game> <min> - Record play time"
        echo "  remaining          - Show time remaining"
        echo "  set-limit <min>    - Set daily time limit"
        echo "  set-hours <start> <end> - Set allowed hours"
        echo "  enable             - Enable parental controls"
        echo "  disable            - Disable parental controls"
        echo "  report             - Show usage report"
        echo "  settings           - Show current settings"
        ;;
esac
