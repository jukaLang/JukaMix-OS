#!/bin/sh
# theme_manager.sh - Theme Manager for JukaMix
# Manages themes, icons, and visual customization

THEMES_DIR="/mnt/SDCARD/System/themes"
ICONS_DIR="/mnt/SDCARD/System/icons"
BACKGROUNDS_DIR="/mnt/SDCARD/System/backgrounds"
CONFIG_FILE="/mnt/SDCARD/System/etc/jukamix.json"
LOG_FILE="/tmp/theme_manager.log"

# Create directories
mkdir -p "$THEMES_DIR" "$ICONS_DIR" "$BACKGROUNDS_DIR" 2>/dev/null

# ── Logging ────────────────────────────────────────────────────────────
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [theme] $1" >> "$LOG_FILE" 2>/dev/null
}

# ── Install default theme ──────────────────────────────────────────────
install_default_theme() {
    echo "Installing default theme..."
    
    # Create default theme structure
    theme_dir="$THEMES_DIR/default"
    mkdir -p "$theme_dir"/{icons,backgrounds,fonts} 2>/dev/null
    
    # Create theme configuration
    cat > "$theme_dir/theme.json" << 'EOF'
{
    "name": "Default",
    "author": "JukaMix",
    "version": "1.0",
    "colors": {
        "background": "#1a1a2e",
        "text": "#ffffff",
        "accent": "#00d4ff",
        "success": "#2ecc71",
        "warning": "#f39c12",
        "error": "#e74c3c"
    },
    "fonts": {
        "primary": "Roboto",
        "secondary": "Roboto Condensed"
    },
    "layout": {
        "menu_style": "grid",
        "icon_size": 64,
        "show_previews": true
    }
}
EOF
    
    # Copy default icons
    if [ -d /mnt/SDCARD/System/resources ]; then
        cp /mnt/SDCARD/System/resources/*.png "$theme_dir/icons/" 2>/dev/null
    fi
    
    echo "Default theme installed"
    log "Default theme installed"
}

# ── Apply theme ────────────────────────────────────────────────────────
apply_theme() {
    theme_name="$1"
    theme_dir="$THEMES_DIR/$theme_name"
    
    if [ ! -d "$theme_dir" ]; then
        echo "Theme not found: $theme_name"
        return 1
    fi
    
    # Backup current theme
    if [ -f "$CONFIG_FILE" ] && command -v jq >/dev/null 2>&1; then
        current=$(jq -r '.["CURRENT_THEME"] // "default"' "$CONFIG_FILE" 2>/dev/null)
        echo "$current" > "$THEMES_DIR/.previous_theme" 2>/dev/null
    fi
    
    # Apply theme
    if [ -f "$CONFIG_FILE" ] && command -v jq >/dev/null 2>&1; then
        jq --arg theme "$theme_name" '. += {"CURRENT_THEME": $theme}' "$CONFIG_FILE" > /tmp/jukamix_tmp.json 2>/dev/null && \
        mv /tmp/jukamix_tmp.json "$CONFIG_FILE" 2>/dev/null
    fi
    
    # Apply icons if present
    if [ -d "$theme_dir/icons" ]; then
        cp -r "$theme_dir/icons/"* /mnt/SDCARD/System/resources/ 2>/dev/null
    fi
    
    # Apply backgrounds if present
    if [ -d "$theme_dir/backgrounds" ]; then
        cp -r "$theme_dir/backgrounds/"* "$BACKGROUNDS_DIR/" 2>/dev/null
    fi
    
    log "Applied theme: $theme_name"
    echo "Theme applied: $theme_name"
    return 0
}

# ── Remove theme ────────────────────────────────────────────────────────
remove_theme() {
    theme_name="$1"
    theme_dir="$THEMES_DIR/$theme_name"
    
    if [ "$theme_name" = "default" ]; then
        echo "Cannot remove default theme"
        return 1
    fi
    
    if [ ! -d "$theme_dir" ]; then
        echo "Theme not found: $theme_name"
        return 1
    fi
    
    rm -rf "$theme_dir" 2>/dev/null
    
    log "Removed theme: $theme_name"
    echo "Theme removed: $theme_name"
    return 0
}

# ── List themes ────────────────────────────────────────────────────────
list_themes() {
    echo "Available Themes:"
    echo "================="
    echo ""
    
    # Get current theme
    current="default"
    if [ -f "$CONFIG_FILE" ] && command -v jq >/dev/null 2>&1; then
        current=$(jq -r '.["CURRENT_THEME"] // "default"' "$CONFIG_FILE" 2>/dev/null)
    fi
    
    count=0
    for theme_dir in "$THEMES_DIR"/*/; do
        [ -d "$theme_dir" ] || continue
        
        theme_name=$(basename "$theme_dir")
        
        # Read theme info
        if [ -f "$theme_dir/theme.json" ] && command -v jq >/dev/null 2>&1; then
            author=$(jq -r '.author // "Unknown"' "$theme_dir/theme.json" 2>/dev/null)
            version=$(jq -r '.version // "1.0"' "$theme_dir/theme.json" 2>/dev/null)
        else
            author="Unknown"
            version="1.0"
        fi
        
        # Mark current theme
        marker=""
        if [ "$theme_name" = "$current" ]; then
            marker=" (current)"
        fi
        
        echo "  [$((count + 1))] $theme_name$marker"
        echo "      Author: $author"
        echo "      Version: $version"
        echo ""
        
        count=$((count + 1))
    done
    
    if [ "$count" -eq 0 ]; then
        echo "  No themes found"
        echo "  Run: theme_manager.sh install-default"
    else
        echo "Total: $count themes"
        echo "Current: $current"
    fi
}

# ── Create custom theme ────────────────────────────────────────────────
create_theme() {
    theme_name="$1"
    
    if [ -z "$theme_name" ]; then
        echo "Usage: theme_manager.sh create <name>"
        return 1
    fi
    
    theme_dir="$THEMES_DIR/$theme_name"
    
    if [ -d "$theme_dir" ]; then
        echo "Theme already exists: $theme_name"
        return 1
    fi
    
    mkdir -p "$theme_dir"/{icons,backgrounds,fonts} 2>/dev/null
    
    # Create theme configuration
    cat > "$theme_dir/theme.json" << EOF
{
    "name": "$theme_name",
    "author": "Custom",
    "version": "1.0",
    "colors": {
        "background": "#1a1a2e",
        "text": "#ffffff",
        "accent": "#00d4ff",
        "success": "#2ecc71",
        "warning": "#f39c12",
        "error": "#e74c3c"
    },
    "fonts": {
        "primary": "Roboto",
        "secondary": "Roboto Condensed"
    },
    "layout": {
        "menu_style": "grid",
        "icon_size": 64,
        "show_previews": true
    }
}
EOF
    
    log "Created theme: $theme_name"
    echo "Theme created: $theme_name"
    echo "Location: $theme_dir"
    echo ""
    echo "To customize:"
    echo "1. Edit $theme_dir/theme.json"
    echo "2. Add icons to $theme_dir/icons/"
    echo "3. Add backgrounds to $theme_dir/backgrounds/"
    echo "4. Run: theme_manager.sh apply $theme_name"
}

# ── Export theme ────────────────────────────────────────────────────────
export_theme() {
    theme_name="$1"
    export_file="${2:-$theme_name.tar.gz}"
    
    theme_dir="$THEMES_DIR/$theme_name"
    
    if [ ! -d "$theme_dir" ]; then
        echo "Theme not found: $theme_name"
        return 1
    fi
    
    tar -czf "$export_file" -C "$THEMES_DIR" "$theme_name" 2>/dev/null
    
    if [ -f "$export_file" ]; then
        log "Exported theme: $theme_name"
        echo "Theme exported: $export_file"
        return 0
    else
        echo "Export failed"
        return 1
    fi
}

# ── Import theme ────────────────────────────────────────────────────────
import_theme() {
    import_file="$1"
    
    if [ ! -f "$import_file" ]; then
        echo "Import file not found: $import_file"
        return 1
    fi
    
    tar -xzf "$import_file" -C "$THEMES_DIR" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        theme_name=$(tar -tzf "$import_file" 2>/dev/null | head -1 | cut -d'/' -f1)
        log "Imported theme: $theme_name"
        echo "Theme imported: $theme_name"
        return 0
    else
        echo "Import failed"
        return 1
    fi
}

# ── List icons ──────────────────────────────────────────────────────────
list_icons() {
    echo "Available Icons:"
    echo "================"
    echo ""
    
    count=0
    find "$ICONS_DIR" -name "*.png" -type f 2>/dev/null | while read -r icon; do
        [ -f "$icon" ] || continue
        
        icon_name=$(basename "$icon")
        icon_size=$(du -h "$icon" | cut -f1)
        
        count=$((count + 1))
        echo "  [$count] $icon_name ($icon_size)"
    done
    
    if [ "$count" -eq 0 ]; then
        echo "  No icons found"
    else
        echo ""
        echo "Total: $count icons"
    fi
}

# ── Main ───────────────────────────────────────────────────────────────
case "${1:-}" in
    install-default)
        install_default_theme
        ;;
    apply)
        apply_theme "${2:-}"
        ;;
    remove)
        remove_theme "${2:-}"
        ;;
    list)
        list_themes
        ;;
    create)
        create_theme "${2:-}"
        ;;
    export)
        export_theme "${2:-}" "${3:-}"
        ;;
    import)
        import_theme "${2:-}"
        ;;
    icons)
        list_icons
        ;;
    *)
        echo "Theme Manager"
        echo "Usage: theme_manager.sh {install-default|apply|remove|list|create|export|import|icons}"
        echo ""
        echo "Commands:"
        echo "  install-default  - Install default theme"
        echo "  apply <name>     - Apply theme"
        echo "  remove <name>    - Remove theme"
        echo "  list             - List available themes"
        echo "  create <name>    - Create custom theme"
        echo "  export <name> [file] - Export theme"
        echo "  import <file>    - Import theme"
        echo "  icons            - List available icons"
        ;;
esac
