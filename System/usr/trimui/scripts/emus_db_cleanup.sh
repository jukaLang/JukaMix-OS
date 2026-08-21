#!/bin/sh
# emus_db_cleanup.sh - Clean up emus database and cache
#
# Usage:
#   ./emus_db_cleanup.sh          # Full cleanup
#   ./emus_db_cleanup.sh --fast   # Quick cleanup (skip large files)
#   ./emus_db_cleanup.sh --dry    # Dry run (show what would be deleted)

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SD_ROOT="/mnt/SDCARD"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[CLEAN]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[CLEAN]${NC} $*"; }
log_error() { echo -e "${RED}[CLEAN]${NC} $*" >&2; }

# Cleanup paths
CLEANUP_PATHS=(
    "$SD_ROOT/.Trash"
    "$SD_ROOT/lost+found"
    "$SD_ROOT/System/tmp"
    "$SD_ROOT/System/var/cache"
    "$SD_ROOT/RetroArch/.retroarch/.cache"
    "$SD_ROOT/Apps/PortMaster/PortMaster/gptokeyb/.cache"
    "$SD_ROOT/Apps/Scraper/scraper.log"
    "$SD_ROOT/Roms/recentlist.json.tmp"
    "/tmp/trimui_osd"
    "/tmp/jukamix_remap"
)

# Count and size before cleanup
measure_before() {
    local total_size=0
    local total_files=0
    
    for path in "${CLEANUP_PATHS[@]}"; do
        if [ -e "$path" ]; then
            local size=$(du -sb "$path" 2>/dev/null | cut -f1)
            local files=$(find "$path" -type f 2>/dev/null | wc -l)
            total_size=$((total_size + size))
            total_files=$((total_files + files))
        fi
    done
    
    echo "$total_files $total_size"
}

# Perform cleanup
do_cleanup() {
    local dry_run="$1"
    local fast="$2"
    local cleaned=0
    
    for path in "${CLEANUP_PATHS[@]}"; do
        if [ ! -e "$path" ]; then
            continue
        fi
        
        # Skip large directories in fast mode
        if [ "$fast" = "true" ]; then
            local size=$(du -sb "$path" 2>/dev/null | cut -f1)
            if [ "$size" -gt 10485760 ]; then  # Skip if > 10MB
                log_warn "Skipping large path: $path ($(du -h "$path" | cut -f1))"
                continue
            fi
        fi
        
        if [ "$dry_run" = "true" ]; then
            log_info "Would delete: $path"
        else
            log_info "Deleting: $path"
            rm -rf "$path"
            cleaned=$((cleaned + 1))
        fi
    done
    
    # Clean log files
    if [ "$fast" != "true" ]; then
        log_info "Cleaning log files..."
        find "$SD_ROOT" -name "*.log" -type f -mtime +7 -delete 2>/dev/null || true
        find "$SD_ROOT" -name "*.log.*" -type f -mtime +7 -delete 2>/dev/null || true
    fi
    
    # Clean temporary files
    log_info "Cleaning temporary files..."
    find "$SD_ROOT" -name "*.tmp" -type f -delete 2>/dev/null || true
    find "$SD_ROOT" -name "*.temp" -type f -delete 2>/dev/null || true
    
    echo "$cleaned"
}

# Main
main() {
    local dry_run=false
    local fast=false
    
    case "${1:-}" in
        --dry|-d)
            dry_run=true
            ;;
        --fast|-f)
            fast=true
            ;;
        --help|-h)
            echo "Usage: $0 [--dry|--fast|--help]"
            echo ""
            echo "Options:"
            echo "  --dry, -d    Dry run (show what would be deleted)"
            echo "  --fast, -f   Quick cleanup (skip large files)"
            echo "  --help, -h   Show this help"
            exit 0
            ;;
    esac
    
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}   Emus Database Cleanup${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    
    # Measure before (POSIX-compatible using pipe)
    before_files=$(measure_before | awk '{print $1}')
    before_size=$(measure_before | awk '{print $2}')
    log_info "Before: $before_files files ($(echo "scale=2; $before_size / 1048576" | bc)MB)"
    
    # Perform cleanup
    cleaned=$(do_cleanup "$dry_run" "$fast")
    
    # Measure after (only if not dry run)
    if [ "$dry_run" = "false" ]; then
        after_files=$(measure_before | awk '{print $1}')
        after_size=$(measure_before | awk '{print $2}')
        freed=$((before_size - after_size))
        log_info "After: $after_files files ($(echo "scale=2; $after_size / 1048576" | bc)MB)"
        log_info "Freed: $(echo "scale=2; $freed / 1048576" | bc)MB"
    fi
    
    echo ""
    log_info "Cleanup complete!"
}

main "$@"
