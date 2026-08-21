#!/bin/sh
# System/usr/trimui/scripts/button_mapper.sh
# Custom Button Mapping - Remap buttons per game or system

MAPPINGS_DIR="/mnt/SDCARD/trimui/button_mappings"
LOG_FILE="/tmp/button_mapper.log"

# Create mappings directory
mkdir -p "$MAPPINGS_DIR"

# Logging
log() {
    echo "$(date '+%H:%M:%S') [mapper] $1" >> "$LOG_FILE"
}

# ── Button names ───────────────────────────────────────────────────────
# TrimUI button codes (from inputd)
BTN_A="54"
BTN_B="52"
BTN_X="47"
BTN_Y="29"
BTN_L="10-193"
BTN_R="10-192"
BTN_START="62"
BTN_SELECT="66"
BTN_UP="19"
BTN_DOWN="20"
BTN_LEFT="21"
BTN_RIGHT="22"
BTN_L2="10-193"
BTN_R2="10-192"

# ── Create default mapping ─────────────────────────────────────────────
create_default() {
    cat > "$MAPPINGS_DIR/default.map" << 'EOF'
# Default Button Mapping
# Format: original=remap

# Face buttons
A=A
B=B
X=X
Y=Y

# Shoulder buttons
L=L
R=R
L2=L2
R2=R2

# D-pad
Up=Up
Down=Down
Left=Left
Right=Right

# System
Start=Start
Select=Select
EOF
    echo "Default mapping created"
}

# ── Create game-specific mapping ───────────────────────────────────────
create_game_mapping() {
    local game_path="$1"
    local game_name=$(basename "$game_path")
    local game_id=$(echo "$game_name" | md5sum 2>/dev/null | cut -d' ' -f1)
    
    if [ -z "$game_id" ]; then
        game_id=$(echo "$game_name" | wc -c)
    fi
    
    local mapping_file="$MAPPINGS_DIR/${game_id}.map"
    
    if [ -f "$mapping_file" ]; then
        echo "Mapping already exists for: $game_name"
        return
    fi
    
    # Copy default mapping
    cp "$MAPPINGS_DIR/default.map" "$mapping_file"
    
    log "Created mapping for: $game_name"
    echo "Created mapping for: $game_name"
}

# ── Create system-specific mapping ─────────────────────────────────────
create_system_mapping() {
    local system="$1"
    local mapping_file="$MAPPINGS_DIR/system_${system}.map"
    
    if [ -f "$mapping_file" ]; then
        echo "System mapping already exists for: $system"
        return
    fi
    
    # Create optimized mapping for system
    cat > "$mapping_file" << EOF
# System Mapping: $system
# Format: original=remap

# Face buttons (standard)
A=A
B=B
X=X
Y=Y

# Shoulder buttons
L=L
R=R
L2=L2
R2=R2

# D-pad
Up=Up
Down=Down
Left=Left
Right=Right

# System
Start=Start
Select=Select

# System-specific optimizations
# $system
EOF
    
    log "Created system mapping for: $system"
    echo "Created system mapping for: $system"
}

# ── Set button mapping ─────────────────────────────────────────────────
set_mapping() {
    local mapping_file="$1"
    local original="$2"
    local remap="$3"
    
    if [ ! -f "$mapping_file" ]; then
        echo "Mapping file not found"
        return 1
    fi
    
    # Update or add mapping
    if grep -q "^${original}=" "$mapping_file"; then
        sed -i "s/^${original}=.*/${original}=${remap}/" "$mapping_file"
    else
        echo "${original}=${remap}" >> "$mapping_file"
    fi
    
    log "Set mapping: $original -> $remap"
    echo "Mapped: $original -> $remap"
}

# ── View mapping ───────────────────────────────────────────────────────
view_mapping() {
    local mapping_file="$1"
    
    if [ ! -f "$mapping_file" ]; then
        echo "Mapping file not found"
        return 1
    fi
    
    echo "Button Mapping:"
    echo "==============="
    echo ""
    
    grep -v "^#" "$mapping_file" | grep -v "^$" | while IFS='=' read -r original remap; do
        if [ "$original" != "$remap" ]; then
            printf "  %-10s -> %s\n" "$original" "$remap"
        fi
    done
}

# ── Reset mapping ──────────────────────────────────────────────────────
reset_mapping() {
    local mapping_file="$1"
    
    if [ ! -f "$mapping_file" ]; then
        echo "Mapping file not found"
        return 1
    fi
    
    cp "$MAPPINGS_DIR/default.map" "$mapping_file"
    
    log "Reset mapping: $mapping_file"
    echo "Mapping reset to default"
}

# ── Export mapping ──────────────────────────────────────────────────────
export_mapping() {
    local mapping_file="$1"
    local export_file="${2:-mapping_export.map}"
    
    if [ ! -f "$mapping_file" ]; then
        echo "Mapping file not found"
        return 1
    fi
    
    cp "$mapping_file" "$export_file"
    echo "Mapping exported to: $export_file"
}

# ── Import mapping ──────────────────────────────────────────────────────
import_mapping() {
    local import_file="$1"
    local mapping_file="${2:-$MAPPINGS_DIR/default.map}"
    
    if [ ! -f "$import_file" ]; then
        echo "File not found: $import_file"
        return 1
    fi
    
    cp "$import_file" "$mapping_file"
    echo "Mapping imported from: $import_file"
}

# ── List mappings ───────────────────────────────────────────────────────
list_mappings() {
    echo "Available mappings:"
    echo ""
    
    echo "Default:"
    if [ -f "$MAPPINGS_DIR/default.map" ]; then
        echo "  ✓ Present"
    else
        echo "  ✗ Missing"
    fi
    
    echo ""
    echo "System mappings:"
    for mapping in "$MAPPINGS_DIR"/system_*.map; do
        [ -f "$mapping" ] || continue
        local system=$(basename "$mapping" | sed 's/system_//;s/\.map//')
        echo "  $system"
    done
    
    echo ""
    echo "Game mappings:"
    local count=0
    for mapping in "$MAPPINGS_DIR"/*.map; do
        [ -f "$mapping" ] || continue
        local name=$(basename "$mapping")
        case "$name" in
            default|system_*) continue ;;
        esac
        count=$((count + 1))
    done
    echo "  $count game-specific mappings"
}

# ── Apply mapping to RetroArch ─────────────────────────────────────────
apply_to_retroarch() {
    local mapping_file="$1"
    local retroarch_config="/mnt/SDCARD/RetroArch/.retroarch/retroarch.cfg"
    
    if [ ! -f "$mapping_file" ] || [ ! -f "$retroarch_config" ]; then
        echo "Files not found"
        return 1
    fi
    
    # Parse mapping and apply to RetroArch
    grep -v "^#" "$mapping_file" | grep -v "^$" | while IFS='=' read -r original remap; do
        case "$original" in
            A)
                sed -i "s/input_player1_a = \".*\"/input_player1_a = \"$remap\"/" "$retroarch_config"
                ;;
            B)
                sed -i "s/input_player1_b = \".*\"/input_player1_b = \"$remap\"/" "$retroarch_config"
                ;;
            X)
                sed -i "s/input_player1_x = \".*\"/input_player1_x = \"$remap\"/" "$retroarch_config"
                ;;
            Y)
                sed -i "s/input_player1_y = \".*\"/input_player1_y = \"$remap\"/" "$retroarch_config"
                ;;
            L)
                sed -i "s/input_player1_l = \".*\"/input_player1_l = \"$remap\"/" "$retroarch_config"
                ;;
            R)
                sed -i "s/input_player1_r = \".*\"/input_player1_r = \"$remap\"/" "$retroarch_config"
                ;;
            Start)
                sed -i "s/input_player1_start = \".*\"/input_player1_start = \"$remap\"/" "$retroarch_config"
                ;;
            Select)
                sed -i "s/input_player1_select = \".*\"/input_player1_select = \"$remap\"/" "$retroarch_config"
                ;;
            Up)
                sed -i "s/input_player1_up = \".*\"/input_player1_up = \"$remap\"/" "$retroarch_config"
                ;;
            Down)
                sed -i "s/input_player1_down = \".*\"/input_player1_down = \"$remap\"/" "$retroarch_config"
                ;;
            Left)
                sed -i "s/input_player1_left = \".*\"/input_player1_left = \"$remap\"/" "$retroarch_config"
                ;;
            Right)
                sed -i "s/input_player1_right = \".*\"/input_player1_right = \"$remap\"/" "$retroarch_config"
                ;;
        esac
    done
    
    log "Applied mapping to RetroArch"
    echo "Mapping applied to RetroArch"
}

# ── Main ──────────────────────────────────────────────────────────────
case "${1:-}" in
    create)
        if [ -n "$2" ]; then
            create_game_mapping "$2"
        else
            create_default
        fi
        ;;
    system)
        create_system_mapping "$2"
        ;;
    set)
        set_mapping "$2" "$3" "$4"
        ;;
    view)
        view_mapping "$2"
        ;;
    reset)
        reset_mapping "$2"
        ;;
    export)
        export_mapping "$2" "$3"
        ;;
    import)
        import_mapping "$2" "$3"
        ;;
    list)
        list_mappings
        ;;
    apply)
        apply_to_retroarch "$2"
        ;;
    *)
        echo "Button Mapper"
        echo "============="
        echo ""
        echo "Usage: button_mapper.sh {command} [args]" >&2
        echo "" >&2
        echo "Commands:" >&2
        echo "  create [game]       - Create default or game mapping" >&2
        echo "  system <system>     - Create system mapping" >&2
        echo "  set <file> <btn> <remap> - Set button mapping" >&2
        echo "  view <file>         - View mapping" >&2
        echo "  reset <file>        - Reset to default" >&2
        echo "  export <file> [out] - Export mapping" >&2
        echo "  import <file> [in]  - Import mapping" >&2
        echo "  list                - List all mappings" >&2
        echo "  apply <file>        - Apply to RetroArch" >&2
        exit 1
        ;;
esac
