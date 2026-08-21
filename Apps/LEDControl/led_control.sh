#!/bin/sh
# Apps/LEDControl/led_control.sh
# LED Control - Change LED colors and effects

LED_DIR="/sys/class/led_anim"
CONFIG_FILE="/mnt/SDCARD/trimui/led_config.json"
LOG_FILE="/tmp/led_control.log"

# Logging
log() {
    echo "$(date '+%H:%M:%S') [led] $1" >> "$LOG_FILE"
}

# ── Check if LED control is available ──────────────────────────────────
check_led() {
    if [ -d "$LED_DIR" ]; then
        return 0
    fi
    return 1
}

# ── Get available LED effects ──────────────────────────────────────────
get_effects() {
    if [ -f "$LED_DIR/effect_list" ]; then
        cat "$LED_DIR/effect_list"
    else
        echo "none"
    fi
}

# ── Set LED effect ─────────────────────────────────────────────────────
set_effect() {
    local effect="$1"
    
    if ! check_led; then
        echo "LED control not available"
        return 1
    fi
    
    # Enable LED animation
    echo 1 > "$LED_DIR/effect_enable" 2>/dev/null
    
    # Set effect
    echo "$effect" > "$LED_DIR/effect" 2>/dev/null
    
    log "Set effect: $effect"
    echo "Effect set: $effect"
}

# ── Set LED color ──────────────────────────────────────────────────────
set_color() {
    local r="$1"
    local g="$2"
    local b="$3"
    
    if ! check_led; then
        echo "LED control not available"
        return 1
    fi
    
    # Set RGB values
    echo "$r" > "$LED_DIR/red" 2>/dev/null
    echo "$g" > "$LED_DIR/green" 2>/dev/null
    echo "$b" > "$LED_DIR/blue" 2>/dev/null
    
    # Enable static effect
    echo "static" > "$LED_DIR/effect" 2>/dev/null
    echo 1 > "$LED_DIR/effect_enable" 2>/dev/null
    
    log "Set color: RGB($r, $g, $b)"
    echo "Color set: RGB($r, $g, $b)"
}

# ── Set LED brightness ─────────────────────────────────────────────────
set_brightness() {
    local brightness="$1"
    
    if ! check_led; then
        echo "LED control not available"
        return 1
    fi
    
    echo "$brightness" > "$LED_DIR/brightness" 2>/dev/null
    
    log "Set brightness: $brightness"
    echo "Brightness set: $brightness"
}

# ── Turn LED on/off ────────────────────────────────────────────────────
led_on() {
    if ! check_led; then
        return 1
    fi
    
    echo 1 > "$LED_DIR/effect_enable" 2>/dev/null
    echo "LED ON"
}

led_off() {
    if ! check_led; then
        return 1
    fi
    
    echo 0 > "$LED_DIR/effect_enable" 2>/dev/null
    echo "LED OFF"
}

# ── Preset colors ──────────────────────────────────────────────────────
preset_red() { set_color 255 0 0; }
preset_green() { set_color 0 255 0; }
preset_blue() { set_color 0 0 255; }
preset_yellow() { set_color 255 255 0; }
preset_cyan() { set_color 0 255 255; }
preset_magenta() { set_color 255 0 255; }
preset_white() { set_color 255 255 255; }
preset_orange() { set_color 255 165 0; }
preset_purple() { set_color 128 0 128; }

# ── Save preset ────────────────────────────────────────────────────────
save_preset() {
    local name="$1"
    local effect="$2"
    local r="${3:-255}"
    local g="${4:-255}"
    local b="${5:-255}"
    local brightness="${6:-128}"
    
    mkdir -p "$(dirname "$CONFIG_FILE")"
    
    # Simple config file
    cat > "$CONFIG_FILE" << EOF
name=$name
effect=$effect
red=$r
green=$g
blue=$b
brightness=$brightness
EOF
    
    log "Saved preset: $name"
    echo "Preset saved: $name"
}

# ── Load preset ────────────────────────────────────────────────────────
load_preset() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "No preset saved"
        return 1
    fi
    
    . "$CONFIG_FILE"
    
    set_brightness "$brightness"
    set_color "$red" "$green" "$blue"
    
    log "Loaded preset: $name"
    echo "Loaded: $name"
}

# ── Main ──────────────────────────────────────────────────────────────
case "${1:-}" in
    effect)
        set_effect "$2"
        ;;
    color)
        set_color "$2" "$3" "$4"
        ;;
    brightness)
        set_brightness "$2"
        ;;
    on)
        led_on
        ;;
    off)
        led_off
        ;;
    red)
        preset_red
        ;;
    green)
        preset_green
        ;;
    blue)
        preset_blue
        ;;
    yellow)
        preset_yellow
        ;;
    cyan)
        preset_cyan
        ;;
    magenta)
        preset_magenta
        ;;
    white)
        preset_white
        ;;
    orange)
        preset_orange
        ;;
    purple)
        preset_purple
        ;;
    save)
        save_preset "$2" "${3:-static}" "$4" "$5" "$6" "$7"
        ;;
    load)
        load_preset
        ;;
    effects)
        get_effects
        ;;
    *)
        echo "LED Control"
        echo "==========="
        echo ""
        if check_led; then
            echo "Status: Available"
        else
            echo "Status: Not available"
        fi
        echo ""
        echo "Usage: led_control.sh {command} [args]" >&2
        echo "" >&2
        echo "Commands:" >&2
        echo "  effect <name>           - Set LED effect" >&2
        echo "  color <r> <g> <b>       - Set LED color (0-255)" >&2
        echo "  brightness <0-255>      - Set brightness" >&2
        echo "  on                      - Turn LED on" >&2
        echo "  off                     - Turn LED off" >&2
        echo "  red/green/blue/...      - Set preset color" >&2
        echo "  save <name>             - Save current as preset" >&2
        echo "  load                    - Load saved preset" >&2
        echo "  effects                 - List available effects" >&2
        exit 1
        ;;
esac
