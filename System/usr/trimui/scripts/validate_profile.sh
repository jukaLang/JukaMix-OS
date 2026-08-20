#!/bin/sh
# JukaMix OS - Profile Validator
# Validates game profile syntax and settings

set -u

PROFILE_FILE=""
VERBOSE=0

usage() {
    cat <<EOF
Usage: $0 <profile.cfg> [--verbose]

Validates a game profile for syntax errors and invalid settings.

Options:
  --verbose   Show detailed validation output
  -h, --help  Show this help

Exit codes:
  0 = Valid profile
  1 = Validation failed
  2 = Usage error
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help) usage; exit 0 ;;
        --verbose) VERBOSE=1; shift ;;
        *) 
            if [ -z "$PROFILE_FILE" ]; then
                PROFILE_FILE="$1"
            else
                echo "Unknown option: $1"
                usage
                exit 2
            fi
            shift
            ;;
    esac
done

if [ -z "$PROFILE_FILE" ]; then
    echo "Error: No profile file specified"
    usage
    exit 2
fi

if [ ! -f "$PROFILE_FILE" ]; then
    echo "Error: File not found: $PROFILE_FILE"
    exit 1
fi

echo "=== Validating Profile: $(basename "$PROFILE_FILE") ==="
echo ""

ERRORS=0
WARNINGS=0

# Check required sections
check_section() {
    _section="$1"
    if grep -q "^\[$_section\]" "$PROFILE_FILE"; then
        [ "$VERBOSE" = "1" ] && echo "  ✅ Section [$_section] present"
    else
        echo "  ❌ Missing required section [$_section]"
        ERRORS=$((ERRORS + 1))
    fi
}

echo "Checking required sections..."
check_section "performance"
check_section "gpu"
echo ""

# Check required fields in [performance]
echo "Checking [performance] section..."
PERF_FIELDS="cpu_governor cpu_min_freq cpu_max_freq active_cores"
for field in $PERF_FIELDS; do
    if grep -q "^$field[[:space:]]*=" "$PROFILE_FILE"; then
        _value=$(grep "^$field[[:space:]]*=" "$PROFILE_FILE" | head -n 1 | cut -d'=' -f2 | tr -d '[:space:]')
        [ "$VERBOSE" = "1" ] && echo "  ✅ $field = $_value"
        
        # Validate specific fields
        case "$field" in
            cpu_governor)
                case "$_value" in
                    performance|ondemand|conservative|powersave) ;;
                    *) echo "  ⚠️  Invalid governor: $_value"; WARNINGS=$((WARNINGS + 1)) ;;
                esac
                ;;
            cpu_min_freq|cpu_max_freq)
                if ! echo "$_value" | grep -qE '^[0-9]+$'; then
                    echo "  ❌ $field must be numeric: $_value"
                    ERRORS=$((ERRORS + 1))
                elif [ "$_value" -lt 408000 ] || [ "$_value" -gt 2400000 ]; then
                    echo "  ⚠️  $field outside typical range (408000-2400000): $_value"
                    WARNINGS=$((WARNINGS + 1))
                fi
                ;;
            active_cores)
                if ! echo "$_value" | grep -qE '^[1-4]$'; then
                    echo "  ❌ active_cores must be 1-4: $_value"
                    ERRORS=$((ERRORS + 1))
                fi
                ;;
        esac
    else
        echo "  ❌ Missing required field: $field"
        ERRORS=$((ERRORS + 1))
    fi
done
echo ""

# Check [gpu] section
echo "Checking [gpu] section..."
GPU_FIELDS="internal_resolution texture_upscaling anisotropic_filtering threaded_rendering"
for field in $GPU_FIELDS; do
    if grep -q "^$field[[:space:]]*=" "$PROFILE_FILE"; then
        _value=$(grep "^$field[[:space:]]*=" "$PROFILE_FILE" | head -n 1 | cut -d'=' -f2 | tr -d '[:space:]')
        [ "$VERBOSE" = "1" ] && echo "  ✅ $field = $_value"
        
        case "$field" in
            internal_resolution)
                case "$_value" in
                    1x|2x|3x|4x) ;;
                    *) echo "  ⚠️  Unusual resolution: $_value (expected 1x-4x)"; WARNINGS=$((WARNINGS + 1)) ;;
                esac
                ;;
            texture_upscaling|threaded_rendering)
                case "$_value" in
                    enabled|disabled|true|false) ;;
                    *) echo "  ❌ $field must be enabled/disabled or true/false: $_value"; ERRORS=$((ERRORS + 1)) ;;
                esac
                ;;
            anisotropic_filtering)
                if ! echo "$_value" | grep -qE '^(0|2|4|8|16)$'; then
                    echo "  ⚠️  Unusual AF value: $_value (expected 0, 2, 4, 8, or 16)"
                    WARNINGS=$((WARNINGS + 1))
                fi
                ;;
        esac
    else
        [ "$VERBOSE" = "1" ] && echo "  ℹ️  Optional field missing: $field"
    fi
done
echo ""

# Check header comments
echo "Checking profile header..."
HEADER_OK=1
for header in "Game:" "System:" "Device:" "Contributor:" "Date:"; do
    if grep -q "^#[[:space:]]*$header" "$PROFILE_FILE"; then
        [ "$VERBOSE" = "1" ] && echo "  ✅ Header has $header"
    else
        echo "  ⚠️  Missing header: $header"
        WARNINGS=$((WARNINGS + 1))
        HEADER_OK=0
    fi
done
echo ""

# Check file naming convention
echo "Checking file naming..."
_FILENAME=$(basename "$PROFILE_FILE")
_SYSTEM_DIR=$(basename "$(dirname "$PROFILE_FILE")")

if [ "$_SYSTEM_DIR" != "DEVICE-OVERRIDES" ]; then
    # Game profile - should match system directory
    _game_from_name=$(echo "$_FILENAME" | sed 's/\.cfg$//')
    [ "$VERBOSE" = "1" ] && echo "  ✅ Profile name: $_game_from_name"
    [ "$VERBOSE" = "1" ] && echo "  ✅ System directory: $_SYSTEM_DIR"
else
    # Base profile - should end with _base.cfg
    if echo "$_FILENAME" | grep -qE '^[a-z0-9]+_base\.cfg$'; then
        [ "$VERBOSE" = "1" ] && echo "  ✅ Base profile naming correct"
    else
        echo "  ⚠️  Base profile should be named <device>_base.cfg"
        WARNINGS=$((WARNINGS + 1))
    fi
fi
echo ""

# Summary
echo "=== Validation Summary ==="
echo "Errors: $ERRORS"
echo "Warnings: $WARNINGS"
echo ""

if [ "$ERRORS" -eq 0 ]; then
    echo "✅ Profile is valid!"
    if [ "$WARNINGS" -gt 0 ]; then
        echo "⚠️  Address warnings for best compatibility."
    fi
    exit 0
else
    echo "❌ Profile has errors and cannot be used."
    exit 1
fi
