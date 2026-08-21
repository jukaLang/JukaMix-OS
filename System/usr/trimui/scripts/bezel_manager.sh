#!/bin/sh
# bezel_manager.sh - Bezel/Background Manager for JukaMix
# Manages decorative bezels and backgrounds for retro games

BEZELS_DIR="/mnt/SDCARD/System/bezels"
BACKGROUNDS_DIR="/mnt/SDCARD/System/backgrounds"
CONFIG_DIR="/mnt/SDCARD/RetroArch/.retroarch"
LOG_FILE="/tmp/bezel_manager.log"

# Create directories
mkdir -p "$BEZELS_DIR" "$BACKGROUNDS_DIR" 2>/dev/null

# ── Logging ────────────────────────────────────────────────────────────
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [bezel] $1" >> "$LOG_FILE" 2>/dev/null
}

# ── Install default bezels ─────────────────────────────────────────────
install_default_bezels() {
    echo "Installing default bezels..."
    
    # NES bezel
    cat > "$BEZELS_DIR/nes.cfg" << 'EOF'
# NES Bezel Configuration
video_shader = "shaders/shaders_glsl/borders/shaders/standard.glslp"
video_fullscreen_x = 1280
video_fullscreen_y = 720
video_scale_type = 0
video_smooth = false
EOF
    
    # SNES bezel
    cat > "$BEZELS_DIR/snes.cfg" << 'EOF'
# SNES Bezel Configuration
video_shader = "shaders/shaders_glsl/borders/shaders/standard.glslp"
video_fullscreen_x = 1280
video_fullscreen_y = 720
video_scale_type = 0
video_smooth = false
EOF
    
    # Game Boy bezel (with green tint)
    cat > "$BEZELS_DIR/gb.cfg" << 'EOF'
# Game Boy Bezel Configuration
video_shader = "shaders/shaders_glsl/handheld/shaders/gameboy.glslp"
video_fullscreen_x = 1280
video_fullscreen_y = 720
video_scale_type = 0
video_smooth = false
EOF
    
    # GBA bezel
    cat > "$BEZELS_DIR/gba.cfg" << 'EOF'
# GBA Bezel Configuration
video_shader = "shaders/shaders_glsl/handheld/shaders/gba.glslp"
video_fullscreen_x = 1280
video_fullscreen_y = 720
video_scale_type = 0
video_smooth = false
EOF
    
    # Genesis bezel
    cat > "$BEZELS_DIR/genesis.cfg" << 'EOF'
# Genesis/Mega Drive Bezel Configuration
video_shader = "shaders/shaders_glsl/borders/shaders/standard.glslp"
video_fullscreen_x = 1280
video_fullscreen_y = 720
video_scale_type = 0
video_smooth = false
EOF
    
    # PS1 bezel
    cat > "$BEZELS_DIR/psx.cfg" << 'EOF'
# PlayStation Bezel Configuration
video_shader = "shaders/shaders_glsl/crt/shaders/crt-geom.glslp"
video_fullscreen_x = 1280
video_fullscreen_y = 720
video_scale_type = 0
video_smooth = true
EOF
    
    # N64 bezel
    cat > "$BEZELS_DIR/n64.cfg" << 'EOF'
# Nintendo 64 Bezel Configuration
video_shader = ""
video_fullscreen_x = 1280
video_fullscreen_y = 720
video_scale_type = 0
video_smooth = true
EOF
    
    # PSP bezel
    cat > "$BEZELS_DIR/psp.cfg" << 'EOF'
# PlayStation Portable Bezel Configuration
video_shader = ""
video_fullscreen_x = 1280
video_fullscreen_y = 720
video_scale_type = 0
video_smooth = true
EOF
    
    # NDS bezel
    cat > "$BEZELS_DIR/nds.cfg" << 'EOF'
# Nintendo DS Bezel Configuration
video_shader = ""
video_fullscreen_x = 1280
video_fullscreen_y = 720
video_scale_type = 0
video_smooth = false
EOF
    
    # Arcade bezel
    cat > "$BEZELS_DIR/arcade.cfg" << 'EOF'
# Arcade Bezel Configuration
video_shader = "shaders/shaders_glsl/crt/shaders/crt-geom.glslp"
video_fullscreen_x = 1280
video_fullscreen_y = 720
video_scale_type = 0
video_smooth = false
EOF
    
    echo "Default bezels installed"
    log "Default bezels installed"
}

# ── Apply bezel for system ─────────────────────────────────────────────
apply_bezel() {
    system="$1"
    bezel_file="$BEZELS_DIR/${system}.cfg"
    
    if [ ! -f "$bezel_file" ]; then
        echo "No bezel found for: $system"
        return 1
    fi
    
    # Apply bezel settings to RetroArch
    ra_config="$CONFIG_DIR/retroarch.cfg"
    
    if [ -f "$ra_config" ]; then
        # Read bezel settings
        while IFS='=' read -r key value; do
            case "$key" in
                video_shader|video_fullscreen_x|video_fullscreen_y|video_scale_type|video_smooth)
                    # Update setting
                    sed -i "s|^$key = .*|$key = \"$value\"|" "$ra_config" 2>/dev/null
                    ;;
            esac
        done < "$bezel_file"
        
        log "Applied bezel for: $system"
        echo "Bezel applied for: $system"
        return 0
    else
        echo "RetroArch config not found"
        return 1
    fi
}

# ── Remove bezel ────────────────────────────────────────────────────────
remove_bezel() {
    system="$1"
    ra_config="$CONFIG_DIR/retroarch.cfg"
    
    if [ -f "$ra_config" ]; then
        # Reset to default
        sed -i 's|^video_shader = .*|video_shader = ""|' "$ra_config" 2>/dev/null
        sed -i 's|^video_scale_type = .*|video_scale_type = 0|' "$ra_config" 2>/dev/null
        
        log "Removed bezel for: $system"
        echo "Bezel removed for: $system"
        return 0
    fi
}

# ── Install default backgrounds ────────────────────────────────────────
install_default_backgrounds() {
    echo "Installing default backgrounds..."
    
    # Create default background images (simple colors)
    # These would normally be actual image files
    
    cat > "$BACKGROUNDS_DIR/default.txt" << 'EOF'
# Default Backgrounds
# Place PNG/JPG files in this directory
# Files will be used as menu backgrounds
#
# Supported formats:
# - PNG (recommended)
# - JPG/JPEG
# - BMP
#
# Recommended size: 1280x720
EOF
    
    echo "Default backgrounds installed"
    log "Default backgrounds installed"
}

# ── Apply background ──────────────────────────────────────────────────
apply_background() {
    bg_file="$1"
    
    if [ ! -f "$bg_file" ]; then
        echo "Background not found: $bg_file"
        return 1
    fi
    
    # Copy to system background location
    system_bg="/mnt/SDCARD/System/resources/background.png"
    cp "$bg_file" "$system_bg" 2>/dev/null
    
    if [ -f "$system_bg" ]; then
        log "Applied background: $bg_file"
        echo "Background applied"
        return 0
    else
        echo "Failed to apply background"
        return 1
    fi
}

# ── List bezels ────────────────────────────────────────────────────────
list_bezels() {
    echo "Available Bezels:"
    echo "================="
    echo ""
    
    count=0
    for bezel in "$BEZELS_DIR"/*.cfg; do
        [ -f "$bezel" ] || continue
        
        bezel_name=$(basename "$bezel" .cfg)
        echo "  [$((count + 1))] $bezel_name"
        
        count=$((count + 1))
    done
    
    if [ "$count" -eq 0 ]; then
        echo "  No bezels found"
        echo "  Run: bezel_manager.sh install-defaults"
    else
        echo ""
        echo "Total: $count bezels"
    fi
}

# ── List backgrounds ──────────────────────────────────────────────────
list_backgrounds() {
    echo "Available Backgrounds:"
    echo "======================"
    echo ""
    
    count=0
    find "$BACKGROUNDS_DIR" -type f \( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" -o -name "*.bmp" \) 2>/dev/null | while read -r bg; do
        [ -f "$bg" ] || continue
        
        bg_name=$(basename "$bg")
        bg_size=$(du -h "$bg" | cut -f1)
        
        count=$((count + 1))
        echo "  [$count] $bg_name ($bg_size)"
    done
    
    if [ "$count" -eq 0 ]; then
        echo "  No backgrounds found"
        echo "  Place PNG/JPG files in: $BACKGROUNDS_DIR"
    else
        echo ""
        echo "Total: $count backgrounds"
    fi
}

# ── Create custom bezel ────────────────────────────────────────────────
create_custom_bezel() {
    system="$1"
    
    if [ -z "$system" ]; then
        echo "Usage: bezel_manager.sh create <system>"
        return 1
    fi
    
    bezel_file="$BEZELS_DIR/${system}.cfg"
    
    cat > "$bezel_file" << EOF
# Custom Bezel for $system
# Created: $(date)

video_shader = ""
video_fullscreen_x = 1280
video_fullscreen_y = 720
video_scale_type = 0
video_smooth = false
EOF
    
    log "Created custom bezel: $system"
    echo "Custom bezel created: $system"
    echo "Edit: $bezel_file"
}

# ── Main ───────────────────────────────────────────────────────────────
case "${1:-}" in
    install-defaults)
        install_default_bezels
        install_default_backgrounds
        ;;
    apply)
        apply_bezel "${2:-}"
        ;;
    remove)
        remove_bezel "${2:-}"
        ;;
    apply-bg)
        apply_background "${2:-}"
        ;;
    list)
        list_bezels
        ;;
    list-bg)
        list_backgrounds
        ;;
    create)
        create_custom_bezel "${2:-}"
        ;;
    *)
        echo "Bezel/Background Manager"
        echo "Usage: bezel_manager.sh {install-defaults|apply|remove|apply-bg|list|list-bg|create}"
        echo ""
        echo "Commands:"
        echo "  install-defaults - Install default bezels and backgrounds"
        echo "  apply <system>   - Apply bezel for system"
        echo "  remove <system>  - Remove bezel for system"
        echo "  apply-bg <file>  - Apply background image"
        echo "  list             - List available bezels"
        echo "  list-bg          - List available backgrounds"
        echo "  create <system>  - Create custom bezel"
        ;;
esac
