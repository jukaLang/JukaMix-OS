#!/bin/sh
# System/usr/trimui/scripts/shader_presets.sh
# Shader Presets - Auto-apply shaders by system

SHADERS_DIR="/mnt/SDCARD/RetroArch/.retroarch/shaders"
PRESETS_DIR="/mnt/SDCARD/trimui/shader_presets"

# Create presets directory
mkdir -p "$PRESETS_DIR"

# ── Get system from ROM extension ──────────────────────────────────────
get_system() {
    local rom="$1"
    local ext="${rom##*.}"
    ext=$(echo "$ext" | tr '[:upper:]' '[:lower:]')
    
    case "$ext" in
        nes|fds|unf|unif)           echo "nes" ;;
        smc|sfc|fig|swc)            echo "snes" ;;
        gb|gbc|sgb)                 echo "gb" ;;
        gba|agb|bin)                echo "gba" ;;
        nds|nds\.gz)                echo "nds" ;;
        gen|md|bin|sms|gg|sg)       echo "genesis" ;;
        pce)                        echo "pce" ;;
        ngp|ngc)                    echo "ngp" ;;
        ws|wsc)                     echo "wswan" ;;
        lynx)                       echo "lynx" ;;
        col|col\.gz)                echo "colecovision" ;;
        integ)                      echo "intellivision" ;;
        2600)                       echo "atari2600" ;;
        a52|a78)                    echo "atari7800" ;;
        z64|n64|v64|j64)            echo "n64" ;;
        iso|bin|cue|cbn|exe|pbp)    echo "psx" ;;
        *)                          echo "unknown" ;;
    esac
}

# ── Get default shader for system ──────────────────────────────────────
get_default_shader() {
    local system="$1"
    local device="${2:-tsp}"
    
    # Only apply shaders on capable devices
    if [ "$device" = "brick" ]; then
        echo ""
        return
    fi
    
    case "$system" in
        nes|snes|genesis|pce|atari2600|atari7800|colecovision|intellivision)
            echo "crt-geom.glslp"
            ;;
        gb|gbc)
            echo "lcd3x.glslp"
            ;;
        gba)
            echo "lcd3x.glslp"
            ;;
        nds)
            echo "lcd3x.glslp"
            ;;
        n64|psx)
            if [ "$device" = "tg5050" ]; then
                echo "crt-geom.glslp"
            else
                echo ""
            fi
            ;;
        *)
            echo ""
            ;;
    esac
}

# ── Apply shader preset ────────────────────────────────────────────────
apply_shader() {
    local rom="$1"
    local device="${2:-tsp}"
    local shader="${3:-}"
    
    local system=$(get_system "$rom")
    
    if [ -z "$shader" ]; then
        shader=$(get_default_shader "$system" "$device")
    fi
    
    if [ -z "$shader" ]; then
        echo "No shader for $system"
        return
    fi
    
    # Check if shader exists
    if [ ! -f "$SHADERS_DIR/$shader" ]; then
        echo "Shader not found: $shader"
        return 1
    fi
    
    # Save preset for this game
    local game_name=$(basename "$rom")
    local preset_file="$PRESETS_DIR/${game_name}.slangp"
    
    echo "# Shader preset for $game_name" > "$preset_file"
    echo "system = $system" >> "$preset_file"
    echo "shader = $SHADERS_DIR/$shader" >> "$preset_file"
    
    echo "Applied shader: $shader for $system"
}

# ── List available shaders ─────────────────────────────────────────────
list_shaders() {
    echo "Available shaders:"
    echo ""
    
    ls "$SHADERS_DIR"/*.glslp 2>/dev/null | while read -r shader; do
        echo "  $(basename "$shader")"
    done
}

# ── List presets ────────────────────────────────────────────────────────
list_presets() {
    echo "Saved presets:"
    echo ""
    
    ls "$PRESETS_DIR"/*.slangp 2>/dev/null | while read -r preset; do
        local name=$(basename "$preset" .slangp)
        local shader=$(grep "^shader" "$preset" | cut -d= -f2 | xargs)
        echo "  $name -> $(basename "$shader")"
    done
}

# ── Main ──────────────────────────────────────────────────────────────
case "${1:-}" in
    apply)
        apply_shader "$2" "$3" "$4"
        ;;
    detect)
        local system=$(get_system "$2")
        local shader=$(get_default_shader "$system" "${3:-tsp}")
        echo "$shader"
        ;;
    system)
        get_system "$2"
        ;;
    list)
        list_shaders
        ;;
    presets)
        list_presets
        ;;
    *)
        echo "Usage: shader_presets.sh {apply|detect|system|list|presets} [args]" >&2
        echo "" >&2
        echo "Commands:" >&2
        echo "  apply <rom> [device] [shader] - Apply shader preset" >&2
        echo "  detect <rom> [device]         - Detect best shader" >&2
        echo "  system <rom>                  - Get system from ROM" >&2
        echo "  list                          - List available shaders" >&2
        echo "  presets                       - List saved presets" >&2
        exit 1
        ;;
esac
