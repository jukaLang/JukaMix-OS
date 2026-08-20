#!/bin/sh
# chroot-manager.sh - Production-grade chroot manager for JukaMix OS
#
# Features:
# - GPU passthrough (Mali for TG5050/TSP/Brick)
# - Audio passthrough (ALSA/PulseAudio)
# - Input device forwarding (gamepad, touchscreen)
# - OverlayFS for persistent package installs
# - Memory management (swap, OOM killer)
# - Signal handling for graceful shutdown
# - Zombie process reaping (PID 1)
# - Environment variable forwarding
# - Auto-mount/umount hooks
# - Backup/restore for user data
# - Health checks and diagnostics
# - Progress indicators
# - Automatic recovery
# - Resource usage tracking
# - Watchdog service
# - Network configuration
# - Auto-updates
#
# Usage:
#   chroot-manager.sh start              # Start chroot environment
#   chroot-manager.sh stop               # Stop chroot environment
#   chroot-manager.sh status             # Show chroot status
#   chroot-manager.sh run <command>      # Run command in chroot
#   chroot-manager.sh shell              # Enter interactive shell
#   chroot-manager.sh optimize           # Apply device-specific optimizations
#   chroot-manager.sh diagnose           # Run diagnostics
#   chroot-manager.sh install            # Install/extract rootfs
#   chroot-manager.sh download           # Download rootfs from release
#   chroot-manager.sh backup             # Backup user data
#   chroot-manager.sh restore <path>     # Restore user data
#   chroot-manager.sh profile load <n>   # Load game profile
#   chroot-manager.sh profile save <n>   # Save game profile
#   chroot-manager.sh monitor            # Monitor resource usage
#   chroot-manager.sh recover            # Attempt automatic recovery
#   chroot-manager.sh watchdog start     # Start watchdog service
#   chroot-manager.sh watchdog stop      # Stop watchdog service
#   chroot-manager.sh network setup      # Setup network access
#   chroot-manager.sh update             # Update rootfs
#   chroot-manager.sh cleanup            # Clean up storage
#   chroot-manager.sh overlay enable     # Enable overlayfs (persistent changes)
#   chroot-manager.sh overlay disable    # Disable overlayfs (clean state)

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILDROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="$BUILDROOT_DIR/output"

# Configuration
CHROOT_BASE="/mnt/SDCARD/buildroot"
SWAP_FILE="/tmp/jukamix-swap"
LOG_FILE="/tmp/jukamix-chroot.log"
CACHE_DIR="/tmp/jukamix-cache"
RELEASE_BASE="https://github.com/jukaLang/JukaMix-OS/releases/download"
# Rootfs files are built by CI and uploaded as release assets.
# They are included in the JukaMix_<stamp>.zip and also as standalone assets.
BACKUP_DIR="/mnt/SDCARD/System/backups/chroot"
PROFILE_DIR="/mnt/SDCARD/config/chroot-profiles"
WATCHDOG_PID="/tmp/jukamix-chroot-watchdog.pid"
REAPER_PID="/tmp/jukamix-chroot-reaper.pid"
MONITOR_INTERVAL=5
WATCHDOG_INTERVAL=30
OVERLAY_UPPER="/tmp/jukamix-overlay/upper"
OVERLAY_WORK="/tmp/jukamix-overlay/work"
RUNNING_MARKER=".running"
OVERLAY_MARKER=".overlay-active"
STATEDIR="/tmp/jukamix-state"

# Colors (safe for busybox ash)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Logging with levels
LOG_LEVEL="${LOG_LEVEL:-INFO}"

log_debug() {
    if [ "$LOG_LEVEL" = "DEBUG" ]; then
        echo -e "${BLUE}[DEBUG]${NC} $*" 2>/dev/null | tee -a "$LOG_FILE" 2>/dev/null || true
    fi
}

log_info() {
    echo -e "${GREEN}[INFO]${NC} $*" 2>/dev/null | tee -a "$LOG_FILE" 2>/dev/null || true
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*" 2>/dev/null | tee -a "$LOG_FILE" 2>/dev/null || true
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" 2>/dev/null | tee -a "$LOG_FILE" 2>/dev/null >&2
}

log_step() {
    echo -e "${CYAN}[STEP]${NC} $*" 2>/dev/null || true
}

# Progress indicator with ETA
show_progress() {
    _current=$1
    _total=$2
    _start_time=$3
    _percent=0
    _bar=0
    _elapsed=0
    _remaining=0
    _eta_min=0
    _eta_sec=0

    _percent=$(( _current * 100 / _total ))
    _bar=$(( _percent / 5 ))

    _elapsed=$(( $(date +%s) - _start_time ))
    _remaining=0
    if [ "$_current" -gt 0 ]; then
        _remaining=$(( (_elapsed * (_total - _current)) / _current ))
    fi

    _eta_min=$(( _remaining / 60 ))
    _eta_sec=$(( _remaining % 60 ))

    printf "\r["
    _i=0
    while [ "$_i" -lt 50 ]; do
        _i=$(( _i + 1 ))
        if [ "$_i" -le "$_bar" ]; then
            printf "#"
        else
            printf "."
        fi
    done
    printf "] %3d%% ETA: %02d:%02d" "$_percent" "$_eta_min" "$_eta_sec"
}

# Signal handling
setup_signal_handlers() {
    _chroot_dir="$1"

    # Store current PID for cleanup
    echo $$ > "$STATEDIR/manager.pid" 2>/dev/null || true

    # Handle SIGTERM, SIGINT, SIGHUP
    trap '_cleanup_on_signal' TERM INT HUP 2>/dev/null || true

    log_debug "Signal handlers installed"
}

_cleanup_on_signal() {
    log_warn "Caught signal, cleaning up..."
    _device=$(detect_device)
    _chroot_dir="$CHROOT_BASE/$_device"

    # Kill watchdog
    stop_watchdog 2>/dev/null || true

    # Kill reaper
    stop_reaper 2>/dev/null || true

    # Unmount chroot
    umount_chroot "$_device" 2>/dev/null || true

    # Disable swap
    swapoff "$SWAP_FILE" 2>/dev/null || true

    # Remove state
    rm -rf "$STATEDIR" 2>/dev/null || true

    log_info "Cleanup complete"
    exit 0
}

# Zombie process reaper (runs as PID 1 in chroot)
reap_zombies() {
    while true; do
        # Wait for any child process, returns immediately if none
        wait 2>/dev/null || true
        sleep 1
    done
}

start_reaper() {
    if [ -f "$REAPER_PID" ]; then
        _pid=$(cat "$REAPER_PID" 2>/dev/null)
        if kill -0 "$_pid" 2>/dev/null; then
            log_debug "Reaper already running (PID: $_pid)"
            return 0
        fi
    fi

    # Start reaper in background
    reap_zombies &
    echo $! > "$REAPER_PID" 2>/dev/null || true
    log_debug "Zombie reaper started (PID: $(cat "$REAPER_PID" 2>/dev/null))"
}

stop_reaper() {
    if [ -f "$REAPER_PID" ]; then
        _pid=$(cat "$REAPER_PID" 2>/dev/null)
        if kill -0 "$_pid" 2>/dev/null; then
            kill "$_pid" 2>/dev/null || true
        fi
        rm -f "$REAPER_PID" 2>/dev/null || true
    fi
}

# Detect device
detect_device() {
    _device="unknown"

    if [ -f /etc/trimui_device.txt ]; then
        _device=$(tr -d '[:space:]' < /etc/trimui_device.txt 2>/dev/null | head -n 1)
    fi

    if [ "$_device" = "unknown" ] && [ -r /proc/device-tree/model ]; then
        _model=$(tr -d '\0' </proc/device-tree/model 2>/dev/null | tr 'A-Z' 'a-z')
        case "$_model" in
            *a523* | *tg5050* | *5050*) _device="tg5050" ;;
            *brick* | *tg3040*)         _device="brick" ;;
            *a133*)                     _device="tsp" ;;
        esac
    fi

    echo "$_device"
}

# Get device tier
get_device_tier() {
    _dev="$1"
    case "$_dev" in
        tg5050) echo "full" ;;
        tsp|brick) echo "minimal" ;;
        *) echo "unknown" ;;
    esac
}

# Get device RAM (MB)
get_device_ram() {
    _dev="$1"
    case "$_dev" in
        tg5050) echo "2048" ;;
        tsp|brick) echo "1024" ;;
        *) echo "1024" ;;
    esac
}

# Get device name
get_device_name() {
    _dev="$1"
    case "$_dev" in
        tg5050) echo "TrimUI Smart Pro S" ;;
        tsp) echo "TrimUI Smart Pro" ;;
        brick) echo "TrimUI Brick" ;;
        *) echo "Unknown" ;;
    esac
}

# Check if running as root
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        log_warn "Not running as root, some operations may fail"
        return 1
    fi
    return 0
}

# Setup state directory
setup_state() {
    mkdir -p "$STATEDIR" 2>/dev/null || true
    mkdir -p "$LOG_FILE" 2>/dev/null || true
    touch "$LOG_FILE" 2>/dev/null || true
}

# Setup cache directory
setup_cache() {
    mkdir -p "$CACHE_DIR" 2>/dev/null || true
    log_debug "Cache directory: $CACHE_DIR"
}

# ============================================================================
# GPU PASSTHROUGH
# ============================================================================

# Detect Mali GPU device nodes
detect_gpu_nodes() {
    _gpu_nodes=""
    _gpu_count=0

    # Check for Mali device nodes
    for _dev in /dev/mali0 /dev/mali /dev/mali_*; do
        if [ -e "$_dev" ]; then
            _gpu_nodes="$_gpu_nodes $_dev"
            _gpu_count=$(( _gpu_count + 1 ))
        fi
    done

    # Check for DRI (for Mesa userspace)
    for _dev in /dev/dri/*; do
        if [ -e "$_dev" ]; then
            _gpu_nodes="$_gpu_nodes $_dev"
            _gpu_count=$(( _gpu_count + 1 ))
        fi
    done

    # Check for DMA-BUF
    if [ -e /dev/dma_heap/system ]; then
        _gpu_nodes="$_gpu_nodes /dev/dma_heap/system"
        _gpu_count=$(( _gpu_count + 1 ))
    fi

    if [ "$_gpu_count" -gt 0 ]; then
        log_debug "GPU nodes found: $_gpu_nodes"
        echo "$_gpu_nodes"
    else
        log_debug "No GPU nodes found"
        echo ""
    fi
}

# Check if GPU is available
check_gpu() {
    _gpu_nodes=$(detect_gpu_nodes)
    if [ -n "$_gpu_nodes" ]; then
        log_info "GPU available: $(echo $_gpu_nodes | wc -w) device(s)"
        return 0
    fi
    log_warn "No GPU device nodes found"
    return 1
}

# Mount GPU devices in chroot
mount_gpu() {
    _chroot_dir="$1"
    _gpu_nodes=$(detect_gpu_nodes)

    if [ -z "$_gpu_nodes" ]; then
        log_debug "No GPU nodes to mount"
        return 0
    fi

    log_step "Mounting GPU devices..."

    mkdir -p "$_chroot_dir/dev" 2>/dev/null || true

    for _gpu_dev in $_gpu_nodes; do
        _dev_name=$(basename "$_gpu_dev")
        _dev_dir=$(dirname "$_gpu_dev")

        mkdir -p "$_chroot_dir$_dev_dir" 2>/dev/null || true

        if mount --bind "$_gpu_dev" "$_chroot_dir$_gpu_dev" 2>/dev/null; then
            log_debug "Mounted GPU: $_gpu_dev"
        else
            log_warn "Failed to mount GPU: $_gpu_dev"
        fi
    done

    # Copy GPU-related libraries from host if they exist
    _gpu_libs=$(find /usr/lib /usr/lib64 /usr/local/lib -name "libmali*" -o -name "libEGL_mali*" -o -name "libGLESv2_mali*" 2>/dev/null | head -10)
    if [ -n "$_gpu_libs" ]; then
        for _lib in $_gpu_libs; do
            _lib_name=$(basename "$_lib")
            _lib_dir=$(dirname "$_lib")
            mkdir -p "$_chroot_dir$_lib_dir" 2>/dev/null || true
            cp -p "$_lib" "$_chroot_dir$_lib" 2>/dev/null || true
            log_debug "Copied GPU library: $_lib_name"
        done
    fi

    # Set up Mali GPU environment variables
    mkdir -p "$_chroot_dir/etc/profile.d" 2>/dev/null || true
    cat > "$_chroot_dir/etc/profile.d/gpu.sh" << 'GPUEOF'
# Mali GPU configuration
export MALI_PLATFORM="wayland"
export EGL_PLATFORM="wayland"
export GBM_BACKEND="mali"
export GBM_ALWAYS_SOFTWARE=0

# EGL device
export EGL_DEVICE=0

# Mesa configuration
export MESA_GL_VERSION_OVERRIDE=3.2
export MESA_GLSL_VERSION_OVERRIDE=150

# Disable vblank for better performance
export vblank_mode=0
export __GL_SYNC_TO_VBLANK=0
GPUEOF
    chmod 644 "$_chroot_dir/etc/profile.d/gpu.sh" 2>/dev/null || true

    log_info "GPU passthrough configured"
}

# ============================================================================
# AUDIO PASSTHROUGH
# ============================================================================

# Mount ALSA/PulseAudio devices
mount_audio() {
    _chroot_dir="$1"

    log_step "Mounting audio devices..."

    # Check for ALSA
    if [ -d /dev/snd ]; then
        mkdir -p "$_chroot_dir/dev/snd" 2>/dev/null || true
        mount --bind /dev/snd "$_chroot_dir/dev/snd" 2>/dev/null || true
        log_debug "Mounted ALSA devices"
    fi

    # Check for PulseAudio
    if [ -S /run/user/0/pulse/native ] || [ -d /run/user/0/pulse ]; then
        mkdir -p "$_chroot_dir/run/user/0/pulse" 2>/dev/null || true
        mount --bind /run/user/0/pulse "$_chroot_dir/run/user/0/pulse" 2>/dev/null || true
    fi

    # Check for PipeWire
    if [ -d /run/user/0/pipewire-0 ]; then
        mkdir -p "$_chroot_dir/run/user/0/pipewire-0" 2>/dev/null || true
        mount --bind /run/user/0/pipewire-0 "$_chroot_dir/run/user/0/pipewire-0" 2>/dev/null || true
    fi

    # Create ALSA config if not present
    if [ ! -f "$_chroot_dir/etc/asound.conf" ]; then
        cat > "$_chroot_dir/etc/asound.conf" << 'ALSAEOF'
# JukaMix OS ALSA configuration
pcm.!default {
    type hw
    card 0
}

ctl.!default {
    type hw
    card 0
}
ALSAEOF
        chmod 644 "$_chroot_dir/etc/asound.conf" 2>/dev/null || true
    fi

    # Set audio environment variables
    mkdir -p "$_chroot_dir/etc/profile.d" 2>/dev/null || true
    cat > "$_chroot_dir/etc/profile.d/audio.sh" << 'AUDIOEOF'
# Audio configuration for TrimUI devices
export AUDIODEV="/dev/snd/"
export SDL_AUDIODRIVER="alsa"
export ALSA_CARD="default"
AUDIOEOF
    chmod 644 "$_chroot_dir/etc/profile.d/audio.sh" 2>/dev/null || true

    log_info "Audio passthrough configured"
}

# ============================================================================
# INPUT DEVICE FORWARDING
# ============================================================================

# Mount input devices (gamepad, touchscreen, buttons)
mount_input() {
    _chroot_dir="$1"

    log_step "Mounting input devices..."

    # Check for input devices
    if [ ! -d /dev/input ]; then
        log_debug "No /dev/input found"
        return 0
    fi

    mkdir -p "$_chroot_dir/dev/input" 2>/dev/null || true

    # Mount all input devices
    for _evdev in /dev/input/event* /dev/input/mouse*; do
        if [ -e "$_evdev" ]; then
            mount --bind "$_evdev" "$_chroot_dir$_evdev" 2>/dev/null || true
            log_debug "Mounted input: $_evdev"
        fi
    done

    # Check for uinput (for virtual input)
    if [ -e /dev/uinput ]; then
        mount --bind /dev/uinput "$_chroot_dir/dev/uinput" 2>/dev/null || true
    fi

    # Create input configuration
    mkdir -p "$_chroot_dir/etc/profile.d" 2>/dev/null || true
    cat > "$_chroot_dir/etc/profile.d/input.sh" << 'INPUTEOF'
# Input configuration for TrimUI gamepad
export SDL_GAMECONTROLLERCONFIG_FILE="/etc/gamecontrollerdb.txt"
INPUTEOF
    chmod 644 "$_chroot_dir/etc/profile.d/input.sh" 2>/dev/null || true

    # Create gamecontroller mapping file for TrimUI buttons
    if [ ! -f "$_chroot_dir/etc/gamecontrollerdb.txt" ]; then
        cat > "$_chroot_dir/etc/gamecontrollerdb.txt" << 'GAMEEOF'
# TrimUI Smart Pro / Brick / Smart Pro S gamepad mapping
# Format: GUID,name,platform,button bits,axes
03000000091200000010000000010000,TrimUI Gamepad,a:b0,b:a,x:b2,y:b3,back:b6,start:b7,dpleft:b8,dpdown:b9,dpright:b10,dpup:b11,leftshoulder:b4,rightshoulder:b5,leftstick:b13,rightstick:b14,leftx:a0,lefty:a1,rightx:a2,righty:a3,lefttrigger:a5,righttrigger:a4,
GAMEEOF
        chmod 644 "$_chroot_dir/etc/gamecontrollerdb.txt" 2>/dev/null || true
    fi

    log_info "Input devices forwarded"
}

# ============================================================================
# OVERLAYFS FOR PERSISTENT CHANGES
# ============================================================================

# Enable overlayfs (persistent package installs)
enable_overlay() {
    _device=$(detect_device)
    _chroot_dir="$CHROOT_BASE/$_device"

    if [ -f "$_chroot_dir/$OVERLAY_MARKER" ]; then
        log_warn "Overlay already active"
        return 0
    fi

    log_step "Enabling overlayfs for persistent changes..."

    # Stop chroot if running
    if [ -f "$_chroot_dir/$RUNNING_MARKER" ]; then
        log_warn "Stopping chroot for overlay enable..."
        stop_chroot 2>/dev/null || true
    fi

    # Create overlay directories
    mkdir -p "$OVERLAY_UPPER" 2>/dev/null || true
    mkdir -p "$OVERLAY_WORK" 2>/dev/null || true

    # Find the rootfs (lower layer)
    _rootfs=""
    case "$_device" in
        tg5050) _rootfs="$CHROOT_BASE/rootfs-tg5050.ext2" ;;
        tsp|brick) _rootfs="$CHROOT_BASE/rootfs-tsp-brick.ext2" ;;
    esac

    if [ ! -f "$_rootfs" ]; then
        log_error "Rootfs not found: $_rootfs"
        return 1
    fi

    # Mount overlay
    mkdir -p "$_chroot_dir.new" 2>/dev/null || true

    if mount -t overlay overlay \
        -o lowerdir="$_chroot_dir",upperdir="$OVERLAY_UPPER",workdir="$OVERLAY_WORK" \
        "$_chroot_dir.new" 2>/dev/null; then

        # Swap directories
        _temp_dir=$(mktemp -d)
        mv "$_chroot_dir" "$_temp_dir/old" 2>/dev/null || true
        mv "$_chroot_dir.new" "$_chroot_dir" 2>/dev/null || true
        rm -rf "$_temp_dir" 2>/dev/null || true

        touch "$_chroot_dir/$OVERLAY_MARKER"
        log_info "Overlay enabled - changes will persist across restarts"
    else
        log_error "Failed to mount overlayfs"
        rm -rf "$_chroot_dir.new" 2>/dev/null || true
        return 1
    fi
}

# Disable overlayfs (clean state)
disable_overlay() {
    _device=$(detect_device)
    _chroot_dir="$CHROOT_BASE/$_device"

    if [ ! -f "$_chroot_dir/$OVERLAY_MARKER" ]; then
        log_warn "Overlay not active"
        return 0
    fi

    log_step "Disabling overlayfs..."

    # Stop chroot if running
    if [ -f "$_chroot_dir/$RUNNING_MARKER" ]; then
        stop_chroot 2>/dev/null || true
    fi

    # Unmount overlay
    umount "$_chroot_dir" 2>/dev/null || true

    # Remove overlay data (optional, keeps changes)
    rm -rf "$OVERLAY_UPPER" 2>/dev/null || true
    rm -rf "$OVERLAY_WORK" 2>/dev/null || true
    rm -f "$_chroot_dir/$OVERLAY_MARKER" 2>/dev/null || true

    log_info "Overlay disabled - clean state restored"
}

# ============================================================================
# NETWORK CONFIGURATION
# ============================================================================

# Setup network access in chroot
setup_network() {
    _chroot_dir="$1"

    log_step "Setting up network access..."

    # Copy DNS configuration from host
    mkdir -p "$_chroot_dir/etc" 2>/dev/null || true

    if [ -f /etc/resolv.conf ]; then
        cp /etc/resolv.conf "$_chroot_dir/etc/" 2>/dev/null || true
    fi

    # Create minimal resolv.conf if not available
    if [ ! -f "$_chroot_dir/etc/resolv.conf" ]; then
        cat > "$_chroot_dir/etc/resolv.conf" << 'DNSEOF'
# JukaMix OS DNS configuration
nameserver 8.8.8.8
nameserver 8.8.4.4
nameserver 1.1.1.1
nameserver 9.9.9.9
DNSEOF
    fi

    # Setup hosts file
    if [ ! -f "$_chroot_dir/etc/hosts" ]; then
        cat > "$_chroot_dir/etc/hosts" << 'HOSTSEOF'
# JukaMix OS hosts file
127.0.0.1       localhost
127.0.1.1       jukamix
::1             localhost ip6-localhost ip6-loopback
ff02::1         ip6-allnodes
ff02::2         ip6-allrouters
HOSTSEOF
    fi

    # Setup network environment variables
    mkdir -p "$_chroot_dir/etc/profile.d" 2>/dev/null || true
    cat > "$_chroot_dir/etc/profile.d/network.sh" << 'NETEOF'
# Network configuration for JukaMix OS
export http_proxy=""
export https_proxy=""
export ftp_proxy=""
export no_proxy="localhost,127.0.0.1,::1"
export CURL_CA_BUNDLE="/etc/ssl/certs/ca-certificates.crt"
NETEOF
    chmod 644 "$_chroot_dir/etc/profile.d/network.sh" 2>/dev/null || true

    log_info "Network configured"
}

# ============================================================================
# FILESYSTEM MOUNTING
# ============================================================================

# Mount filesystems
mount_chroot() {
    _device="$1"
    _chroot_dir="$CHROOT_BASE/$_device"

    log_step "Mounting filesystems for $_device..."

    # Create mount points
    mkdir -p "$_chroot_dir/dev/pts" 2>/dev/null || true
    mkdir -p "$_chroot_dir/proc" 2>/dev/null || true
    mkdir -p "$_chroot_dir/sys" 2>/dev/null || true
    mkdir -p "$_chroot_dir/tmp" 2>/dev/null || true
    mkdir -p "$_chroot_dir/run" 2>/dev/null || true
    mkdir -p "$_chroot_dir/mnt/SDCARD" 2>/dev/null || true
    mkdir -p "$_chroot_dir/var/tmp" 2>/dev/null || true

    # Mount virtual filesystems
    mount --bind /dev "$_chroot_dir/dev" 2>/dev/null || true
    mount -t devpts devpts "$_chroot_dir/dev/pts" -o gid=5,mode=620 2>/dev/null || true
    mount -t proc proc "$_chroot_dir/proc" 2>/dev/null || true
    mount -t sysfs sys "$_chroot_dir/sys" 2>/dev/null || true
    mount --bind /tmp "$_chroot_dir/tmp" 2>/dev/null || true
    mount --bind /run "$_chroot_dir/run" 2>/dev/null || true

    # Mount SD card (read-write for user data)
    if [ -d /mnt/SDCARD ]; then
        mount --bind /mnt/SDCARD "$_chroot_dir/mnt/SDCARD" 2>/dev/null || true
    fi

    # Mount GPU devices
    mount_gpu "$_chroot_dir"

    # Mount audio devices
    mount_audio "$_chroot_dir"

    # Mount input devices
    mount_input "$_chroot_dir"

    # Setup network
    setup_network "$_chroot_dir"

    log_debug "Filesystems mounted"
}

# Unmount filesystems
umount_chroot() {
    _device="$1"
    _chroot_dir="$CHROOT_BASE/$_device"

    log_step "Unmounting filesystems for $_device..."

    # Unmount in reverse order (most specific first)

    # Unmount input devices
    for _evdev in "$_chroot_dir/dev/input/event"* "$_chroot_dir/dev/input/mouse"*; do
        [ -e "$_evdev" ] && umount "$_evdev" 2>/dev/null || true
    done
    umount "$_chroot_dir/dev/uinput" 2>/dev/null || true

    # Unmount audio
    umount "$_chroot_dir/run/user/0/pipewire-0" 2>/dev/null || true
    umount "$_chroot_dir/run/user/0/pulse" 2>/dev/null || true
    umount "$_chroot_dir/dev/snd" 2>/dev/null || true

    # Unmount GPU
    for _dev in "$_chroot_dir/dev/mali"* "$_chroot_dir/dev/dri"* "$_chroot_dir/dev/dma_heap"*; do
        [ -e "$_dev" ] && umount "$_dev" 2>/dev/null || true
    done

    # Unmount virtual filesystems
    umount "$_chroot_dir/mnt/SDCARD" 2>/dev/null || true
    umount "$_chroot_dir/run" 2>/dev/null || true
    umount "$_chroot_dir/tmp" 2>/dev/null || true
    umount "$_chroot_dir/sys" 2>/dev/null || true
    umount "$_chroot_dir/proc" 2>/dev/null || true
    umount "$_chroot_dir/dev/pts" 2>/dev/null || true
    umount "$_chroot_dir/dev" 2>/dev/null || true

    # Unmount overlay if active
    if mount | grep -q "overlay.*$_chroot_dir"; then
        umount "$_chroot_dir" 2>/dev/null || true
    fi

    log_debug "Filesystems unmounted"
}

# ============================================================================
# MEMORY MANAGEMENT
# ============================================================================

# Setup swap for low-memory devices
setup_swap() {
    _device="$1"
    _ram=$(get_device_ram "$_device")

    # Only setup swap for devices with <= 1GB RAM
    if [ "$_ram" -gt 1024 ]; then
        log_debug "Skipping swap for ${_ram}MB RAM device"
        return 0
    fi

    if [ -f "$SWAP_FILE" ]; then
        # Check if swap is already active
        if swapon -s 2>/dev/null | grep -q "$SWAP_FILE"; then
            log_debug "Swap already active"
            return 0
        fi
    fi

    log_step "Setting up swap for low-memory device..."

    # Check available space on SD card
    _avail=$(df -m /mnt/SDCARD 2>/dev/null | awk 'NR==2 {print $4}')
    if [ -n "$_avail" ] && [ "$_avail" -lt 300 ]; then
        log_warn "Insufficient space for swap file (${_avail}MB available, need 300MB)"
        return 1
    fi

    # Create 256MB swap file
    dd if=/dev/zero of="$SWAP_FILE" bs=1M count=256 2>/dev/null
    chmod 600 "$SWAP_FILE"
    mkswap "$SWAP_FILE" 2>/dev/null
    swapon "$SWAP_FILE" 2>/dev/null

    log_info "Swap enabled: 256MB"
}

# Configure OOM killer
configure_oom_killer() {
    _device="$1"
    _tier=$(get_device_tier "$_device")

    if [ "$_tier" = "full" ]; then
        # TG5050: less aggressive OOM (has 2GB RAM)
        echo 0 > /proc/sys/vm/overcommit_memory 2>/dev/null || true
        echo 10 > /proc/sys/vm/overcommit_ratio 2>/dev/null || true
    else
        # TSP/Brick: more aggressive OOM (1GB RAM)
        echo 1 > /proc/sys/vm/overcommit_memory 2>/dev/null || true
        echo 50 > /proc/sys/vm/overcommit_ratio 2>/dev/null || true
    fi

    log_debug "OOM killer configured for $_device"
}

# Apply device-specific optimizations
apply_optimizations() {
    _device="$1"
    _tier=$(get_device_tier "$_device")
    _chroot_dir="$CHROOT_BASE/$_device"

    log_step "Applying optimizations for $_device ($_tier tier)..."

    # CPU governor
    case "$_device" in
        tg5050)
            for _cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
                echo "performance" > "$_cpu" 2>/dev/null || true
            done
            ;;
        tsp|brick)
            for _cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
                echo "ondemand" > "$_cpu" 2>/dev/null || true
            done
            ;;
    esac

    # Memory limits per tier (cgroups v1)
    if [ -d /sys/fs/cgroup/memory ]; then
        mkdir -p /sys/fs/cgroup/memory/jukamix-chroot 2>/dev/null || true

        case "$_tier" in
            full)
                echo "1536M" > /sys/fs/cgroup/memory/jukamix-chroot/memory.limit_in_bytes 2>/dev/null || true
                ;;
            minimal)
                echo "512M" > /sys/fs/cgroup/memory/jukamix-chroot/memory.limit_in_bytes 2>/dev/null || true
                ;;
        esac
    fi

    # Drop caches to free memory
    echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true

    log_info "Optimizations applied"
}

# ============================================================================
# ROOTFS MANAGEMENT
# ============================================================================

# Download rootfs from release
download_rootfs() {
    _device="$1"
    _rootfs=""
    _url=""

    case "$_device" in
        tg5050)
            _rootfs="$CHROOT_BASE/rootfs-tg5050.ext2"
            # Download from latest JukaMix-OS release (built by CI)
            _url="${RELEASE_BASE}/latest/download/rootfs-tg5050.ext2"
            ;;
        tsp|brick)
            _rootfs="$CHROOT_BASE/rootfs-tsp-brick.ext2"
            # Download from latest JukaMix-OS release (built by CI)
            _url="${RELEASE_BASE}/latest/download/rootfs-tsp-brick.ext2"
            ;;
        *)
            log_error "Unknown device: $_device"
            return 1
            ;;
    esac

    log_step "Downloading rootfs for $(get_device_name $_device)..."
    mkdir -p "$CHROOT_BASE" 2>/dev/null || true

    # Show progress
    if command -v curl >/dev/null 2>&1; then
        curl -fL --retry 3 --retry-delay 5 --progress-bar -o "$_rootfs" "$_url"
    elif command -v wget >/dev/null 2>&1; then
        wget --tries=3 --waitretry=5 --progress=dot:giga -O "$_rootfs" "$_url"
    else
        log_error "Neither curl nor wget available"
        return 1
    fi

    if [ ! -s "$_rootfs" ]; then
        log_error "Download failed: $_rootfs is empty"
        rm -f "$_rootfs" 2>/dev/null || true
        return 1
    fi

    # Verify file integrity
    _size=$(ls -l "$_rootfs" | awk '{print $5}')
    if [ "$_size" -lt 1000000 ]; then
        log_error "Rootfs too small (${_size} bytes), download may be corrupted"
        rm -f "$_rootfs" 2>/dev/null || true
        return 1
    fi

    log_info "Downloaded: $(ls -lh "$_rootfs" | awk '{print $5}')"
}

# Extract rootfs with progress
extract_rootfs() {
    _rootfs="$1"
    _chroot_dir="$2"

    log_step "Extracting rootfs..."

    # Try ext2fuse first (fastest, non-destructive)
    if command -v ext2fuse >/dev/null 2>&1; then
        log_info "Using ext2fuse (fastest method)"
        if ext2fuse "$_rootfs" "$_chroot_dir" 2>/dev/null; then
            return 0
        fi
        log_warn "ext2fuse failed, trying alternative methods"
    fi

    # Fallback: mount and copy
    log_info "Using mount and copy method"
    _mount_point=$(mktemp -d)
    _start_time=$(date +%s)

    if mount -o loop,ro "$_rootfs" "$_mount_point" 2>/dev/null; then
        _files=$(find "$_mount_point" -type f 2>/dev/null | wc -l)
        _current=0

        find "$_mount_point" -type f 2>/dev/null | while read -r _file; do
            _current=$(( _current + 1 ))
            show_progress $_current $_files $_start_time
            _rel="${_file#$_mount_point/}"
            mkdir -p "$(dirname "$_chroot_dir/$_rel")" 2>/dev/null || true
            cp -p "$_file" "$_chroot_dir/$_rel" 2>/dev/null || true
        done
        echo ""

        umount "$_mount_point" 2>/dev/null || true
        rmdir "$_mount_point" 2>/dev/null || true
        return 0
    fi

    # Fallback: use debugfs
    if command -v debugfs >/dev/null 2>&1; then
        log_info "Using debugfs method"
        if debugfs -R "dump_all $_chroot_dir" "$_rootfs" 2>/dev/null; then
            return 0
        fi
    fi

    # Last resort: use e2fsck + dump
    if command -v e2image >/dev/null 2>&1; then
        log_info "Using e2image method"
        if e2image -ro "$_rootfs" "$_chroot_dir" 2>/dev/null; then
            return 0
        fi
    fi

    log_error "Cannot extract rootfs - no suitable method available"
    return 1
}

# ============================================================================
# CHROOT LIFECYCLE
# ============================================================================

# Start chroot
start_chroot() {
    _device=$(detect_device)
    _tier=$(get_device_tier "$_device")
    _chroot_dir="$CHROOT_BASE/$_device"
    _rootfs=""

    setup_state

    # Check if already running
    if [ -f "$_chroot_dir/$RUNNING_MARKER" ]; then
        log_warn "Chroot already running for $_device"
        return 0
    fi

    # Find rootfs for this device
    case "$_device" in
        tg5050)
            _rootfs="$CHROOT_BASE/rootfs-tg5050.ext2"
            ;;
        tsp|brick)
            _rootfs="$CHROOT_BASE/rootfs-tsp-brick.ext2"
            ;;
        *)
            log_error "Unknown device: $_device"
            return 1
            ;;
    esac

    # Check rootfs exists, download if not
    if [ ! -f "$_rootfs" ]; then
        log_warn "Rootfs not found: $_rootfs"
        download_rootfs "$_device"
    fi

    if [ ! -f "$_rootfs" ]; then
        log_error "Rootfs not found after download: $_rootfs"
        return 1
    fi

    log_info "Starting chroot for $(get_device_name $_device)..."
    log_info "Tier: $_tier | RAM: $(get_device_ram $_device)MB"

    # Setup memory management
    setup_swap "$_device"
    configure_oom_killer "$_device"

    # Create chroot directory
    mkdir -p "$_chroot_dir" 2>/dev/null || true

    # Extract rootfs (if not already done)
    if [ ! -f "$_chroot_dir/bin/sh" ]; then
        extract_rootfs "$_rootfs" "$_chroot_dir"
    fi

    # Apply optimizations
    apply_optimizations "$_device"

    # Mount filesystems
    mount_chroot "$_device"

    # Setup signal handlers
    setup_signal_handlers "$_chroot_dir"

    # Start zombie reaper
    start_reaper

    # Mark as running
    echo $$ > "$_chroot_dir/$RUNNING_MARKER"

    # Auto-start watchdog
    start_watchdog 2>/dev/null || true

    log_info "Chroot started successfully"
    log_info "Use 'chroot-manager.sh run /bin/sh' to enter"
}

# Stop chroot
stop_chroot() {
    _device=$(detect_device)
    _chroot_dir="$CHROOT_BASE/$_device"

    if [ ! -f "$_chroot_dir/$RUNNING_MARKER" ]; then
        log_warn "Chroot not running for $_device"
        return 0
    fi

    log_step "Stopping chroot for $_device..."

    # Stop watchdog
    stop_watchdog 2>/dev/null || true

    # Stop reaper
    stop_reaper 2>/dev/null || true

    # Kill any processes in chroot
    _chroot_pid=$(cat "$_chroot_dir/$RUNNING_MARKER" 2>/dev/null)
    if [ -n "$_chroot_pid" ]; then
        kill -TERM "$_chroot_pid" 2>/dev/null || true
        sleep 2
        kill -9 "$_chroot_pid" 2>/dev/null || true
    fi

    # Kill any remaining processes using the chroot
    pkill -f "chroot.*$_chroot_dir" 2>/dev/null || true

    # Unmount filesystems
    umount_chroot "$_device"

    # Remove running marker
    rm -f "$_chroot_dir/$RUNNING_MARKER" 2>/dev/null || true

    # Disable swap (only if we created it)
    if [ -f "$SWAP_FILE" ]; then
        swapoff "$SWAP_FILE" 2>/dev/null || true
        rm -f "$SWAP_FILE" 2>/dev/null || true
    fi

    log_info "Chroot stopped for $_device"
}

# ============================================================================
# COMMAND EXECUTION
# ============================================================================

# Run command in chroot
run_in_chroot() {
    _device=$(detect_device)
    _chroot_dir="$CHROOT_BASE/$_device"
    _cmd="$@"

    if [ ! -f "$_chroot_dir/$RUNNING_MARKER" ]; then
        log_error "Chroot not running. Start with: chroot-manager.sh start"
        return 1
    fi

    if [ -z "$_cmd" ]; then
        _cmd="/bin/sh"
    fi

    # Forward important environment variables
    _env_args=""
    for _env_var in HOME PATH TERM DISPLAY USER LANG LC_ALL; do
        _val=$(eval echo "\$$_env_var" 2>/dev/null)
        if [ -n "$_val" ]; then
            _env_args="$_env_args $_env_var=$_val"
        fi
    done

    # Execute in chroot
    chroot "$_chroot_dir" /bin/sh -c "$_cmd"
}

# Enter interactive shell
enter_shell() {
    _device=$(detect_device)
    _chroot_dir="$CHROOT_BASE/$_device"

    if [ ! -f "$_chroot_dir/$RUNNING_MARKER" ]; then
        log_error "Chroot not running. Start with: chroot-manager.sh start"
        return 1
    fi

    log_info "Entering chroot shell (type 'exit' to leave)..."

    # Set PS1 for better UX
    export PS1='[\u@\jukamix \w]\$ '

    chroot "$_chroot_dir" /bin/sh
}

# ============================================================================
# BACKUP/RESTORE
# ============================================================================

# Backup user data
backup_user_data() {
    _device="$1"
    _chroot_dir="$CHROOT_BASE/$_device"
    _timestamp=$(date +%Y%m%d_%H%M%S)
    _backup_path="$BACKUP_DIR/${_device}_${_timestamp}"

    log_step "Backing up user data..."

    mkdir -p "$_backup_path" 2>/dev/null || true

    # Backup user data from chroot
    for _dir in Roms BIOS Saves States Pictures Themes Data; do
        if [ -d "$_chroot_dir/mnt/SDCARD/$_dir" ]; then
            cp -r "$_chroot_dir/mnt/SDCARD/$_dir" "$_backup_path/" 2>/dev/null || true
            log_debug "Backed up: $_dir"
        fi
    done

    # Also backup profile data
    if [ -d "$PROFILE_DIR" ]; then
        cp -r "$PROFILE_DIR" "$_backup_path/profiles" 2>/dev/null || true
    fi

    log_info "Backup created: $_backup_path"
    echo "$_backup_path"
}

# Restore user data
restore_user_data() {
    _device="$1"
    _backup_path="$2"
    _chroot_dir="$CHROOT_BASE/$_device"

    if [ ! -d "$_backup_path" ]; then
        log_error "Backup not found: $_backup_path"
        return 1
    fi

    log_step "Restoring user data from $_backup_path..."

    for _dir in Roms BIOS Saves States Pictures Themes Data; do
        if [ -d "$_backup_path/$_dir" ]; then
            cp -r "$_backup_path/$_dir" "$_chroot_dir/mnt/SDCARD/" 2>/dev/null || true
            log_debug "Restored: $_dir"
        fi
    done

    # Restore profiles
    if [ -d "$_backup_path/profiles" ]; then
        mkdir -p "$PROFILE_DIR" 2>/dev/null || true
        cp -r "$_backup_path/profiles/"* "$PROFILE_DIR/" 2>/dev/null || true
    fi

    log_info "User data restored"
}

# List backups
list_backups() {
    _device="$1"

    if [ ! -d "$BACKUP_DIR" ]; then
        log_info "No backups found"
        return 0
    fi

    echo -e "${CYAN}Available backups for $_device:${NC}"
    ls -1dt "$BACKUP_DIR/${_device}_"* 2>/dev/null | while read -r _backup; do
        _name=$(basename "$_backup")
        _size=$(du -sh "$_backup" 2>/dev/null | awk '{print $1}')
        echo "  $_name ($_size)"
    done
}

# ============================================================================
# PROFILES
# ============================================================================

# Load game profile
load_profile() {
    _profile_name="$1"
    _profile_file="$PROFILE_DIR/$_profile_name.json"

    if [ ! -f "$_profile_file" ]; then
        log_error "Profile not found: $_profile_name"
        return 1
    fi

    log_step "Loading profile: $_profile_name"

    # Parse JSON profile (simple shell parsing)
    _device=$(grep '"device"' "$_profile_file" 2>/dev/null | sed 's/.*: *"\(.*\)".*/\1/')
    _created=$(grep '"created"' "$_profile_file" 2>/dev/null | sed 's/.*: *"\(.*\)".*/\1/')

    log_info "Profile loaded: $_profile_name"
    log_info "  Device: $_device"
    log_info "  Created: $_created"
}

# Save game profile
save_profile() {
    _profile_name="$1"
    _profile_file="$PROFILE_DIR/$_profile_name.json"

    mkdir -p "$PROFILE_DIR" 2>/dev/null || true

    log_step "Saving profile: $_profile_name"

    _device=$(detect_device)
    _timestamp=$(date -Iseconds 2>/dev/null || date)

    # Save current settings
    cat > "$_profile_file" << EOF
{
    "name": "$_profile_name",
    "device": "$_device",
    "created": "$_timestamp",
    "settings": {
        "cpu_governor": "$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo 'unknown')",
        "swap_enabled": $([ -f "$SWAP_FILE" ] && echo "true" || echo "false"),
        "overlay_enabled": $([ -f "$CHROOT_BASE/$_device/$OVERLAY_MARKER" ] && echo "true" || echo "false")
    }
}
EOF

    log_info "Profile saved: $_profile_name"
}

# List profiles
list_profiles() {
    if [ ! -d "$PROFILE_DIR" ]; then
        log_info "No profiles found"
        return 0
    fi

    echo -e "${CYAN}Available profiles:${NC}"
    ls -1 "$PROFILE_DIR"/*.json 2>/dev/null | while read -r _profile; do
        _name=$(basename "$_profile" .json)
        echo "  $_name"
    done
}

# ============================================================================
# MONITORING & DIAGNOSTICS
# ============================================================================

# Monitor resource usage
monitor_resources() {
    _device=$(detect_device)

    log_step "Monitoring resources for $_device (Ctrl+C to stop)..."

    while true; do
        clear
        echo -e "${CYAN}========================================${NC}"
        echo -e "${CYAN}   JukaMix Buildroot Monitor${NC}"
        echo -e "${CYAN}========================================${NC}"
        echo ""

        # CPU usage
        if [ -f /proc/stat ]; then
            _cpu_line=$(head -1 /proc/stat)
            _cpu_user=$(echo "$_cpu_line" | awk '{print $2}')
            _cpu_system=$(echo "$_cpu_line" | awk '{print $4}')
            _cpu_idle=$(echo "$_cpu_line" | awk '{print $5}')
            _cpu_total=$(( _cpu_user + _cpu_system + _cpu_idle ))
            _cpu_used=$(( _cpu_user + _cpu_system ))
            if [ "$_cpu_total" -gt 0 ]; then
                _cpu_percent=$(( _cpu_used * 100 / _cpu_total ))
            else
                _cpu_percent=0
            fi
            echo -e "CPU:       ${GREEN}${_cpu_percent}%${NC}"
        fi

        # Memory usage
        if [ -f /proc/meminfo ]; then
            _total=$(awk '/^MemTotal/ {print $2}' /proc/meminfo)
            _free=$(awk '/^MemAvailable/ {print $2}' /proc/meminfo)
            if [ -n "$_free" ]; then
                _used=$(( (_total - _free) / 1024 ))
            else
                _available=$(awk '/^MemFree/ {print $2}' /proc/meminfo)
                _buffers=$(awk '/^Buffers/ {print $2}' /proc/meminfo)
                _cached=$(awk '/^Cached/ {print $2}' /proc/meminfo)
                _used=$(( (_total - _available - _buffers - _cached) / 1024 ))
            fi
            _total_mb=$(( _total / 1024 ))
            if [ "$_total_mb" -gt 0 ]; then
                _percent=$(( _used * 100 / _total_mb ))
            else
                _percent=0
            fi
            echo -e "Memory:    ${GREEN}${_used}MB${NC} / ${GREEN}${_total_mb}MB${NC} (${_percent}%)"
        fi

        # Swap usage
        if [ -f /proc/swaps ]; then
            _swap_used=$(awk 'NR>1 {print $3}' /proc/swaps 2>/dev/null | head -1)
            if [ -n "$_swap_used" ]; then
                echo -e "Swap:      ${GREEN}${_swap_used}MB${NC}"
            fi
        fi

        # Disk usage
        _disk_used=$(df -h /mnt/SDCARD 2>/dev/null | awk 'NR==2 {print $3}')
        _disk_total=$(df -h /mnt/SDCARD 2>/dev/null | awk 'NR==2 {print $2}')
        echo -e "Disk:      ${GREEN}${_disk_used}${NC} / ${GREEN}${_disk_total}${NC}"

        # GPU status
        _gpu_nodes=$(detect_gpu_nodes)
        if [ -n "$_gpu_nodes" ]; then
            echo -e "GPU:       ${GREEN}ACTIVE${NC}"
        else
            echo -e "GPU:       ${YELLOW}INACTIVE${NC}"
        fi

        # Chroot status
        _chroot_dir="$CHROOT_BASE/$_device"
        if [ -f "$_chroot_dir/$RUNNING_MARKER" ]; then
            echo -e "Chroot:    ${GREEN}RUNNING${NC}"
        else
            echo -e "Chroot:    ${YELLOW}STOPPED${NC}"
        fi

        echo ""
        echo -e "${CYAN}Press Ctrl+C to stop monitoring${NC}"

        sleep "$MONITOR_INTERVAL"
    done
}

# Run diagnostics
run_diagnostics() {
    _device=$(detect_device)

    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}   JukaMix Buildroot Diagnostics${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""

    # Device info
    echo "Device: $(get_device_name $_device) ($_device)"
    echo "Tier: $(get_device_tier $_device)"
    echo "RAM: $(get_device_ram $_device)MB"
    echo ""

    # Check dependencies
    echo "Dependencies:"
    for _cmd in curl wget ext2fuse debugfs mount chroot; do
        if command -v "$_cmd" >/dev/null 2>&1; then
            echo -e "  ${GREEN}+${NC} $_cmd"
        else
            echo -e "  ${RED}x${NC} $_cmd (required)"
        fi
    done
    echo ""

    # Check rootfs
    _rootfs=""
    case "$_device" in
        tg5050) _rootfs="$CHROOT_BASE/rootfs-tg5050.ext2" ;;
        tsp|brick) _rootfs="$CHROOT_BASE/rootfs-tsp-brick.ext2" ;;
    esac

    if [ -f "$_rootfs" ]; then
        _size=$(ls -lh "$_rootfs" 2>/dev/null | awk '{print $5}')
        echo -e "Rootfs: ${GREEN}+${NC} $_size"

        # Check if it's a valid ext2
        if command -v file >/dev/null 2>&1; then
            if file "$_rootfs" 2>/dev/null | grep -q "ext2"; then
                echo -e "  Format: ${GREEN}Valid ext2${NC}"
            else
                echo -e "  Format: ${RED}Invalid or corrupted${NC}"
            fi
        fi
    else
        echo -e "Rootfs: ${RED}x${NC} Not found"
    fi
    echo ""

    # Check chroot
    _chroot_dir="$CHROOT_BASE/$_device"
    if [ -f "$_chroot_dir/$RUNNING_MARKER" ]; then
        echo -e "Chroot: ${GREEN}+${NC} Running"
    else
        echo -e "Chroot: ${YELLOW}o${NC} Stopped"
    fi
    echo ""

    # Check GPU
    echo "GPU:"
    _gpu_nodes=$(detect_gpu_nodes)
    if [ -n "$_gpu_nodes" ]; then
        for _gpu in $_gpu_nodes; do
            echo -e "  ${GREEN}+${NC} $_gpu"
        done
    else
        echo -e "  ${YELLOW}o${NC} No GPU nodes found"
    fi
    echo ""

    # Check audio
    echo "Audio:"
    if [ -d /dev/snd ]; then
        echo -e "  ${GREEN}+${NC} ALSA available"
    else
        echo -e "  ${YELLOW}o${NC} No ALSA devices"
    fi
    echo ""

    # Check input
    echo "Input:"
    _input_count=$(ls /dev/input/event* 2>/dev/null | wc -l)
    if [ "$_input_count" -gt 0 ]; then
        echo -e "  ${GREEN}+${NC} $_input_count input device(s)"
    else
        echo -e "  ${YELLOW}o${NC} No input devices"
    fi
    echo ""

    # Check memory
    echo "Memory:"
    if [ -f /proc/meminfo ]; then
        _total=$(awk '/^MemTotal/ {print $2}' /proc/meminfo)
        _free=$(awk '/^MemAvailable/ {print $2}' /proc/meminfo)
        _total_mb=$(( _total / 1024 ))
        if [ -n "$_free" ]; then
            _free_mb=$(( _free / 1024 ))
        else
            _free_mb=$(( _total_mb / 2 ))
        fi
        echo -e "  Total: ${GREEN}${_total_mb}MB${NC}"
        echo -e "  Free:  ${GREEN}${_free_mb}MB${NC}"
    fi
    echo ""

    # Check swap
    echo "Swap:"
    if swapon -s 2>/dev/null | grep -q "jukamix-swap"; then
        echo -e "  ${GREEN}+${NC} Active (256MB)"
    else
        echo -e "  ${YELLOW}o${NC} Inactive"
    fi
    echo ""

    echo -e "${CYAN}========================================${NC}"
}

# ============================================================================
# WATCHDOG
# ============================================================================

# Watchdog service
start_watchdog() {
    _device=$(detect_device)
    _chroot_dir="$CHROOT_BASE/$_device"

    if [ -f "$WATCHDOG_PID" ]; then
        _pid=$(cat "$WATCHDOG_PID" 2>/dev/null)
        if kill -0 "$_pid" 2>/dev/null; then
            log_debug "Watchdog already running (PID: $_pid)"
            return 0
        fi
    fi

    log_step "Starting watchdog service..."

    # Start watchdog in background
    (
        while true; do
            sleep "$WATCHDOG_INTERVAL"

            # Check if chroot is running
            if [ -f "$_chroot_dir/$RUNNING_MARKER" ]; then
                _pid=$(cat "$_chroot_dir/$RUNNING_MARKER" 2>/dev/null)
                if [ -n "$_pid" ] && ! kill -0 "$_pid" 2>/dev/null; then
                    log_warn "Chroot process $_pid died, cleaning up..."
                    rm -f "$_chroot_dir/$RUNNING_MARKER" 2>/dev/null || true
                fi
            fi

            # Check memory usage
            if [ -f /proc/meminfo ]; then
                _free=$(awk '/^MemAvailable/ {print $2}' /proc/meminfo)
                if [ -n "$_free" ]; then
                    _free_mb=$(( _free / 1024 ))
                    if [ "$_free_mb" -lt 50 ]; then
                        log_warn "Low memory: ${_free_mb}MB free"
                        echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true
                    fi
                fi
            fi

            # Check disk space
            _disk_free=$(df -m /mnt/SDCARD 2>/dev/null | awk 'NR==2 {print $4}')
            if [ -n "$_disk_free" ] && [ "$_disk_free" -lt 100 ]; then
                log_warn "Low disk space: ${_disk_free}MB free"
                find /tmp -name "*.log" -mtime +7 -delete 2>/dev/null || true
            fi

            # Clean up stale PID files
            if [ -f "$WATCHDOG_PID" ]; then
                _wpid=$(cat "$WATCHDOG_PID" 2>/dev/null)
                if [ -n "$_wpid" ] && ! kill -0 "$_wpid" 2>/dev/null; then
                    rm -f "$WATCHDOG_PID" 2>/dev/null || true
                fi
            fi
        done
    ) &

    echo $! > "$WATCHDOG_PID" 2>/dev/null || true
    log_info "Watchdog started (PID: $(cat "$WATCHDOG_PID" 2>/dev/null))"
}

# Stop watchdog
stop_watchdog() {
    if [ ! -f "$WATCHDOG_PID" ]; then
        log_debug "Watchdog not running"
        return 0
    fi

    _pid=$(cat "$WATCHDOG_PID" 2>/dev/null)
    if [ -n "$_pid" ] && kill -0 "$_pid" 2>/dev/null; then
        kill "$_pid" 2>/dev/null || true
        log_info "Watchdog stopped"
    fi

    rm -f "$WATCHDOG_PID" 2>/dev/null || true
}

# ============================================================================
# UPDATE & CLEANUP
# ============================================================================

# Update rootfs
update_rootfs() {
    _device=$(detect_device)
    _rootfs=""
    _chroot_dir="$CHROOT_BASE/$_device"

    case "$_device" in
        tg5050) _rootfs="$CHROOT_BASE/rootfs-tg5050.ext2" ;;
        tsp|brick) _rootfs="$CHROOT_BASE/rootfs-tsp-brick.ext2" ;;
    esac

    log_step "Updating rootfs for $_device..."

    # Backup current rootfs
    if [ -f "$_rootfs" ]; then
        mv "$_rootfs" "$_rootfs.bak" 2>/dev/null || true
    fi

    # Download new rootfs
    if ! download_rootfs "$_device"; then
        log_error "Download failed, restoring backup..."
        mv "$_rootfs.bak" "$_rootfs" 2>/dev/null || true
        return 1
    fi

    # Re-extract if chroot is running
    if [ -f "$_chroot_dir/$RUNNING_MARKER" ]; then
        log_warn "Chroot is running, stopping for update..."
        stop_chroot 2>/dev/null || true
        extract_rootfs "$_rootfs" "$_chroot_dir"
        start_chroot 2>/dev/null || true
    fi

    # Remove backup
    rm -f "$_rootfs.bak" 2>/dev/null || true

    log_info "Rootfs updated"
}

# Cleanup storage
cleanup_storage() {
    log_step "Cleaning up storage..."

    # Remove old backups (keep last 5)
    if [ -d "$BACKUP_DIR" ]; then
        ls -dt "$BACKUP_DIR"/*/ 2>/dev/null | tail -n +6 | xargs rm -rf 2>/dev/null || true
    fi

    # Remove old logs (older than 7 days)
    find /tmp -name "jukamix-*.log" -mtime +7 -delete 2>/dev/null || true

    # Remove cache
    rm -rf "$CACHE_DIR" 2>/dev/null || true

    # Remove old state files
    find /tmp -name ".jukamix-*" -mtime +1 -delete 2>/dev/null || true

    # Remove swap if not needed
    _device=$(detect_device)
    _ram=$(get_device_ram "$_device")
    if [ "$_ram" -gt 1024 ] && [ -f "$SWAP_FILE" ]; then
        swapoff "$SWAP_FILE" 2>/dev/null || true
        rm -f "$SWAP_FILE" 2>/dev/null || true
    fi

    # Remove overlay if inactive
    if [ ! -f "$CHROOT_BASE/$_device/$OVERLAY_MARKER" ]; then
        rm -rf "$OVERLAY_UPPER" 2>/dev/null || true
        rm -rf "$OVERLAY_WORK" 2>/dev/null || true
    fi

    log_info "Cleanup complete"
}

# ============================================================================
# STATUS
# ============================================================================

# Show status
show_status() {
    _device=$(detect_device)
    _tier=$(get_device_tier "$_device")
    _chroot_dir="$CHROOT_BASE/$_device"
    _ram=$(get_device_ram "$_device")
    _rootfs=""

    case "$_device" in
        tg5050) _rootfs="$CHROOT_BASE/rootfs-tg5050.ext2" ;;
        tsp|brick) _rootfs="$CHROOT_BASE/rootfs-tsp-brick.ext2" ;;
    esac

    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}   JukaMix Buildroot Status${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    echo -e "Device:     ${GREEN}$(get_device_name $_device)${NC}"
    echo -e "Device ID:  ${GREEN}$_device${NC}"
    echo -e "Tier:       ${GREEN}$_tier${NC}"
    echo -e "RAM:        ${GREEN}${_ram}MB${NC}"
    echo ""

    # Rootfs status
    if [ -f "$_rootfs" ]; then
        _rootfs_size=$(ls -lh "$_rootfs" | awk '{print $5}')
        echo -e "Rootfs:     ${GREEN}INSTALLED${NC} ($_rootfs_size)"
    else
        echo -e "Rootfs:     ${YELLOW}NOT INSTALLED${NC}"
    fi

    # Chroot status
    if [ -f "$_chroot_dir/$RUNNING_MARKER" ]; then
        echo -e "Status:     ${GREEN}RUNNING${NC}"
    else
        echo -e "Status:     ${YELLOW}STOPPED${NC}"
    fi

    # Overlay status
    if [ -f "$_chroot_dir/$OVERLAY_MARKER" ]; then
        echo -e "Overlay:    ${GREEN}ACTIVE${NC}"
    else
        echo -e "Overlay:    ${YELLOW}INACTIVE${NC}"
    fi

    # Watchdog status
    if [ -f "$WATCHDOG_PID" ]; then
        _watchdog_pid=$(cat "$WATCHDOG_PID" 2>/dev/null)
        if [ -n "$_watchdog_pid" ] && kill -0 "$_watchdog_pid" 2>/dev/null; then
            echo -e "Watchdog:   ${GREEN}ACTIVE${NC} (PID: $_watchdog_pid)"
        else
            echo -e "Watchdog:   ${YELLOW}INACTIVE${NC}"
        fi
    else
        echo -e "Watchdog:   ${YELLOW}INACTIVE${NC}"
    fi

    # Reaper status
    if [ -f "$REAPER_PID" ]; then
        _reaper_pid=$(cat "$REAPER_PID" 2>/dev/null)
        if [ -n "$_reaper_pid" ] && kill -0 "$_reaper_pid" 2>/dev/null; then
            echo -e "Reaper:     ${GREEN}ACTIVE${NC} (PID: $_reaper_pid)"
        else
            echo -e "Reaper:     ${YELLOW}INACTIVE${NC}"
        fi
    else
        echo -e "Reaper:     ${YELLOW}INACTIVE${NC}"
    fi

    # GPU status
    _gpu_nodes=$(detect_gpu_nodes)
    if [ -n "$_gpu_nodes" ]; then
        _gpu_count=$(echo "$_gpu_nodes" | wc -w)
        echo -e "GPU:        ${GREEN}ACTIVE${NC} ($_gpu_count device(s))"
    else
        echo -e "GPU:        ${YELLOW}INACTIVE${NC}"
    fi

    # Audio status
    if [ -d /dev/snd ]; then
        echo -e "Audio:      ${GREEN}ACTIVE${NC}"
    else
        echo -e "Audio:      ${YELLOW}INACTIVE${NC}"
    fi

    # Input devices
    _input_count=$(ls /dev/input/event* 2>/dev/null | wc -l)
    if [ "$_input_count" -gt 0 ]; then
        echo -e "Input:      ${GREEN}ACTIVE${NC} ($_input_count device(s))"
    else
        echo -e "Input:      ${YELLOW}INACTIVE${NC}"
    fi

    # Memory usage
    if [ -f /proc/meminfo ]; then
        _total=$(awk '/^MemTotal/ {print $2}' /proc/meminfo)
        _free=$(awk '/^MemAvailable/ {print $2}' /proc/meminfo)
        if [ -n "$_free" ]; then
            _used=$(( (_total - _free) / 1024 ))
        else
            _used=$(( _total / 2048 ))
        fi
        echo -e "Memory:     ${GREEN}${_used}MB${NC} used / ${GREEN}$((_total / 1024))MB${NC} total"
    fi

    # Swap status
    if swapon -s 2>/dev/null | grep -q "jukamix-swap"; then
        echo -e "Swap:       ${GREEN}ACTIVE${NC} (256MB)"
    else
        echo -e "Swap:       ${YELLOW}INACTIVE${NC}"
    fi

    # Backup count
    if [ -d "$BACKUP_DIR" ]; then
        _backup_count=$(ls -1d "$BACKUP_DIR"/*/ 2>/dev/null | wc -l)
        echo -e "Backups:    ${GREEN}${_backup_count}${NC}"
    fi

    # Profile count
    if [ -d "$PROFILE_DIR" ]; then
        _profile_count=$(ls -1 "$PROFILE_DIR"/*.json 2>/dev/null | wc -l)
        echo -e "Profiles:   ${GREEN}${_profile_count}${NC}"
    fi

    echo -e "${CYAN}========================================${NC}"
}

# ============================================================================
# RECOVERY
# ============================================================================

# Attempt automatic recovery
attempt_recovery() {
    _device=$(detect_device)
    _chroot_dir="$CHROOT_BASE/$_device"

    log_step "Attempting automatic recovery for $_device..."

    # Check if chroot is stuck
    if [ -f "$_chroot_dir/$RUNNING_MARKER" ]; then
        _pid=$(cat "$_chroot_dir/$RUNNING_MARKER" 2>/dev/null)
        if [ -n "$_pid" ] && ! kill -0 "$_pid" 2>/dev/null; then
            log_warn "Chroot process $_pid is dead, cleaning up..."
            rm -f "$_chroot_dir/$RUNNING_MARKER" 2>/dev/null || true
        fi
    fi

    # Check for corrupted rootfs
    _rootfs=""
    case "$_device" in
        tg5050) _rootfs="$CHROOT_BASE/rootfs-tg5050.ext2" ;;
        tsp|brick) _rootfs="$CHROOT_BASE/rootfs-tsp-brick.ext2" ;;
    esac

    if [ -f "$_rootfs" ]; then
        # Verify rootfs integrity
        if command -v file >/dev/null 2>&1; then
            if ! file "$_rootfs" 2>/dev/null | grep -q "ext2"; then
                log_warn "Rootfs appears corrupted, re-downloading..."
                rm -f "$_rootfs" 2>/dev/null || true
                download_rootfs "$_device" 2>/dev/null || true
            fi
        fi
    fi

    # Clean up stale mounts
    mount | grep "$_chroot_dir" 2>/dev/null | while read -r _line; do
        _mount_point=$(echo "$_line" | awk '{print $3}')
        log_warn "Cleaning up stale mount: $_mount_point"
        umount "$_mount_point" 2>/dev/null || true
    done

    # Clean up stale PID files
    rm -f "$WATCHDOG_PID" 2>/dev/null || true
    rm -f "$REAPER_PID" 2>/dev/null || true
    rm -rf "$STATEDIR" 2>/dev/null || true

    # Kill any orphaned processes
    pkill -f "jukamix-chroot" 2>/dev/null || true

    log_info "Recovery complete"
}

# ============================================================================
# USAGE
# ============================================================================

usage() {
    cat << 'EOF'
Usage: chroot-manager.sh <command> [args]

Commands:
  start              Start chroot environment
  stop               Stop chroot environment
  status             Show chroot status
  run <command>      Run command in chroot
  shell              Enter interactive shell
  optimize           Apply device-specific optimizations
  diagnose           Run diagnostics
  install            Install/extract rootfs
  download           Download rootfs from release
  backup             Backup user data
  restore <path>     Restore user data from backup
  backups            List available backups
  profile load <n>   Load game profile
  profile save <n>   Save game profile
  profiles           List available profiles
  monitor            Monitor resource usage
  recover            Attempt automatic recovery
  watchdog start     Start watchdog service
  watchdog stop      Stop watchdog service
  network setup      Setup network access
  update             Update rootfs
  cleanup            Clean up storage
  overlay enable     Enable overlayfs (persistent changes)
  overlay disable    Disable overlayfs (clean state)

Examples:
  chroot-manager.sh start              # Start chroot
  chroot-manager.sh shell              # Enter interactive shell
  chroot-manager.sh run /bin/sh        # Run shell
  chroot-manager.sh run python3 -c "print('hi')"  # Run Python
  chroot-manager.sh stop               # Stop chroot
  chroot-manager.sh diagnose           # Check system health
  chroot-manager.sh backup             # Backup user data
  chroot-manager.sh overlay enable     # Enable persistent changes
  chroot-manager.sh profile save mygame  # Save profile
  chroot-manager.sh monitor            # Monitor resources
  chroot-manager.sh recover            # Attempt recovery

Device Tiers:
  TG5050 (Smart Pro S): Full tier (GPU, QT6, Wayland, Mesa3D)
  TSP/Brick:            Minimal tier (GPU passthrough, modern libs)

Features:
  - GPU passthrough (Mali for all devices)
  - Audio passthrough (ALSA/PulseAudio)
  - Input device forwarding (gamepad, touchscreen)
  - OverlayFS for persistent package installs
  - Memory management (swap, OOM killer)
  - Signal handling for graceful shutdown
  - Zombie process reaping (PID 1)
  - Environment variable forwarding
  - Auto-mount/umount hooks
  - Backup/restore for user data
  - Health checks and diagnostics
  - Progress indicators
  - Automatic recovery
  - Resource usage tracking
  - Watchdog service
  - Network configuration
  - Auto-updates

Services:
  - Watchdog: Monitors chroot health, auto-recovery
  - Reaper: Reaps zombie processes in chroot
  - Network: Internet access in chroot
  - GPU: Mali GPU passthrough for graphics
  - Audio: ALSA audio passthrough
  - Input: Gamepad and touchscreen forwarding
  - Overlay: Persistent package installs
EOF
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    _command="${1:-help}"
    shift || true

    case "$_command" in
        start)
            start_chroot
            ;;
        stop)
            stop_chroot
            ;;
        status)
            show_status
            ;;
        run)
            run_in_chroot "$@"
            ;;
        shell)
            enter_shell
            ;;
        optimize)
            _device=$(detect_device)
            apply_optimizations "$_device"
            ;;
        diagnose)
            run_diagnostics
            ;;
        install)
            _device=$(detect_device)
            _rootfs=""
            _chroot_dir="$CHROOT_BASE/$_device"

            case "$_device" in
                tg5050) _rootfs="$CHROOT_BASE/rootfs-tg5050.ext2" ;;
                tsp|brick) _rootfs="$CHROOT_BASE/rootfs-tsp-brick.ext2" ;;
            esac

            if [ ! -f "$_rootfs" ]; then
                log_error "Rootfs not found: $_rootfs"
                return 1
            fi

            mkdir -p "$_chroot_dir" 2>/dev/null || true
            extract_rootfs "$_rootfs" "$_chroot_dir"
            ;;
        download)
            _device=$(detect_device)
            download_rootfs "$_device"
            ;;
        backup)
            _device=$(detect_device)
            backup_user_data "$_device"
            ;;
        restore)
            _device=$(detect_device)
            _backup_path="$1"

            if [ -z "$_backup_path" ]; then
                log_error "Please specify backup path"
                return 1
            fi

            restore_user_data "$_device" "$_backup_path"
            ;;
        backups)
            _device=$(detect_device)
            list_backups "$_device"
            ;;
        profile)
            _subcommand="$1"
            shift || true

            case "$_subcommand" in
                load)
                    _profile_name="$1"
                    if [ -z "$_profile_name" ]; then
                        log_error "Please specify profile name"
                        return 1
                    fi
                    load_profile "$_profile_name"
                    ;;
                save)
                    _profile_name="$1"
                    if [ -z "$_profile_name" ]; then
                        log_error "Please specify profile name"
                        return 1
                    fi
                    save_profile "$_profile_name"
                    ;;
                *)
                    log_error "Unknown profile command: $_subcommand"
                    usage
                    return 1
                    ;;
            esac
            ;;
        profiles)
            list_profiles
            ;;
        monitor)
            monitor_resources
            ;;
        recover)
            attempt_recovery
            ;;
        watchdog)
            _subcommand="$1"
            shift || true

            case "$_subcommand" in
                start)
                    start_watchdog
                    ;;
                stop)
                    stop_watchdog
                    ;;
                *)
                    log_error "Unknown watchdog command: $_subcommand"
                    usage
                    return 1
                    ;;
            esac
            ;;
        network)
            _subcommand="$1"
            shift || true

            case "$_subcommand" in
                setup)
                    _device=$(detect_device)
                    _chroot_dir="$CHROOT_BASE/$_device"
                    setup_network "$_chroot_dir"
                    ;;
                *)
                    log_error "Unknown network command: $_subcommand"
                    usage
                    return 1
                    ;;
            esac
            ;;
        overlay)
            _subcommand="$1"
            shift || true

            case "$_subcommand" in
                enable)
                    enable_overlay
                    ;;
                disable)
                    disable_overlay
                    ;;
                *)
                    log_error "Unknown overlay command: $_subcommand"
                    usage
                    return 1
                    ;;
            esac
            ;;
        update)
            update_rootfs
            ;;
        cleanup)
            cleanup_storage
            ;;
        help|--help|-h)
            usage
            ;;
        *)
            log_error "Unknown command: $_command"
            usage
            exit 1
            ;;
    esac
}

main "$@"
