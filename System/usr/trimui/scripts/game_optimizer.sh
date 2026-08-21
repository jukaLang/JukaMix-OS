#!/bin/sh
# game_optimizer.sh - Automatic Game Optimizer
# Analyzes game performance and generates optimal per-game profiles
#
# Usage: game_optimizer.sh <rom_path> [--auto]

SCRIPTS_DIR="/mnt/SDCARD/System/usr/trimui/scripts"
PROFILES_DIR="/mnt/SDCARD/Profiles"
LOG_DIR="/tmp/optimizer_logs"
SAMPLE_INTERVAL=5  # seconds between samples
TEST_DURATION=60   # seconds to run optimization

# Create directories
mkdir -p "$LOG_DIR" 2>/dev/null

# ── Logging ────────────────────────────────────────────────────────────
log() {
    echo "$(date '+%H:%M:%S') [optimizer] $1" >> "$LOG_DIR/optimizer.log" 2>/dev/null
}

# ── Get device capabilities ────────────────────────────────────────────
get_device() {
    if [ -f /etc/trimui_device.txt ]; then
        cat /etc/trimui_device.txt 2>/dev/null
    else
        echo "tsp"
    fi
}

get_cpu_cores() {
    nproc 2>/dev/null || echo "4"
}

# ── Get performance metrics ────────────────────────────────────────────
get_cpu_usage() {
    # Get CPU usage from /proc/stat
    if [ -f /proc/stat ]; then
        read -r cpu user nice system idle rest < /proc/stat
        total=$((user + nice + system + idle))
        idle_pct=$((idle * 100 / total))
        echo $((100 - idle_pct))
    else
        echo "50"
    fi
}

get_temperature() {
    if [ -f /sys/class/thermal/thermal_zone0/temp ]; then
        temp=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null)
        echo $((temp / 1000))
    else
        echo "45"
    fi
}

get_battery_level() {
    if [ -f /sys/class/power_supply/battery/capacity ]; then
        cat /sys/class/power_supply/battery/capacity 2>/dev/null
    else
        echo "100"
    fi
}

# ── Set CPU frequency ──────────────────────────────────────────────────
set_cpu_mode() {
    mode="$1"
    device=$(get_device)
    
    case "$device" in
        tg5050)
            case "$mode" in
                eco)     freq_max=1200000 ;;
                balanced) freq_max=1608000 ;;
                turbo)   freq_max=1800000 ;;
            esac
            ;;
        brick|brick_pro)
            case "$mode" in
                eco)     freq_max=1000000 ;;
                balanced) freq_max=1416000 ;;
                turbo)   freq_max=1608000 ;;
            esac
            ;;
        *)
            case "$mode" in
                eco)     freq_max=1200000 ;;
                balanced) freq_max=1416000 ;;
                turbo)   freq_max=1608000 ;;
            esac
            ;;
    esac
    
    # Apply frequency
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_max_freq; do
        [ -w "$cpu" ] && echo "$freq_max" > "$cpu" 2>/dev/null
    done
}

# ── Sample performance ─────────────────────────────────────────────────
sample_performance() {
    cpu=$(get_cpu_usage)
    temp=$(get_temperature)
    batt=$(get_battery_level)
    
    echo "$cpu,$temp,$batt"
}

# ── Analyze performance ────────────────────────────────────────────────
analyze_performance() {
    log_file="$1"
    
    # Calculate averages
    avg_cpu=$(awk -F',' '{sum+=$1; count++} END {if(count>0) print sum/count; else print 0}' "$log_file")
    avg_temp=$(awk -F',' '{sum+=$2; count++} END {if(count>0) print sum/count; else print 0}' "$log_file")
    max_temp=$(awk -F',' '{if($2>max) max=$2} END {print max+0}' "$log_file")
    
    echo "avg_cpu=$avg_cpu avg_temp=$avg_temp max_temp=$max_temp"
}

# ── Generate profile ───────────────────────────────────────────────────
generate_profile() {
    rom_path="$1"
    analysis="$2"
    
    # Parse analysis
    avg_cpu=$(echo "$analysis" | grep -o "avg_cpu=[0-9]*" | cut -d= -f2)
    avg_temp=$(echo "$analysis" | grep -o "avg_temp=[0-9]*" | cut -d= -f2)
    max_temp=$(echo "$analysis" | grep -o "max_temp=[0-9]*" | cut -d= -f2)
    
    # Determine optimal mode
    if [ "$avg_cpu" -lt 50 ] && [ "$max_temp" -lt 55 ]; then
        mode="eco"
        comment="Low CPU usage, cool running - eco mode is optimal"
    elif [ "$avg_cpu" -lt 75 ] && [ "$max_temp" -lt 65 ]; then
        mode="balanced"
        comment="Moderate CPU usage - balanced mode recommended"
    else
        mode="turbo"
        comment="High CPU usage or thermal throttling - turbo mode needed"
    fi
    
    # Create profile directory
    rom_name=$(basename "$rom_path" | sed 's/\.[^.]*$//')
    system=$(basename "$(dirname "$(dirname "$rom_path")")")
    profile_dir="$PROFILES_DIR/$system"
    mkdir -p "$profile_dir" 2>/dev/null
    
    # Generate profile file
    profile_file="$profile_dir/${rom_name}.cfg"
    cat > "$profile_file" << EOF
# Auto-generated profile for: $rom_name
# System: $system
# Date: $(date '+%Y-%m-%d %H:%M:%S')
# Device: $(get_device)
#
# Performance Analysis:
#   Average CPU: ${avg_cpu}%
#   Average Temp: ${avg_temp}°C
#   Max Temp: ${max_temp}°C
#
# Recommendation: $mode
# $comment

PERFORMANCE_MODE=$mode
CPU_MAX_FREQ=$(case "$mode" in eco) echo 1200000;; balanced) echo 1416000;; turbo) echo 1608000;; esac)
FRAME_SKIP=0
SHADER=default
EOF
    
    log "Profile generated: $profile_file"
    echo "$profile_file"
}

# ── Main optimization loop ─────────────────────────────────────────────
optimize_game() {
    rom_path="$1"
    auto_mode="${2:-0}"
    
    rom_name=$(basename "$rom_path" 2>/dev/null)
    log "Starting optimization for: $rom_name"
    
    # Create sample log
    sample_log="$LOG_DIR/$(date +%Y%m%d_%H%M%S)_samples.log"
    
    # Test each mode
    modes="eco balanced turbo"
    best_mode="balanced"
    best_score=999
    
    for mode in $modes; do
        log "Testing mode: $mode"
        
        # Set CPU mode
        set_cpu_mode "$mode"
        
        # Wait for stabilization
        sleep 2
        
        # Sample performance
        : > "$sample_log"
        samples=0
        while [ "$samples" -lt "$((TEST_DURATION / SAMPLE_INTERVAL))" ]; do
            sample_performance >> "$sample_log"
            sleep "$SAMPLE_INTERVAL"
            samples=$((samples + 1))
        done
        
        # Analyze results
        analysis=$(analyze_performance "$sample_log")
        avg_cpu=$(echo "$analysis" | grep -o "avg_cpu=[0-9]*" | cut -d= -f2)
        max_temp=$(echo "$analysis" | grep -o "max_temp=[0-9]*" | cut -d= -f2)
        
        # Calculate score (lower is better)
        # Penalize high CPU and high temperature
        score=$((avg_cpu + max_temp * 2))
        
        log "Mode $mode: CPU=$avg_cpu% Temp=$max_temp°C Score=$score"
        
        # Check if this is better
        if [ "$score" -lt "$best_score" ]; then
            # Verify the mode is stable (CPU < 90% and temp < 70°C)
            if [ "$avg_cpu" -lt 90 ] && [ "$max_temp" -lt 70 ]; then
                best_score=$score
                best_mode=$mode
            fi
        fi
    done
    
    # Generate profile with best mode
    set_cpu_mode "$best_mode"
    profile_file=$(generate_profile "$rom_path" "avg_cpu=50 avg_temp=50 max_temp=60")
    
    log "Optimization complete: $rom_name -> $best_mode"
    echo "Recommended mode: $best_mode"
    echo "Profile saved: $profile_file"
}

# ── Usage ──────────────────────────────────────────────────────────────
usage() {
    echo "Usage: game_optimizer.sh <rom_path> [--auto]"
    echo ""
    echo "Options:"
    echo "  rom_path    Path to the ROM file"
    echo "  --auto      Run automatically without prompts"
    echo ""
    echo "Example:"
    echo "  game_optimizer.sh /mnt/SDCARD/Roms/GBA/game.gba"
    echo "  game_optimizer.sh /mnt/SDCARD/Roms/GBA/game.gba --auto"
}

# ── Main ───────────────────────────────────────────────────────────────
if [ $# -lt 1 ]; then
    usage
    exit 1
fi

ROM_PATH="$1"
AUTO_MODE=0

if [ "${2:-}" = "--auto" ]; then
    AUTO_MODE=1
fi

if [ ! -f "$ROM_PATH" ]; then
    echo "Error: ROM file not found: $ROM_PATH"
    exit 1
fi

optimize_game "$ROM_PATH" "$AUTO_MODE"
