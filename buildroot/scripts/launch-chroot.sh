#!/bin/sh
# launch-chroot.sh - Device-aware Buildroot chroot for TrimUI devices
#
# Usage:
#   ./launch-chroot.sh /bin/bash                    # Interactive shell
#   ./launch-chroot.sh /usr/bin/python3 script.py   # Run Python script
#   ./launch-chroot.sh /usr/bin/node app.js         # Run Node.js app
#
# This script:
# 1. Detects your device (TG5050, TSP, or Brick)
# 2. Selects appropriate rootfs (full or minimal tier)
# 3. Mounts necessary filesystems
# 4. Enters chroot environment
# 5. Cleans up on exit

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILDROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="$BUILDROOT_DIR/output"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

# Detect device
detect_device() {
    local device="unknown"
    
    # Method 1: Read from /etc/trimui_device.txt
    if [ -f /etc/trimui_device.txt ]; then
        device=$(tr -d '[:space:]' < /etc/trimui_device.txt | head -n 1)
    fi
    
    # Method 2: Check device tree
    if [ "$device" = "unknown" ] && [ -r /proc/device-tree/model ]; then
        local model=$(tr -d '\0' </proc/device-tree/model 2>/dev/null | tr 'A-Z' 'a-z')
        case "$model" in
            *a523* | *tg5050* | *5050*) device="tg5050" ;;
            *brick* | *tg3040*)         device="brick" ;;
            *a133*)                     device="tsp" ;;
        esac
    fi
    
    # Method 3: Check screen resolution (Brick is 4:3)
    if [ "$device" = "unknown" ] && [ -r /sys/class/graphics/fb0/virtual_size ]; then
        case "$(cat /sys/class/graphics/fb0/virtual_size 2>/dev/null)" in
            1024,*) device="brick" ;;
            1280,*) device="tsp" ;;
        esac
    fi
    
    echo "$device"
}

# Select rootfs based on device
select_rootfs() {
    local device="$1"
    local rootfs=""
    local tier=""
    
    case "$device" in
        tg5050)
            rootfs="$OUTPUT_DIR/rootfs-tg5050.ext2"
            tier="full"
            ;;
        tsp|brick)
            rootfs="$OUTPUT_DIR/rootfs-tsp-brick.ext2"
            tier="minimal"
            ;;
        *)
            log_error "Unknown device: $device"
            log_error "Please specify rootfs manually with --rootfs"
            exit 1
            ;;
    esac
    
    if [ ! -f "$rootfs" ]; then
        log_error "Rootfs not found: $rootfs"
        log_error "Please run build_all.sh first to build rootfs"
        exit 1
    fi
    
    echo "$rootfs:$tier"
}

# Check available memory
check_memory() {
    local device="$1"
    local min_memory=""
    
    case "$device" in
        tg5050)
            min_memory=200  # MB
            ;;
        tsp|brick)
            min_memory=150  # MB
            ;;
        *)
            min_memory=100
            ;;
    esac
    
    if command -v free >/dev/null 2>&1; then
        local free_mem=$(free -m | awk '/Mem:/ {print $7}')
        if [ "$free_mem" -lt "$min_memory" ]; then
            log_warn "Low memory: ${free_mem}MB free (recommended: ${min_memory}MB+)"
            log_warn "Some apps may not work correctly"
        fi
    fi
}

# Mount filesystems for chroot
mount_chroot() {
    local chroot_dir="$1"
    
    log_info "Mounting filesystems..."
    
    # Create mount points
    mkdir -p "$chroot_dir/dev"
    mkdir -p "$chroot_dir/proc"
    mkdir -p "$chroot_dir/sys"
    mkdir -p "$chroot_dir/tmp"
    mkdir -p "$chroot_dir/mnt/Roms"
    mkdir -p "$chroot_dir/mnt/BIOS"
    mkdir -p "$chroot_dir/mnt/Saves"
    
    # Mount virtual filesystems
    mount --bind /dev "$chroot_dir/dev" 2>/dev/null || true
    mount -t proc proc "$chroot_dir/proc" 2>/dev/null || true
    mount -t sysfs sys "$chroot_dir/sys" 2>/dev/null || true
    mount --bind /tmp "$chroot_dir/tmp" 2>/dev/null || true
    
    # Mount user data (if available)
    if [ -d /mnt/SDCARD/Roms ]; then
        mount --bind /mnt/SDCARD/Roms "$chroot_dir/mnt/Roms" 2>/dev/null || true
    fi
    if [ -d /mnt/SDCARD/BIOS ]; then
        mount --bind /mnt/SDCARD/BIOS "$chroot_dir/mnt/BIOS" 2>/dev/null || true
    fi
    if [ -d /mnt/SDCARD/Saves ]; then
        mount --bind /mnt/SDCARD/Saves "$chroot_dir/mnt/Saves" 2>/dev/null || true
    fi
}

# Unmount filesystems
umount_chroot() {
    local chroot_dir="$1"
    
    log_info "Unmounting filesystems..."
    
    umount "$chroot_dir/mnt/Roms" 2>/dev/null || true
    umount "$chroot_dir/mnt/BIOS" 2>/dev/null || true
    umount "$chroot_dir/mnt/Saves" 2>/dev/null || true
    umount "$chroot_dir/tmp" 2>/dev/null || true
    umount "$chroot_dir/sys" 2>/dev/null || true
    umount "$chroot_dir/proc" 2>/dev/null || true
    umount "$chroot_dir/dev" 2>/dev/null || true
}

# Enter chroot
enter_chroot() {
    local chroot_dir="$1"
    local command="$2"
    
    log_info "Entering chroot environment..."
    log_info "Device: $(detect_device)"
    log_info "Rootfs: $chroot_dir"
    
    # Set environment variables
    export TERM=xterm-256color
    
    # Enter chroot
    chroot "$chroot_dir" /bin/bash -c "$command"
}

# Print usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS] [COMMAND]

Device-aware Buildroot chroot for TrimUI devices.

Options:
  --rootfs PATH    Use specific rootfs file
  --setup          Setup chroot (extract rootfs)
  --cleanup        Cleanup chroot
  --help           Show this help message

Commands:
  /bin/bash                    Interactive shell
  /usr/bin/python3 script.py  Run Python script
  /usr/bin/node app.js        Run Node.js app
  <any command>                Run any command

Examples:
  $0 /bin/bash                          # Interactive shell
  $0 /usr/bin/python3 -c "print('hi')" # Run Python
  $0 --rootfs /path/to/rootfs.ext2 /bin/bash

Device Tiers:
  TG5050 (Smart Pro S): Full tier (QT6, Wayland, Mesa3D)
  TSP/Brick:            Minimal tier (no QT6/Wayland)
EOF
}

# Setup chroot (extract rootfs)
setup_chroot() {
    local rootfs="$1"
    local chroot_dir="$2"
    
    log_info "Setting up chroot..."
    log_info "Rootfs: $rootfs"
    log_info "Target: $chroot_dir"
    
    # Create directory
    mkdir -p "$chroot_dir"
    
    # Extract rootfs
    log_info "Extracting rootfs..."
    ext2fuse "$rootfs" "$chroot_dir" 2>/dev/null || {
        # Fallback: use debugfs
        log_warn "ext2fuse not available, using debugfs..."
        debugfs -R "dump_all $chroot_dir" "$rootfs" 2>/dev/null || {
            log_error "Cannot extract rootfs. Install ext2fuse or e2fsprogs."
            exit 1
        }
    }
    
    log_info "Chroot setup complete"
}

# Cleanup chroot
cleanup_chroot() {
    local chroot_dir="$1"
    
    log_info "Cleaning up chroot..."
    
    # Unmount first
    umount_chroot "$chroot_dir"
    
    # Remove directory
    rm -rf "$chroot_dir"
    
    log_info "Cleanup complete"
}

# Main
main() {
    local rootfs=""
    local command=""
    local setup=false
    local cleanup=false
    
    # Parse arguments
    while [ $# -gt 0 ]; do
        case "$1" in
            --rootfs)
                rootfs="$2"
                shift 2
                ;;
            --setup)
                setup=true
                shift
                ;;
            --cleanup)
                cleanup=true
                shift
                ;;
            --help|-h)
                usage
                exit 0
                ;;
            *)
                command="$1"
                shift
                ;;
        esac
    done
    
    # Detect device
    local device=$(detect_device)
    log_info "Detected device: $device"
    
    # Select rootfs if not specified
    if [ -z "$rootfs" ]; then
        local result=$(select_rootfs "$device")
        rootfs=$(echo "$result" | cut -d: -f1)
        local tier=$(echo "$result" | cut -d: -f2)
        log_info "Selected rootfs: $rootfs (tier: $tier)"
    fi
    
    # Check memory
    check_memory "$device"
    
    # Setup mode
    if [ "$setup" = true ]; then
        setup_chroot "$rootfs" "/tmp/chroot-${device}"
        exit 0
    fi
    
    # Cleanup mode
    if [ "$cleanup" = true ]; then
        cleanup_chroot "/tmp/chroot-${device}"
        exit 0
    fi
    
    # Default command
    if [ -z "$command" ]; then
        command="/bin/bash"
    fi
    
    # Create chroot directory
    local chroot_dir="/tmp/chroot-${device}"
    mkdir -p "$chroot_dir"
    
    # Extract rootfs if not already done
    if [ ! -f "$chroot_dir/bin/bash" ]; then
        setup_chroot "$rootfs" "$chroot_dir"
    fi
    
    # Mount filesystems
    mount_chroot "$chroot_dir"
    
    # Trap to cleanup on exit
    trap "umount_chroot '$chroot_dir'" EXIT INT TERM
    
    # Enter chroot
    enter_chroot "$chroot_dir" "$command"
    
    # Cleanup
    umount_chroot "$chroot_dir"
}

main "$@"
