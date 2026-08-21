#!/bin/sh
. /mnt/SDCARD/System/usr/trimui/scripts/common_launcher.sh

KEYMAP_DIR="/mnt/SDCARD/System/usr/trimui/keymaps"
REMAP_CONFIG="/mnt/SDCARD/System/usr/trimui/keyremap.conf"

# Ensure keymap directory exists
mkdir -p "$KEYMAP_DIR"

# Create default profile if missing
if [ ! -f "$KEYMAP_DIR/default.ini" ]; then
    cat > "$KEYMAP_DIR/default.ini" << 'DEFAULTEOF'
#desc=Default mapping (no changes)
A=A
B=B
X=X
Y=Y
L1=L1
R1=R1
L2=L2
R2=R2
START=START
SELECT=SELECT
UP=UP
DOWN=DOWN
LEFT=LEFT
RIGHT=RIGHT
DEFAULTEOF
fi

# Create nintendo profile if missing
if [ ! -f "$KEYMAP_DIR/nintendo.ini" ]; then
    cat > "$KEYMAP_DIR/nintendo.ini" << 'NINTENDOEOF'
#desc=Nintendo layout (A/B and X/Y swapped)
A=B
B=A
X=Y
Y=X
L1=L1
R1=R1
L2=L2
R2=R2
START=START
SELECT=SELECT
UP=UP
DOWN=DOWN
LEFT=LEFT
RIGHT=RIGHT
NINTENDOEOF
fi

# Create arcade profile if missing
if [ ! -f "$KEYMAP_DIR/arcade.ini" ]; then
    cat > "$KEYMAP_DIR/arcade.ini" << 'ARCADEEOF'
#desc=Arcade layout (punch/kick style)
A=A
B=B
X=X
Y=Y
L1=L1
R1=R1
L2=R2
R2=L2
START=START
SELECT=SELECT
UP=UP
DOWN=DOWN
LEFT=LEFT
RIGHT=RIGHT
ARCADEEOF
fi

# Create comfort profile if missing
if [ ! -f "$KEYMAP_DIR/comfort.ini" ]; then
    cat > "$KEYMAP_DIR/comfort.ini" << 'COMFORTEOF'
#desc=Comfort layout (ergonomic for long sessions)
A=A
B=B
X=L1
Y=R1
L1=X
R1=Y
L2=L2
R2=R2
START=START
SELECT=SELECT
UP=UP
DOWN=DOWN
LEFT=LEFT
RIGHT=RIGHT
COMFORTEOF
fi

# Read current profile
CURRENT_PROFILE="none"
if [ -f "$REMAP_CONFIG" ]; then
    CURRENT_PROFILE=$(cat "$REMAP_CONFIG")
fi

echo "========================================="
echo "     JukaMix Key Remapper"
echo "========================================="
echo ""
echo "Current profile: $CURRENT_PROFILE"
echo ""
echo "Available profiles:"
echo "  1. none        - Default mapping"
echo "  2. default     - Default mapping (explicit)"
echo "  3. nintendo    - A/B and X/Y swapped"
echo "  4. arcade      - Fighting game layout"
echo "  5. comfort     - Ergonomic layout"
echo ""
echo "Select profile (1-5): "

# Read input
read choice

case "$choice" in
    1|"none")
        echo "none" > "$REMAP_CONFIG"
        echo "Profile set to: none (default mapping)"
        ;;
    2|"default")
        echo "default" > "$REMAP_CONFIG"
        echo "Profile set to: default"
        ;;
    3|"nintendo")
        echo "nintendo" > "$REMAP_CONFIG"
        echo "Profile set to: nintendo (A/B swapped)"
        ;;
    4|"arcade")
        echo "arcade" > "$REMAP_CONFIG"
        echo "Profile set to: arcade (fighting layout)"
        ;;
    5|"comfort")
        echo "comfort" > "$REMAP_CONFIG"
        echo "Profile set to: comfort (ergonomic)"
        ;;
    *)
        echo "Invalid choice. No changes made."
        ;;
esac

echo ""
echo "Press any key to continue..."
read -n 1 -s
