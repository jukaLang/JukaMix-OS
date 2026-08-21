#!/bin/sh
# gpu_reset.sh - Reset GPU settings to fix black screen issues
#
# Usage:
#   ./gpu_reset.sh          # Reset GPU to defaults
#   ./gpu_reset.sh --status # Show current GPU status

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[GPU]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[GPU]${NC} $*"; }
log_error() { echo -e "${RED}[GPU]${NC} $*" >&2; }

# Get device code
get_device() {
    if [ -r /etc/trimui_device.txt ]; then
        tr -d '[:space:]' < /etc/trimui_device.txt 2>/dev/null | head -n 1
    else
        echo "unknown"
    fi
}

# Show GPU status
show_status() {
    local device=$(get_device)
    
    echo "=== GPU Status ==="
    echo "Device: $device"
    echo ""
    
    # Check GPU info
    if [ -f /sys/class/misc/mali0/device/gpuinfo ]; then
        echo "GPU Info: $(cat /sys/class/misc/mali0/device/gpuinfo 2>/dev/null)"
    fi
    
    # Check GPU frequency
    if [ -f /sys/class/misc/mali0/device/cur_freq ]; then
        echo "Current Freq: $(cat /sys/class/misc/mali0/device/cur_freq 2>/dev/null)"
    fi
    
    # Check GPU utilization
    if [ -f /sys/class/misc/mali0/device/utilization ]; then
        echo "GPU Utilization: $(cat /sys/class/misc/mali0/device/utilization 2>/dev/null)"
    fi
    
    # Check frame buffer
    echo ""
    echo "Frame Buffer:"
    fbset 2>/dev/null | head -5
    
    # Check OpenGL renderer
    echo ""
    echo "OpenGL Renderer:"
    glxinfo 2>/dev/null | grep "OpenGL renderer" || echo "glxinfo not available"
}

# Reset GPU settings
reset_gpu() {
    local device=$(get_device)
    
    log_info "Resetting GPU settings for $device..."
    
    # Kill any running GPU-related processes
    log_info "Stopping GPU processes..."
    killall -9 malitraits 2>/dev/null || true
    killall -9 mali* 2>/dev/null || true
    
    # Reset GPU frequency to default
    log_info "Resetting GPU frequency..."
    case "$device" in
        tg5050)
            # TG5050: Mali-G57
            echo performance > /sys/class/misc/mali0/device/devfreq/governor 2>/dev/null || true
            echo 600000 > /sys/class/misc/mali0/device/devfreq/min_freq 2>/dev/null || true
            echo 850000 > /sys/class/misc/mali0/device/devfreq/max_freq 2>/dev/null || true
            ;;
        tsp|brick|brick_pro|brickpro)
            # TSP/Brick: Mali-G31
            echo performance > /sys/class/misc/mali0/device/devfreq/governor 2>/dev/null || true
            echo 408000 > /sys/class/misc/mali0/device/devfreq/min_freq 2>/dev/null || true
            echo 600000 > /sys/class/misc/mali0/device/devfreq/max_freq 2>/dev/null || true
            ;;
    esac
    
    # Reset frame buffer
    log_info "Resetting frame buffer..."
    fbset -a -depth 32 2>/dev/null || true
    
    # Clear GPU cache
    log_info "Clearing GPU cache..."
    sync
    
    # Reset OpenGL settings
    log_info "Resetting OpenGL settings..."
    rm -rf /tmp/mali* 2>/dev/null || true
    rm -rf /var/tmp/mali* 2>/dev/null || true
    
    # Restart display manager if running
    log_info "Restarting display..."
    if pgrep -f "presenter" >/dev/null; then
        killall -9 presenter 2>/dev/null || true
        sleep 0.5
    fi
    
    log_info "GPU reset complete"
    log_info "You may need to restart the device for full effect"
}

# Main
main() {
    case "${1:-}" in
        --status|-s)
            show_status
            exit 0
            ;;
        --help|-h)
            echo "Usage: $0 [--status|--help]"
            echo ""
            echo "Options:"
            echo "  --status, -s   Show current GPU status"
            echo "  --help, -h     Show this help"
            exit 0
            ;;
    esac
    
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}   GPU Reset Tool${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    
    reset_gpu
}

main "$@"
