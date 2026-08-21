#!/bin/sh
# language_patcher.sh - Apply device-specific language patches
#
# Usage:
#   ./language_patcher.sh [language_code]
#   ./language_patcher.sh en
#   ./language_patcher.sh --auto  (detect from config)

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LANG_DIR="/mnt/SDCARD/trimui/res/lang"
PATCH_DIR="/mnt/SDCARD/System/usr/trimui/patches/lang"
CONFIG_FILE="/mnt/SDCARD/System/usr/trimui/language.conf"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[LANG]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[LANG]${NC} $*"; }
log_error() { echo -e "${RED}[LANG]${NC} $*" >&2; }

# Get device code
get_device() {
    if [ -r /etc/trimui_device.txt ]; then
        tr -d '[:space:]' < /etc/trimui_device.txt 2>/dev/null | head -n 1
    else
        echo "unknown"
    fi
}

# Get language from config or argument
get_language() {
    local lang="$1"
    
    if [ -z "$lang" ] || [ "$lang" = "--auto" ]; then
        if [ -f "$CONFIG_FILE" ]; then
            lang=$(cat "$CONFIG_FILE" 2>/dev/null | tr -d '[:space:]')
        fi
    fi
    
    # Default to English
    echo "${lang:-en}"
}

# Apply language patch for device
apply_patch() {
    local lang="$1"
    local device="$2"
    
    # Check if patch exists
    local patch_file="$PATCH_DIR/${device}/${lang}.lang"
    local base_file="$PATCH_DIR/base/${lang}.lang"
    
    if [ -f "$patch_file" ]; then
        log_info "Applying device-specific patch: $device/$lang"
        cp "$patch_file" "$LANG_DIR/${lang}.lang"
        return 0
    elif [ -f "$base_file" ]; then
        log_info "Applying base patch: $lang"
        cp "$base_file" "$LANG_DIR/${lang}.lang"
        return 0
    else
        log_warn "No patch found for $lang on $device"
        return 1
    fi
}

# Create short version of language file
create_short_version() {
    local lang="$1"
    local long_file="$LANG_DIR/${lang}.lang"
    local short_file="$LANG_DIR/${lang}.lang.short"
    
    if [ ! -f "$long_file" ]; then
        return 1
    fi
    
    # Create short version (first 50 lines or key strings)
    head -50 "$long_file" > "$short_file"
    log_info "Created short version: $short_file"
}

# List available languages
list_languages() {
    echo "Available languages:"
    for f in "$LANG_DIR"/*.lang; do
        [ -f "$f" ] || continue
        local lang=$(basename "$f" .lang)
        echo "  $lang"
    done
}

# Main
main() {
    local lang="${1:---auto}"
    local device=$(get_device)
    
    case "$lang" in
        --list|-l)
            list_languages
            exit 0
            ;;
        --help|-h)
            echo "Usage: $0 [language_code|--auto|--list]"
            echo ""
            echo "Options:"
            echo "  language_code   Apply language patch (e.g., en, fr, de)"
            echo "  --auto          Use language from config file"
            echo "  --list          List available languages"
            echo "  --help          Show this help"
            exit 0
            ;;
    esac
    
    lang=$(get_language "$lang")
    
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}   Language Patcher${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    log_info "Device: $device"
    log_info "Language: $lang"
    echo ""
    
    # Apply patch
    if apply_patch "$lang" "$device"; then
        create_short_version "$lang"
        log_info "Language patch applied successfully"
    else
        log_error "Failed to apply language patch"
        exit 1
    fi
}

main "$@"
