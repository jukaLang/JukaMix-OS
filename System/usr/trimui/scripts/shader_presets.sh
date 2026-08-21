#!/bin/sh
# shader_presets.sh - Auto-apply shaders by system
# POSIX-compatible, works on TrimUI devices
# SAFETY: Includes validation and fallback mechanisms

SHADERS_DIR="/mnt/SDCARD/RetroArch/.retroarch/shaders"
PRESETS_DIR="/mnt/SDCARD/trimui/shader_presets"
LOG_FILE="/tmp/shader_presets.log"

# Create directories
mkdir -p "$PRESETS_DIR" 2>/dev/null

# ── Logging ────────────────────────────────────────────────────────────
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [shader_preset] $1" >> "$LOG_FILE" 2>/dev/null
}

# ── Safety: Check if shader file is valid ──────────────────────────────
validate_shader() {
    shader_file="$1"

    [ -f "$shader_file" ] || return 1
    [ -s "$shader_file" ] || return 1  # Not empty

    # Check max size (50KB)
    file_size=$(wc -c < "$shader_file" 2>/dev/null || echo "0")
    [ "$file_size" -lt 50000 ] || return 1

    return 0
}

# ── Get system from ROM extension ──────────────────────────────────────
get_system() {
    rom="$1"
    ext=$(basename "$rom" | sed 's/.*\.//' | tr '[:upper:]' '[:lower:]')

    case "$ext" in
        nes|fds|unf|unif)           echo "nes" ;;
        smc|sfc|fig|swc)            echo "snes" ;;
        gb|gbc|sgb)                 echo "gb" ;;
        gba|agb)                    echo "gba" ;;
        nds)                        echo "nds" ;;
        gen|md|sms|gg|sg)           echo "genesis" ;;
        pce)                        echo "pce" ;;
        ngp|ngc)                    echo "ngp" ;;
        ws|wsc)                     echo "wswan" ;;
        lynx)                       echo "lynx" ;;
        col)                        echo "colecovision" ;;
        integ)                      echo "intellivision" ;;
        2600)                       echo "atari2600" ;;
        a52|a78)                    echo "atari7800" ;;
        z64|n64|v64|j64)            echo "n64" ;;
        iso|bin|cue|cbn|exe|pbp|cso) echo "psx" ;;
        iso|cso)                    echo "psp" ;;
        *)                          echo "unknown" ;;
    esac
}

# ── Get default shader for system ──────────────────────────────────────
get_default_shader() {
    system="$1"
    device="${2:-tsp}"

    # Use our GLES2 shaders instead of system shaders
    case "$system" in
        nes|snes|genesis|pce|atari2600|atari7800|colecovision|intellivision)
            echo "shaders/gles2/shaders.crt-ntsc.glsl"
            ;;
        gb|gbc)
            echo "shaders/gles2/shaders.lcd-gameboy-v2.glsl"
            ;;
        gba)
            echo "shaders/gles2/shaders.lcd-gba.glsl"
            ;;
        nds)
            echo "shaders/gles2/shaders.lcd-gba.glsl"
            ;;
        n64)
            echo "shaders/gles2/shaders.scanline-strong.glsl"
            ;;
        psx)
            if [ "$device" = "tg5050" ]; then
                echo "shaders/gles2/shaders.crt-curved-v2.glsl"
            else
                echo "shaders/gles2/shaders.crt-ntsc.glsl"
            fi
            ;;
        psp)
            echo "shaders/gles2/shaders.sharp-bilinear.glsl"
            ;;
        *)
            echo ""
            ;;
    esac
}

# ── Apply shader preset ────────────────────────────────────────────────
apply_shader() {
    rom="$1"
    device="${2:-tsp}"
    shader="${3:-}"

    system=$(get_system "$rom")

    if [ -z "$shader" ]; then
        shader=$(get_default_shader "$system" "$device")
    fi

    if [ -z "$shader" ]; then
        echo "No shader for $system"
        return 0
    fi

    # Validate shader exists
    full_path="$SHADERS_DIR/$shader"
    if ! validate_shader "$full_path"; then
        log "WARNING: Shader validation failed: $shader"
        echo "Shader not found or invalid: $shader"
        return 1
    fi

    # Save preset for this game
    game_name=$(basename "$rom")
    preset_file="$PRESETS_DIR/${game_name}.glslp"

    cat > "$preset_file" << EOF
# Shader preset for $game_name
# System: $system
# Applied: $(date)

shader0 = "$shader"
alias0 = ""
shader0_linear = true
shader0_filter = 1
shader0_scale = 1.0
EOF

    log "Applied shader: $shader for $system ($game_name)"
    echo "Applied shader: $(basename "$shader" .glsl) for $system"
}

# ── List available shaders ─────────────────────────────────────────────
list_shaders() {
    echo "Available GLES2 shaders:"
    echo ""

    count=0
    find "$SHADERS_DIR/gles2" -name "*.glsl" -type f 2>/dev/null | sort | while read -r shader; do
        shader_name=$(basename "$shader" .glsl)
        if validate_shader "$shader" 2>/dev/null; then
            echo "  ✅ $shader_name"
        else
            echo "  ❌ $shader_name (invalid)"
        fi
        count=$((count + 1))
    done

    if [ "$count" -eq 0 ]; then
        echo "  No shaders found"
    fi
}

# ── List presets ────────────────────────────────────────────────────────
list_presets() {
    echo "Saved presets:"
    echo ""

    count=0
    find "$PRESETS_DIR" -name "*.glslp" -type f 2>/dev/null | sort | while read -r preset; do
        name=$(basename "$preset" .glslp)
        shader=$(grep "^shader0 = " "$preset" 2>/dev/null | head -1 | cut -d'"' -f2)
        if [ -n "$shader" ]; then
            echo "  $name -> $(basename "$shader" .glsl)"
        else
            echo "  $name -> none"
        fi
        count=$((count + 1))
    done

    if [ "$count" -eq 0 ]; then
        echo "  No presets saved"
    fi
}

# ── Clear all presets ──────────────────────────────────────────────────
clear_presets() {
    rm -f "$PRESETS_DIR"/*.glslp 2>/dev/null
    echo "All presets cleared"
    log "All presets cleared"
}

# ── Main ───────────────────────────────────────────────────────────────
case "${1:-}" in
    apply)
        apply_shader "${2:-}" "${3:-tsp}" "${4:-}"
        ;;
    detect)
        system=$(get_system "${2:-}")
        shader=$(get_default_shader "$system" "${3:-tsp}")
        echo "$shader"
        ;;
    system)
        get_system "${2:-}"
        ;;
    list)
        list_shaders
        ;;
    presets)
        list_presets
        ;;
    clear)
        clear_presets
        ;;
    *)
        echo "Shader Presets"
        echo "Usage: shader_presets.sh <command> [args]"
        echo ""
        echo "Commands:"
        echo "  apply <rom> [device] [shader] - Apply shader preset"
        echo "  detect <rom> [device]         - Detect best shader"
        echo "  system <rom>                  - Get system from ROM"
        echo "  list                          - List available shaders"
        echo "  presets                       - List saved presets"
        echo "  clear                         - Clear all presets"
        ;;
esac
