#!/bin/sh
# crash_reporter.sh - Crash Reporter
# Packages logs, profiles, device info for debugging
#
# Usage: crash_reporter.sh [output_path]

REPORT_DIR="/tmp/crash_report_$(date +%Y%m%d_%H%M%S)"
OUTPUT_DEFAULT="/mnt/SDCARD/trimui/crash_reports"
LOG_FILE="/tmp/crash_reporter.log"

# ── Logging ────────────────────────────────────────────────────────────
log() {
    echo "$(date '+%H:%M:%S') [crash_report] $1" >> "$LOG_FILE" 2>/dev/null
}

# ── Collect device info ────────────────────────────────────────────────
collect_device_info() {
    log "Collecting device information"
    
    mkdir -p "$REPORT_DIR/device" 2>/dev/null
    
    # Device model
    cat /etc/trimui_device.txt > "$REPORT_DIR/device/model.txt" 2>/dev/null
    
    # Firmware version
    cat /etc/version > "$REPORT_DIR/device/firmware.txt" 2>/dev/null
    
    # Kernel version
    uname -a > "$REPORT_DIR/device/kernel.txt" 2>/dev/null
    
    # CPU info
    cat /proc/cpuinfo > "$REPORT_DIR/device/cpuinfo.txt" 2>/dev/null
    
    # Memory info
    cat /proc/meminfo > "$REPORT_DIR/device/meminfo.txt" 2>/dev/null
    
    # Storage info
    df -h > "$REPORT_DIR/device/storage.txt" 2>/dev/null
    
    # Battery info
    if [ -f /sys/class/power_supply/battery/capacity ]; then
        echo "Capacity: $(cat /sys/class/power_supply/battery/capacity)" > "$REPORT_DIR/device/battery.txt"
        echo "Status: $(cat /sys/class/power_supply/battery/status)" >> "$REPORT_DIR/device/battery.txt"
    fi
    
    # Temperature
    if [ -f /sys/class/thermal/thermal_zone0/temp ]; then
        echo "CPU Temp: $(cat /sys/class/thermal/thermal_zone0/temp)" > "$REPORT_DIR/device/temperature.txt"
    fi
    
    log "Device info collected"
}

# ── Collect system logs ────────────────────────────────────────────────
collect_logs() {
    log "Collecting system logs"
    
    mkdir -p "$REPORT_DIR/logs" 2>/dev/null
    
    # System log
    cat /var/log/messages > "$REPORT_DIR/logs/syslog.txt" 2>/dev/null
    
    # Kernel log
    dmesg > "$REPORT_DIR/logs/dmesg.txt" 2>/dev/null
    
    # Application logs
    for log_file in /tmp/*.log; do
        [ -f "$log_file" ] && cp "$log_file" "$REPORT_DIR/logs/" 2>/dev/null
    done
    
    # RetroArch logs
    find /mnt/SDCARD -name "retroarch.log" -type f 2>/dev/null | head -5 | while read -r log; do
        cp "$log" "$REPORT_DIR/logs/" 2>/dev/null
    done
    
    log "Logs collected"
}

# ── Collect configuration ──────────────────────────────────────────────
collect_config() {
    log "Collecting configuration"
    
    mkdir -p "$REPORT_DIR/config" 2>/dev/null
    
    # JukaMix config
    cp /mnt/SDCARD/System/etc/jukamix.json "$REPORT_DIR/config/" 2>/dev/null
    
    # Device profiles
    if [ -d /mnt/SDCARD/Profiles/DEVICE-OVERRIDES ]; then
        cp -r /mnt/SDCARD/Profiles/DEVICE-OVERRIDES "$REPORT_DIR/config/" 2>/dev/null
    fi
    
    # Compatibility database
    cp /mnt/SDCARD/System/usr/trimui/compatibility-db.txt "$REPORT_DIR/config/" 2>/dev/null
    
    # Device capabilities
    cp /mnt/SDCARD/System/usr/trimui/device-capabilities.txt "$REPORT_DIR/config/" 2>/dev/null
    
    log "Configuration collected"
}

# ── Collect game state ─────────────────────────────────────────────────
collect_game_state() {
    log "Collecting game state"
    
    mkdir -p "$REPORT_DIR/game" 2>/dev/null
    
    # Last played game
    cp /mnt/SDCARD/trimui/autosave/last_session.txt "$REPORT_DIR/game/" 2>/dev/null
    
    # Auto-resume state
    find /mnt/SDCARD/trimui/autosave -name "last_game.txt" -type f 2>/dev/null | head -5 | while read -r file; do
        cp "$file" "$REPORT_DIR/game/" 2>/dev/null
    done
    
    # Play history
    cp /mnt/SDCARD/trimui/play_history.csv "$REPORT_DIR/game/" 2>/dev/null
    
    log "Game state collected"
}

# ── Collect crash dumps ────────────────────────────────────────────────
collect_crash_dumps() {
    log "Collecting crash dumps"
    
    mkdir -p "$REPORT_DIR/crashes" 2>/dev/null
    
    # Core dumps
    find /tmp -name "core.*" -type f 2>/dev/null | head -5 | while read -r dump; do
        cp "$dump" "$REPORT_DIR/crashes/" 2>/dev/null
    done
    
    # Segfault logs
    grep -i "segfault\|signal\|abort" /var/log/messages 2>/dev/null > "$REPORT_DIR/crashes/segfaults.txt"
    
    log "Crash dumps collected"
}

# ── Generate report summary ────────────────────────────────────────────
generate_summary() {
    log "Generating report summary"
    
    cat > "$REPORT_DIR/SUMMARY.md" << EOF
# JukaMix OS Crash Report

## Date: $(date)

## Device Information
- Model: $(cat "$REPORT_DIR/device/model.txt" 2>/dev/null || echo "Unknown")
- Firmware: $(cat "$REPORT_DIR/device/firmware.txt" 2>/dev/null || echo "Unknown")
- Kernel: $(head -1 "$REPORT_DIR/device/kernel.txt" 2>/dev/null || echo "Unknown")

## System State
- Battery: $(grep "Capacity" "$REPORT_DIR/device/battery.txt" 2>/dev/null || echo "Unknown")
- Temperature: $(cat "$REPORT_DIR/device/temperature.txt" 2>/dev/null || echo "Unknown")
- Storage: $(df -h /mnt/SDCARD 2>/dev/null | tail -1 || echo "Unknown")

## Contents
- device/ - Device information
- logs/ - System and application logs
- config/ - JukaMix configuration
- game/ - Game state and history
- crashes/ - Crash dumps (if any)

## Report Generated By
JukaMix OS Crash Reporter
EOF
    
    log "Summary generated"
}

# ── Create archive ─────────────────────────────────────────────────────
create_archive() {
    output_path="${1:-$OUTPUT_DEFAULT}"
    
    mkdir -p "$output_path" 2>/dev/null
    
    archive_name="crash_report_$(date +%Y%m%d_%H%M%S).zip"
    archive_path="$output_path/$archive_name"
    
    # Create ZIP
    cd "$REPORT_DIR" && zip -r "$archive_path" . >/dev/null 2>&1
    
    log "Archive created: $archive_path"
    echo "Crash report saved: $archive_path"
    echo "Size: $(ls -lh "$archive_path" | awk '{print $5}')"
}

# ── Cleanup ────────────────────────────────────────────────────────────
cleanup() {
    rm -rf "$REPORT_DIR" 2>/dev/null
    log "Cleanup complete"
}

# ── Usage ──────────────────────────────────────────────────────────────
usage() {
    echo "Usage: crash_reporter.sh [output_path]"
    echo ""
    echo "Options:"
    echo "  output_path   Directory to save the report (default: /mnt/SDCARD/trimui/crash_reports)"
    echo ""
    echo "Example:"
    echo "  crash_reporter.sh"
    echo "  crash_reporter.sh /tmp/reports"
}

# ── Main ───────────────────────────────────────────────────────────────
main() {
    log "Starting crash report generation"
    
    # Collect all information
    collect_device_info
    collect_logs
    collect_config
    collect_game_state
    collect_crash_dumps
    generate_summary
    
    # Create archive
    create_archive "$1"
    
    # Cleanup
    cleanup
    
    log "Crash report complete"
}

# Run if called directly
if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    usage
    exit 0
fi

main "$@"
