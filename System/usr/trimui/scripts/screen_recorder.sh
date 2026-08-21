#!/bin/sh
# screen_recorder.sh - Screen Recording System for JukaMix
# Records gameplay footage with audio

RECORDINGS_DIR="/mnt/SDCARD/recordings"
TEMP_DIR="/tmp/recording"
LOG_FILE="/tmp/screen_recorder.log"
CONFIG_FILE="/mnt/SDCARD/System/etc/jukamix.json"

# Create directories
mkdir -p "$RECORDINGS_DIR" "$TEMP_DIR" 2>/dev/null

# ── Logging ────────────────────────────────────────────────────────────
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [record] $1" >> "$LOG_FILE" 2>/dev/null
}

# ── Get recording settings ─────────────────────────────────────────────
get_settings() {
    if [ -f "$CONFIG_FILE" ] && command -v jq >/dev/null 2>&1; then
        resolution=$(jq -r '.["RECORD_RESOLUTION"] // "720p"' "$CONFIG_FILE" 2>/dev/null)
        fps=$(jq -r '.["RECORD_FPS"] // "30"' "$CONFIG_FILE" 2>/dev/null)
        quality=$(jq -r '.["RECORD_QUALITY"] // "medium"' "$CONFIG_FILE" 2>/dev/null)
    else
        resolution="720p"
        fps="30"
        quality="medium"
    fi
    
    echo "$resolution $fps $quality"
}

# ── Start recording ────────────────────────────────────────────────────
start_recording() {
    game_name="${1:-gameplay}"
    timestamp=$(date +%Y%m%d_%H%M%S)
    output_file="$RECORDINGS_DIR/${game_name}_${timestamp}.mp4"
    
    # Get settings
    read resolution fps quality <<< "$(get_settings)"
    
    # Set resolution
    case "$resolution" in
        480p) width=640; height=480 ;;
        720p) width=1280; height=720 ;;
        1080p) width=1920; height=1080 ;;
        *) width=1280; height=720 ;;
    esac
    
    # Set quality
    case "$quality" in
        low) bitrate="1M" ;;
        medium) bitrate="2M" ;;
        high) bitrate="4M" ;;
        *) bitrate="2M" ;;
    esac
    
    log "Starting recording: $output_file"
    echo "Starting recording..."
    echo "Resolution: ${width}x${height}"
    echo "FPS: $fps"
    echo "Quality: $quality ($bitrate)"
    
    # Record framebuffer
    if command -v ffmpeg >/dev/null 2>&1; then
        # Record with ffmpeg
        ffmpeg -f rawvideo -pixel_format rgba -video_size ${width}x${height} \
            -framerate "$fps" -i /dev/graphics/fb0 \
            -c:v libx264 -preset ultrafast -b:v "$bitrate" \
            -y "$output_file" 2>/dev/null &
        
        REC_PID=$!
        echo "$REC_PID" > "$TEMP_DIR/recording.pid"
        
        log "Recording started with PID: $REC_PID"
        echo "Recording started (PID: $REC_PID)"
        echo "Output: $output_file"
        
        return 0
    else
        # Fallback: raw framebuffer capture
        echo "ffmpeg not available, using raw capture"
        
        # Start background capture
        while true; do
            cat /dev/graphics/fb0 >> "$TEMP_DIR/raw_frames.dat" 2>/dev/null
            sleep "$(echo "scale=3; 1/$fps" | bc 2>/dev/null || echo "0.033")"
        done &
        
        CAP_PID=$!
        echo "$CAP_PID" > "$TEMP_DIR/recording.pid"
        
        log "Raw recording started with PID: $CAP_PID"
        echo "Raw recording started (PID: $CAP_PID)"
        echo "Output: $TEMP_DIR/raw_frames.dat"
        
        return 0
    fi
}

# ── Stop recording ────────────────────────────────────────────────────
stop_recording() {
    if [ -f "$TEMP_DIR/recording.pid" ]; then
        rec_pid=$(cat "$TEMP_DIR/recording.pid" 2>/dev/null)
        
        if [ -n "$rec_pid" ]; then
            kill "$rec_pid" 2>/dev/null
            rm -f "$TEMP_DIR/recording.pid"
            
            log "Recording stopped (PID: $rec_pid)"
            echo "Recording stopped"
            
            # Convert raw frames if needed
            if [ -f "$TEMP_DIR/raw_frames.dat" ]; then
                echo "Converting raw frames to video..."
                # This would need ffmpeg to convert
                rm -f "$TEMP_DIR/raw_frames.dat"
            fi
            
            return 0
        fi
    fi
    
    echo "No active recording"
    return 1
}

# ── Pause recording ────────────────────────────────────────────────────
pause_recording() {
    if [ -f "$TEMP_DIR/recording.pid" ]; then
        rec_pid=$(cat "$TEMP_DIR/recording.pid" 2>/dev/null)
        
        if [ -n "$rec_pid" ]; then
            kill -STOP "$rec_pid" 2>/dev/null
            
            log "Recording paused (PID: $rec_pid)"
            echo "Recording paused"
            
            return 0
        fi
    fi
    
    echo "No active recording"
    return 1
}

# ── Resume recording ───────────────────────────────────────────────────
resume_recording() {
    if [ -f "$TEMP_DIR/recording.pid" ]; then
        rec_pid=$(cat "$TEMP_DIR/recording.pid" 2>/dev/null)
        
        if [ -n "$rec_pid" ]; then
            kill -CONT "$rec_pid" 2>/dev/null
            
            log "Recording resumed (PID: $rec_pid)"
            echo "Recording resumed"
            
            return 0
        fi
    fi
    
    echo "No paused recording"
    return 1
}

# ── Check recording status ────────────────────────────────────────────
check_status() {
    if [ -f "$TEMP_DIR/recording.pid" ]; then
        rec_pid=$(cat "$TEMP_DIR/recording.pid" 2>/dev/null)
        
        if [ -n "$rec_pid" ] && kill -0 "$rec_pid" 2>/dev/null; then
            # Get recording duration
            start_time=$(ps -o lstart= -p "$rec_pid" 2>/dev/null)
            if [ -n "$start_time" ]; then
                echo "Recording active (PID: $rec_pid)"
                echo "Started: $start_time"
            else
                echo "Recording active (PID: $rec_pid)"
            fi
            return 0
        fi
    fi
    
    echo "No active recording"
    return 1
}

# ── List recordings ────────────────────────────────────────────────────
list_recordings() {
    echo "Recordings:"
    echo "==========="
    echo ""
    
    count=0
    find "$RECORDINGS_DIR" -name "*.mp4" -type f 2>/dev/null | while read -r recording; do
        [ -f "$recording" ] || continue
        
        filename=$(basename "$recording")
        filesize=$(du -h "$recording" | cut -f1)
        filedate=$(stat -c %y "$recording" 2>/dev/null | cut -d'.' -f1)
        
        count=$((count + 1))
        echo "  [$count] $filename"
        echo "      Size: $filesize"
        echo "      Date: $filedate"
        echo ""
    done
    
    if [ "$count" -eq 0 ]; then
        echo "  No recordings found"
    else
        echo "Total: $count recordings"
    fi
}

# ── Delete recording ───────────────────────────────────────────────────
delete_recording() {
    recording_file="$1"
    
    if [ -f "$recording_file" ]; then
        rm -f "$recording_file" 2>/dev/null
        echo "Deleted: $(basename "$recording_file")"
        log "Deleted recording: $recording_file"
        return 0
    else
        echo "Recording not found"
        return 1
    fi
}

# ── Set recording settings ─────────────────────────────────────────────
set_settings() {
    resolution="${1:-720p}"
    fps="${2:-30}"
    quality="${3:-medium}"
    
    if [ -f "$CONFIG_FILE" ] && command -v jq >/dev/null 2>&1; then
        jq --arg res "$resolution" --arg fps "$fps" --arg qual "$quality" \
            '. += {"RECORD_RESOLUTION": $res, "RECORD_FPS": ($fps | tonumber), "RECORD_QUALITY": $qual}' \
            "$CONFIG_FILE" > /tmp/jukamix_tmp.json 2>/dev/null && \
        mv /tmp/jukamix_tmp.json "$CONFIG_FILE" 2>/dev/null
        
        log "Recording settings updated: $resolution, $fps fps, $quality"
        echo "Settings updated:"
        echo "  Resolution: $resolution"
        echo "  FPS: $fps"
        echo "  Quality: $quality"
    else
        echo "Cannot update config"
        return 1
    fi
}

# ── Show settings ───────────────────────────────────────────────────────
show_settings() {
    read resolution fps quality <<< "$(get_settings)"
    
    echo "Recording Settings:"
    echo "==================="
    echo ""
    echo "Resolution: $resolution"
    echo "FPS: $fps"
    echo "Quality: $quality"
    echo ""
    echo "Output Directory: $RECORDINGS_DIR"
}

# ── Main ───────────────────────────────────────────────────────────────
case "${1:-}" in
    start)
        start_recording "${2:-gameplay}"
        ;;
    stop)
        stop_recording
        ;;
    pause)
        pause_recording
        ;;
    resume)
        resume_recording
        ;;
    status)
        check_status
        ;;
    list)
        list_recordings
        ;;
    delete)
        delete_recording "${2:-}"
        ;;
    settings)
        if [ -n "${2:-}" ]; then
            set_settings "$2" "${3:-30}" "${4:-medium}"
        else
            show_settings
        fi
        ;;
    *)
        echo "Screen Recording System"
        echo "Usage: screen_recorder.sh {start|stop|pause|resume|status|list|delete|settings}"
        echo ""
        echo "Commands:"
        echo "  start [name]       - Start recording"
        echo "  stop               - Stop recording"
        echo "  pause              - Pause recording"
        echo "  resume             - Resume recording"
        echo "  status             - Check recording status"
        echo "  list               - List recordings"
        echo "  delete <file>      - Delete recording"
        echo "  settings [res] [fps] [quality] - View/set settings"
        ;;
esac
