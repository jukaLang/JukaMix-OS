#!/bin/sh
# shader_manager.sh - Shader Manager for GLES-compatible shaders
# Manages and applies shaders for RetroArch and other emulators
# POSIX-compatible, works on TrimUI devices
# SAFETY: Includes crash prevention and fallback mechanisms

SHADERS_DIR="/mnt/SDCARD/RetroArch/.retroarch/shaders"
PRESETS_DIR="/mnt/SDCARD/RetroArch/.retroarch/shader_presets"
CONFIG_FILE="/mnt/SDCARD/System/etc/jukamix.json"
LOG_FILE="/tmp/shader_manager.log"
SAFETY_FILE="/tmp/shader_safety"
MAX_SHADER_SIZE=50000  # Max shader file size in bytes (50KB)

# Create directories
mkdir -p "$PRESETS_DIR" 2>/dev/null

# ── Logging ────────────────────────────────────────────────────────────
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [shader] $1" >> "$LOG_FILE" 2>/dev/null
}

# ── Safety: Check if shader file is valid ──────────────────────────────
validate_shader() {
    shader_file="$1"

    # Check file exists
    if [ ! -f "$shader_file" ]; then
        log "SAFETY: Shader file not found: $shader_file"
        return 1
    fi

    # Check file size (prevent oversized shaders)
    file_size=$(wc -c < "$shader_file" 2>/dev/null || echo "0")
    if [ "$file_size" -gt "$MAX_SHADER_SIZE" ]; then
        log "SAFETY: Shader too large: ${file_size} bytes (max: $MAX_SHADER_SIZE)"
        return 1
    fi

    # Check for required GLSL elements
    if ! grep -q "void main()" "$shader_file" 2>/dev/null; then
        log "SAFETY: Shader missing void main(): $shader_file"
        return 1
    fi

    # Check for syntax errors (basic validation)
    if grep -q "syntax error\|error:" "$shader_file" 2>/dev/null; then
        log "SAFETY: Shader contains error markers: $shader_file"
        return 1
    fi

    # Check for infinite loops (basic pattern)
    if grep -q "while.*true\|for.*;;" "$shader_file" 2>/dev/null; then
        log "SAFETY: Shader may have infinite loop: $shader_file"
        return 1
    fi

    return 0
}

# ── Safety: Emergency disable all shaders ──────────────────────────────
emergency_disable() {
    log "SAFETY: Emergency shader disable triggered"

    # Remove all preset files
    rm -f "$PRESETS_DIR"/*.glslp 2>/dev/null

    # Reset RetroArch config
    ra_config="/mnt/SDCARD/RetroArch/.retroarch/retroarch.cfg"
    if [ -f "$ra_config" ]; then
        sed -i 's/video_shader = ".*"/video_shader = ""/' "$ra_config" 2>/dev/null
        sed -i 's/video_smooth = ".*"/video_smooth = "false"/' "$ra_config" 2>/dev/null
    fi

    # Create safety flag
    echo "disabled" > "$SAFETY_FILE" 2>/dev/null

    echo "EMERGENCY: All shaders disabled"
    log "SAFETY: All shaders disabled"
}

# ── Safety: Check if shaders are in emergency mode ─────────────────────
is_emergency() {
    if [ -f "$SAFETY_FILE" ]; then
        return 0
    fi
    return 1
}

# ── Safety: Clear emergency mode ───────────────────────────────────────
clear_emergency() {
    rm -f "$SAFETY_FILE" 2>/dev/null
    log "SAFETY: Emergency mode cleared"
    echo "Emergency mode cleared"
}

# ── Safety: Create recovery preset ─────────────────────────────────────
create_recovery_preset() {
    recovery_file="$PRESETS_DIR/recovery.glslp"

    cat > "$recovery_file" << 'EOF'
# Recovery preset - minimal safe shader
# Created for emergency recovery

shader0 = ""
alias0 = ""
EOF

    log "SAFETY: Recovery preset created"
}

# ── Safety: Backup current config before shader change ─────────────────
backup_config() {
    backup_file="/mnt/SDCARD/RetroArch/.retroarch/retroarch.cfg.bak"

    if [ -f "/mnt/SDCARD/RetroArch/.retroarch/retroarch.cfg" ]; then
        cp "/mnt/SDCARD/RetroArch/.retroarch/retroarch.cfg" "$backup_file" 2>/dev/null
        log "Config backed up to $backup_file"
    fi
}

# ── Safety: Restore config from backup ─────────────────────────────────
restore_config() {
    backup_file="/mnt/SDCARD/RetroArch/.retroarch/retroarch.cfg.bak"

    if [ -f "$backup_file" ]; then
        cp "$backup_file" "/mnt/SDCARD/RetroArch/.retroarch/retroarch.cfg" 2>/dev/null
        log "Config restored from backup"
        echo "Config restored"
    else
        echo "No backup found"
    fi
}

# ── List available shaders ─────────────────────────────────────────────
list_shaders() {
    if is_emergency; then
        echo "⚠️  EMERGENCY MODE - Shaders disabled"
        echo "Run: shader_manager.sh clear-emergency"
        echo ""
    fi

    echo "╔══════════════════════════════════════╗"
    echo "║       JukaMix Shader Manager         ║"
    echo "╠══════════════════════════════════════╣"
    echo "║ Available Shaders:                   ║"
    echo "║                                      ║"
    echo "║ [1]  None (default)                  ║"
    echo "║ [2]  CRT NTSC (v2)                   ║"
    echo "║ [3]  CRT Curved (v2)                 ║"
    echo "║ [4]  Retro TV                        ║"
    echo "║ [5]  LCD Game Boy (v2)               ║"
    echo "║ [6]  LCD GBA                         ║"
    echo "║ [7]  Pixel Perfect (v2)              ║"
    echo "║ [8]  Sharp Bilinear                  ║"
    echo "║ [9]  Scanlines (strong)              ║"
    echo "║                                      ║"
    echo "║ [E]  Emergency disable all           ║"
    echo "║ [R]  Restore config backup           ║"
    echo "║                                      ║"
    echo "╚══════════════════════════════════════╝"
}

# ── Get shader path by ID ──────────────────────────────────────────────
get_shader_path() {
    case "$1" in
        2|crt_ntsc)         echo "shaders/gles2/shaders.crt-ntsc.glsl" ;;
        3|crt_curved)       echo "shaders/gles2/shaders.crt-curved-v2.glsl" ;;
        4|retro_tv)         echo "shaders/gles2/shaders.retro-tv.glsl" ;;
        5|lcd_gameboy)      echo "shaders/gles2/shaders.lcd-gameboy-v2.glsl" ;;
        6|lcd_gba)          echo "shaders/gles2/shaders.lcd-gba.glsl" ;;
        7|pixel_perfect)    echo "shaders/gles2/shaders.pixel-perfect-v2.glsl" ;;
        8|sharp_bilinear)   echo "shaders/gles2/shaders.sharp-bilinear.glsl" ;;
        9|scanlines_strong) echo "shaders/gles2/shaders.scanline-strong.glsl" ;;
        *) echo "" ;;
    esac
}

# ── Get shader name ────────────────────────────────────────────────────
get_shader_name() {
    case "$1" in
        1|none)             echo "None" ;;
        2|crt_ntsc)         echo "CRT NTSC (v2)" ;;
        3|crt_curved)       echo "CRT Curved (v2)" ;;
        4|retro_tv)         echo "Retro TV" ;;
        5|lcd_gameboy)      echo "LCD Game Boy (v2)" ;;
        6|lcd_gba)          echo "LCD GBA" ;;
        7|pixel_perfect)    echo "Pixel Perfect (v2)" ;;
        8|sharp_bilinear)   echo "Sharp Bilinear" ;;
        9|scanlines_strong) echo "Scanlines (strong)" ;;
        *) echo "Unknown" ;;
    esac
}

# ── Apply shader with safety checks ───────────────────────────────────
apply_shader() {
    shader_id="$1"
    system="${2:-all}"

    # Check emergency mode
    if is_emergency; then
        echo "⚠️  Emergency mode active - cannot apply shaders"
        echo "Run: shader_manager.sh clear-emergency"
        return 1
    fi

    preset_file="$PRESETS_DIR/${system}.glslp"
    shader_path=$(get_shader_path "$shader_id")
    shader_name=$(get_shader_name "$shader_id")

    # Validate shader file if not "none"
    if [ -n "$shader_path" ]; then
        full_path="$SHADERS_DIR/$shader_path"

        if ! validate_shader "$full_path"; then
            echo "❌ Shader validation failed: $shader_name"
            echo "   File: $full_path"
            echo ""
            echo "Options:"
            echo "  1. Try a different shader"
            echo "  2. Run: shader_manager.sh emergency"
            return 1
        fi
    fi

    # Backup config before change
    backup_config

    # Apply shader
    if [ -z "$shader_path" ]; then
        # Disable shaders
        cat > "$preset_file" << 'EOF'
# Shader preset: None
shader0 = ""
EOF
    else
        cat > "$preset_file" << EOF
# Shader preset: $shader_name
# System: $system
# Applied: $(date)

shader0 = "$shader_path"
alias0 = ""
shader0_linear = true
shader0_filter = 1
shader0_scale = 1.0
EOF
    fi

    log "Applied $shader_name for $system"
    echo "✅ Applied: $shader_name"
    echo ""
    echo "If RetroArch crashes, run:"
    echo "  shader_manager.sh emergency"
    echo "  shader_manager.sh restore"
}

# ── Create per-system presets with validation ──────────────────────────
create_system_presets() {
    echo "Creating per-system shader presets..."

    validated=0
    failed=0

    # Define system -> shader mapping
    # Format: system:shader_id
    presets="NES:crt_ntsc SNES:crt_ntsc GB:lcd_gameboy GBC:lcd_gameboy GBA:lcd_gba GEN:retro_tv PSX:crt_curved N64:scanlines_strong PSP:sharp_bilinear NDS:lcd_gba ARCADE:crt_curved NEOGEO:crt_ntsc PCE:retro_tv WS:lcd_gba LYNX:lcd_gba NGP:lcd_gameboy ATARI:scanlines_strong DOS:sharp_bilinear"

    for preset in $presets; do
        system=$(echo "$preset" | cut -d: -f1)
        shader_id=$(echo "$preset" | cut -d: -f2)

        # Validate shader before applying
        shader_path=$(get_shader_path "$shader_id")
        full_path="$SHADERS_DIR/$shader_path"

        if validate_shader "$full_path" 2>/dev/null; then
            apply_shader "$shader_id" "$system" >/dev/null 2>&1
            echo "  ✅ $system -> $shader_id"
            validated=$((validated + 1))
        else
            echo "  ⚠️  $system -> $shader_id (validation failed, skipping)"
            failed=$((failed + 1))
        fi
    done

    echo ""
    echo "Presets created: $validated"
    if [ "$failed" -gt 0 ]; then
        echo "Failed validations: $failed"
    fi

    log "Per-system presets created: $validated ok, $failed failed"
}

# ── Apply device-specific optimizations ────────────────────────────────
apply_device_optimizations() {
    device=$(cat /etc/trimui_device.txt 2>/dev/null || echo "tsp")

    echo "Applying device optimizations for: $device"

    ra_config="/mnt/SDCARD/RetroArch/.retroarch/retroarch.cfg"
    [ -f "$ra_config" ] || { echo "RetroArch config not found"; return 1; }

    # Backup first
    backup_config

    case "$device" in
        tg5050)
            sed -i 's/video_smooth = ".*"/video_smooth = "true"/' "$ra_config" 2>/dev/null
            sed -i 's/video_driver = ".*"/video_driver = "gl"/' "$ra_config" 2>/dev/null
            sed -i 's/video_fullscreen = ".*"/video_fullscreen = "true"/' "$ra_config" 2>/dev/null
            ;;
        brick|brick_pro)
            sed -i 's/video_smooth = ".*"/video_smooth = "true"/' "$ra_config" 2>/dev/null
            sed -i 's/video_driver = ".*"/video_driver = "gl"/' "$ra_config" 2>/dev/null
            sed -i 's/video_fullscreen = ".*"/video_fullscreen = "true"/' "$ra_config" 2>/dev/null
            ;;
        *)
            sed -i 's/video_smooth = ".*"/video_smooth = "false"/' "$ra_config" 2>/dev/null
            sed -i 's/video_driver = ".*"/video_driver = "gl"/' "$ra_config" 2>/dev/null
            ;;
    esac

    log "Applied device optimizations for $device"
    echo "✅ Device optimizations applied"
}

# ── Get current shader ─────────────────────────────────────────────────
get_current_shader() {
    system="${1:-all}"
    preset_file="$PRESETS_DIR/${system}.glslp"

    if [ -f "$preset_file" ]; then
        shader_line=$(grep "^shader0 = " "$preset_file" 2>/dev/null | head -1)
        if [ -n "$shader_line" ]; then
            shader=$(echo "$shader_line" | cut -d'"' -f2)
            if [ -z "$shader" ]; then
                echo "none"
            else
                basename "$shader" .glsl
            fi
        else
            echo "none"
        fi
    else
        echo "none"
    fi
}

# ── Reset shaders ──────────────────────────────────────────────────────
reset_shaders() {
    system="${1:-all}"
    preset_file="$PRESETS_DIR/${system}.glslp"

    # Backup before reset
    backup_config

    rm -f "$preset_file" 2>/dev/null

    # Reset RetroArch config
    ra_config="/mnt/SDCARD/RetroArch/.retroarch/retroarch.cfg"
    if [ -f "$ra_config" ]; then
        sed -i 's/video_shader = ".*"/video_shader = ""/' "$ra_config" 2>/dev/null
    fi

    log "Reset shaders for $system"
    echo "✅ Shaders reset to default"
}

# ── List current presets ───────────────────────────────────────────────
list_presets() {
    echo "Current Shader Presets:"
    echo "======================="
    echo ""

    count=0
    find "$PRESETS_DIR" -name "*.glslp" -type f 2>/dev/null | sort | while read -r preset; do
        [ -f "$preset" ] || continue
        system=$(basename "$preset" .glslp)
        shader=$(get_current_shader "$system")
        echo "  $system: $shader"
        count=$((count + 1))
    done

    if [ "$count" -eq 0 ]; then
        echo "  No presets configured"
    fi
}

# ── Validate all shaders ───────────────────────────────────────────────
validate_all_shaders() {
    echo "Validating all shaders..."
    echo ""

    valid=0
    invalid=0

    find "$SHADERS_DIR" -name "*.glsl" -type f 2>/dev/null | while read -r shader; do
        shader_name=$(basename "$shader")
        if validate_shader "$shader" 2>/dev/null; then
            echo "  ✅ $shader_name"
            valid=$((valid + 1))
        else
            echo "  ❌ $shader_name"
            invalid=$((invalid + 1))
        fi
    done

    echo ""
    echo "Validation complete"
    log "Shader validation: all checked"
}

# ── Main ───────────────────────────────────────────────────────────────
case "${1:-}" in
    list)
        list_shaders
        ;;
    apply)
        shader="${2:-none}"
        system="${3:-all}"
        apply_shader "$shader" "$system"
        ;;
    create-presets)
        create_system_presets
        ;;
    device-optimize)
        apply_device_optimizations
        ;;
    status)
        system="${2:-all}"
        current=$(get_current_shader "$system")
        echo "Current shader for $system: $current"
        ;;
    presets)
        list_presets
        ;;
    reset)
        system="${2:-all}"
        reset_shaders "$system"
        ;;
    emergency)
        emergency_disable
        ;;
    clear-emergency)
        clear_emergency
        ;;
    restore)
        restore_config
        ;;
    validate)
        validate_all_shaders
        ;;
    *)
        echo "JukaMix Shader Manager"
        echo "Usage: shader_manager.sh <command> [args]"
        echo ""
        echo "Commands:"
        echo "  list              List available shaders"
        echo "  apply <id> [sys]  Apply shader"
        echo "  create-presets    Create per-system defaults"
        echo "  device-optimize   Optimize for device"
        echo "  status [sys]      Show current shader"
        echo "  presets           List current presets"
        echo "  reset [sys]       Reset to default"
        echo "  emergency         Disable all shaders (crash recovery)"
        echo "  clear-emergency   Re-enable shaders"
        echo "  restore           Restore config backup"
        echo "  validate          Check all shader files"
        echo ""
        echo "Safety Commands:"
        echo "  emergency         - Use if RetroArch crashes after shader"
        echo "  restore           - Restore config from backup"
        echo "  validate          - Check shader files for errors"
        ;;
esac
