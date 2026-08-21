#!/bin/sh

if [ -f "/tmp/infoscreen_disabled" ]; then
    exit 0
fi

# /tmp/boot_in_progress is set by System/starts/°customization.sh and
# °post_starts.sh around their own inputd_switcher.sh call. It's meant to
# stop a status toast from appearing/racing during that reinit, but until
# now only inputd_switcher.sh itself checked it before calling in -- the
# other ~170+ call sites across the repo did not, so the flag protected one
# call path and not the rest. Checking it here instead covers all of them
# from a single place.
if [ -f "/tmp/boot_in_progress" ]; then
    exit 0
fi

# Function to display usage
usage() {
    echo "Usage: [options]"
    echo "Options:"
    echo "  -i <image>      Image file to display (can be full path or just file name)"
    echo "  -k <keys>       Wait for key input (valid keys: A B Y X L R SELECT START MENU FN UP DOWN LEFT RIGHT FN_RIGHT FN_LEFT)"
    echo "  -t <timer>      Timer duration in seconds"
    echo "  -m <message>    Message to display"
    echo "  -ff <font_file> Font file to use"
    echo "  -fs <font_size> Font size"
    echo "  -c <color>      Color (name or RGB format, e.g., red or 255,0,0)"
    echo "  -h              Display this help message"
    exit 1
}

# Function to convert color names to RGB values
color_to_rgb() {
    case "$1" in
    red) echo "255,0,0" ;;
    green) echo "0,255,0" ;;
    blue) echo "0,0,255" ;;
    white) echo "255,255,255" ;;
    black) echo "0,0,0" ;;
    yellow) echo "255,255,0" ;;
    cyan) echo "0,255,255" ;;
    magenta) echo "255,0,255" ;;
    gray | grey) echo "128,128,128" ;;
    lightgray | lightgrey) echo "192,192,192" ;;
    darkgray | darkgrey) echo "64,64,64" ;;
    brown) echo "165,42,42" ;;
    orange) echo "255,165,0" ;;
    purple) echo "128,0,128" ;;
    pink) echo "255,119,170" ;;
    *) echo "$1" ;; # If it's not a named color, assume it's already in RGB format
    esac
}

# Function to check if a value is a number (integer or floating-point)
is_number() {
    case "$1" in
    '' | *[!0-9.]* | *.*.*) return 1 ;; # Not a number
    *) return 0 ;;                      # Is a number
    esac
}

# Function to validate keys
validate_keys() {
    valid_keys="A B Y X L R SELECT START MENU FN UP DOWN LEFT RIGHT FN_RIGHT FN_LEFT"
    for key in $1; do
        if ! echo "$valid_keys" | grep -qw "$key"; then
            echo "Invalid key: $key. Using default."
            return 1
        fi
    done
    return 0
}

# Initialize variables with default values
image="bg-info.png"
wait_keys=""
timer=""
message=" "
font_file="/mnt/SDCARD/System/resources/DejaVuSans.ttf"
font_size=35
color="220,220,220"

Current_Theme=$(basename "$(/usr/trimui/bin/systemval theme)")
if [ "$Current_Theme" = "res" ]; then
    Current_Theme="JukaMix - OS"
fi
# Get JukaMix style with fallback
JukaMix_Style="default"
if [ -x "/mnt/SDCARD/System/bin/jq" ] && [ -f "/mnt/SDCARD/System/etc/jukamix.json" ]; then
    JukaMix_Style=$(/mnt/SDCARD/System/bin/jq -r '.["JUKAMIX STYLE"] // "default"' "/mnt/SDCARD/System/etc/jukamix.json" 2>/dev/null || echo "default")
fi

# Determine font path : by default we take the one from the current theme
Current_font=""
if [ -x "/mnt/SDCARD/System/bin/jq" ] && [ -f "/mnt/SDCARD/Themes/$Current_Theme/config.json" ]; then
    Current_font=$(/mnt/SDCARD/System/bin/jq -r '.["font"] // empty' "/mnt/SDCARD/Themes/$Current_Theme/config.json" 2>/dev/null)
fi
if [ -f "/mnt/SDCARD/Themes/$Current_Theme/$Current_font" ]; then
    font_file="/mnt/SDCARD/Themes/$Current_Theme/$Current_font"
fi

# Display usage if no parameters or -h is specified
if [ $# -eq 0 ]; then
    usage
fi

# Parse command-line arguments
while [ "$#" -gt 0 ]; do
    case "$1" in
    -h) usage ;;
    -i)
        image="$2"
        shift 2
        ;;
    -k)
        validate_keys "$2"
        if [ $? -eq 0 ]; then
            wait_keys="$2"
        fi
        shift 2
        ;;
    -t)
        if is_number "$2"; then
            timer="$2"
        else
            echo "Invalid timer: $2. Using default."
        fi
        shift 2
        ;;
    -m)
        message="${2:- }"
        shift 2
        ;;
    -ff)
        if [ -f "$2" ]; then
            font_file="$2"
        else
            echo "Font file $2 does not exist. Using default."
        fi
        shift 2
        ;;
    -fs)
        if [ "$2" -eq "$2" ] 2>/dev/null; then
            font_size="$2"
        else
            echo "Invalid font size: $2. Using default."
        fi
        shift 2
        ;;
    -c)
        color=$(color_to_rgb "$2")
        shift 2
        ;;
    *) shift ;;
    esac
done

# Function to determine the image path
determine_image_path() {
    image_name="$1"
    base_path="/mnt/SDCARD/trimui/res/jukamix-os"

    # Check if image is a full path
    if [ -f "$image_name" ]; then
        base_path=$(dirname "$image_name")

        # Check if themed image exists
        themed_image="$base_path/style_$JukaMix_Style/$(basename "$image_name")"
        if [ -f "$themed_image" ]; then
            echo "$themed_image"
            return
        fi

        echo "$image_name"
        return
    fi

    # Check if themed image exists
    themed_image="$base_path/style_$JukaMix_Style/$image_name"
    if [ -f "$themed_image" ]; then
        echo "$themed_image"
        return
    fi

    # Check if image is in the base path
    if [ -f "$base_path/$image_name" ]; then
        echo "$base_path/$image_name"
        return
    fi

    # Default image
    echo "$base_path/bg-info.png"
}

# Determine the actual image path
image=$(determine_image_path "$image")

# Set the library path
PATH="/mnt/SDCARD/System/bin:$PATH"
export LD_LIBRARY_PATH="/mnt/SDCARD/System/lib:/usr/trimui/lib:$LD_LIBRARY_PATH"

touch /var/trimui_inputd/sticks_disabled 2>/dev/null

# infoscreen.sh has no caller-to-caller coordination: every menu action and
# boot-time step that shows a status toast calls this script independently.
# If two calls land within the same ~1-2s window (easy during first boot,
# when several "apply default X" steps and input-daemon setup can fire close
# together), their sdl2imgshow processes both draw to the screen with no
# lock between them, producing garbled/overlapping text and flicker as each
# call's cleanup kills the other's still-active overlay. PID_FILE below lets
# a new call hand off from (and only ever kill) the specific previous
# instance, instead of blanket `pkill -f sdl2imgshow` nuking any concurrent
# instance regardless of which call owns it.
PID_FILE="/tmp/infoscreen.pid"
LOCK_DIR="/tmp/infoscreen.lockdir"

# Best-effort, non-blocking mutex around the handoff below (mkdir is atomic).
# If it's already held, proceed anyway rather than risk hanging on a sleep
# whose fractional-second support isn't guaranteed on-device -- the PID
# hand-off itself is what actually fixes the overlap; this just narrows the
# much smaller remaining race on reading/writing $PID_FILE.
_got_lock=0
mkdir "$LOCK_DIR" 2>/dev/null && _got_lock=1

if [ -f "$PID_FILE" ]; then
    old_pid=$(cat "$PID_FILE" 2>/dev/null)
    if [ -n "$old_pid" ] && kill -0 "$old_pid" 2>/dev/null; then
        kill -TERM "$old_pid" 2>/dev/null
    fi
fi

# Run the sdl2imgshow command
/mnt/SDCARD/System/bin/sdl2imgshow \
    -i "$image" \
    -f "$font_file" \
    -s "$font_size" \
    -c "$color" \
    -t "$message" \
    >/dev/null 2>&1 &
sdl_pid=$!
echo "$sdl_pid" >"$PID_FILE"

[ "$_got_lock" -eq 1 ] && rmdir "$LOCK_DIR" 2>/dev/null

# Function to handle the timer
handle_timer() {
    if [ -n "$timer" ]; then
        sleep 1
        sleep "$timer"
        for pid in $(pgrep -f getkey.sh); do pkill -TERM -P $pid; done
    fi
}

# Start the timer and key wait handlers concurrently

if [ -n "$wait_keys" ]; then
    handle_timer &
    handle_timer_pid=$!
    button=$(/mnt/SDCARD/System/usr/trimui/scripts/getkey.sh "$wait_keys" 2>/dev/null)
    if [ -z "$button" ]; then
        button="timeout" # the timer has completed the script before the user presses a key
    fi
    echo "$button"
    kill -9 $handle_timer_pid 2>/dev/null
else
    handle_timer
fi

# Only tear down THIS call's own overlay, and only if a newer infoscreen.sh
# call hasn't already replaced it (checked via $PID_FILE) -- a blanket
# `pkill -f sdl2imgshow` here is exactly what used to kill a concurrent
# call's still-valid, not-yet-expired overlay out from under it.
current_pid=$(cat "$PID_FILE" 2>/dev/null)
if [ "$current_pid" = "$sdl_pid" ]; then
    kill -TERM "$sdl_pid" 2>/dev/null
    rm -f "$PID_FILE"
fi

rm -f /var/trimui_inputd/sticks_disabled 2>/dev/null
