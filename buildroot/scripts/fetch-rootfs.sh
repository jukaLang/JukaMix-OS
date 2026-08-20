#!/bin/sh
# fetch-rootfs.sh - Download Buildroot rootfs from GitHub releases
#
# Usage:
#   ./fetch-rootfs.sh              # Fetch all rootfs
#   ./fetch-rootfs.sh tg5050       # Fetch only TG5050 rootfs
#   ./fetch-rootfs.sh tsp          # Fetch only TSP/Brick rootfs
#
# Output:
#   buildroot/output/rootfs-tg5050.ext2
#   buildroot/output/rootfs-tsp-brick.ext2
#
# These files are built by GitHub Actions and uploaded as release assets.
# See .github/workflows/JukaMix-OS Release.yml for build configuration.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTPUT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)/output"

# GitHub release URL
RELEASE_BASE="https://github.com/jukaLang/JukaMix-OS/releases/download"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
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

# Download file with retry
download_file() {
    local url="$1"
    local output="$2"
    
    log_info "Downloading: $url"
    
    if command -v curl >/dev/null 2>&1; then
        curl -fL --retry 3 -o "$output" "$url"
    elif command -v wget >/dev/null 2>&1; then
        wget -q --tries=3 -O "$output" "$url"
    else
        log_error "Neither curl nor wget available"
        return 1
    fi
    
    # Check if download succeeded
    if [ ! -s "$output" ]; then
        log_error "Download failed: $output is empty"
        rm -f "$output"
        return 1
    fi
    
    log_info "Downloaded: $(ls -lh "$output" | awk '{print $5}')"
}

# Fetch TG5050 rootfs
fetch_tg5050() {
    local output="$OUTPUT_DIR/rootfs-tg5050.ext2"
    local url="${RELEASE_BASE}/latest/download/rootfs-tg5050.ext2"
    
    if [ -f "$output" ]; then
        log_warn "TG5050 rootfs already exists: $output"
        return 0
    fi
    
    mkdir -p "$OUTPUT_DIR"
    download_file "$url" "$output"
}

# Fetch TSP/Brick rootfs
fetch_tsp_brick() {
    local output="$OUTPUT_DIR/rootfs-tsp-brick.ext2"
    local url="${RELEASE_BASE}/latest/download/rootfs-tsp-brick.ext2"
    
    if [ -f "$output" ]; then
        log_warn "TSP/Brick rootfs already exists: $output"
        return 0
    fi
    
    mkdir -p "$OUTPUT_DIR"
    download_file "$url" "$output"
}

# Print usage
usage() {
    cat << EOF
Usage: $0 [DEVICE]

Download Buildroot rootfs from GitHub releases.

Options:
  tg5050    Download only TG5050 rootfs (1GB, full tier)
  tsp       Download only TSP/Brick rootfs (512MB, minimal tier)
  all       Download all rootfs (default)
  --help    Show this help message

Output:
  buildroot/output/rootfs-tg5050.ext2     (1GB, full tier)
  buildroot/output/rootfs-tsp-brick.ext2  (512MB, minimal tier)

Examples:
  $0              # Download all
  $0 tg5050       # Download TG5050 only
  $0 tsp          # Download TSP/Brick only
EOF
}

# Main
main() {
    local device="${1:-all}"
    
    case "$device" in
        tg5050)
            fetch_tg5050
            ;;
        tsp)
            fetch_tsp_brick
            ;;
        all)
            fetch_tg5050
            fetch_tsp_brick
            ;;
        --help|-h)
            usage
            ;;
        *)
            log_error "Unknown device: $device"
            usage
            exit 1
            ;;
    esac
    
    log_info "=== Download Complete ==="
    log_info "Output files:"
    ls -lh "$OUTPUT_DIR"/*.ext2 2>/dev/null || log_warn "No rootfs files found"
}

main "$@"
