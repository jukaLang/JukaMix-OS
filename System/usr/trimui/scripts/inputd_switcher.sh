#!/usr/bin/env sh
PATH="/mnt/SDCARD/System/bin:/mnt/SDCARD/System/usr/trimui/scripts:$PATH"
export LD_LIBRARY_PATH="/mnt/SDCARD/System/lib:/usr/trimui/lib:$LD_LIBRARY_PATH"

script_name=$(basename "$0" .sh)
if [ "$script_name" = "inputd_switcher" ]; then
    polling_rate=$(/mnt/SDCARD/System/bin/jq -r '.["POLLING RATE"]' "/mnt/SDCARD/System/etc/jukamix.json")
else
    polling_rate=$script_name
fi

bin_dir="/mnt/SDCARD/trimui/app"

read -r device < /etc/trimui_device.txt
# Brick and Brick Pro use the same inputd as TSP (horizontal layout)
case "$device" in
    brick|brick_pro)
        device="tsp"
        ;;
esac

# Use the device-specific input daemon when present; otherwise fall back to the
# Smart Pro (tsp) daemon. The Smart Pro S (tg5050) shares the 1280x720 display
# and horizontal layout, so the tsp daemon is a safe default until a dedicated
# tg5050_inputd is dropped into System/resources/.
src_inputd="/mnt/SDCARD/System/resources/${device}_inputd"
if [ ! -f "$src_inputd" ]; then
    src_inputd="/mnt/SDCARD/System/resources/tsp_inputd"
fi
if [ ! -f "$src_inputd" ]; then
    infoscreen -m "No input daemon available for device '$device'" -t 2 2>/dev/null
    exit 1
fi

cp "$src_inputd" "$bin_dir/trimui_inputd"
chmod +x "$bin_dir/trimui_inputd"
sync


case "$polling_rate" in
"1ms")
    echo 1000 > "$bin_dir/inputd_polling_rate.cfg"
    ;;
"8ms")
    echo 8000 > "$bin_dir/inputd_polling_rate.cfg"
    ;;
"16ms")
    rm "$bin_dir/inputd_polling_rate.cfg"
    ;;
esac

sync


# Menu modification to reflect the change immediately

# update jukamix.json configuration file
json_file="/mnt/SDCARD/System/etc/jukamix.json"
if [ ! -f "$json_file" ]; then
    echo "{}" >"$json_file"
fi
jq --arg polling_rate "$polling_rate" '. += {"POLLING RATE": $polling_rate}' "$json_file" >"/tmp/json_file.tmp" && mv "/tmp/json_file.tmp" "$json_file"

# update database of "System Tools" database
/mnt/SDCARD/System/usr/trimui/scripts/mainui_state_update.sh "POLLING RATE" "$polling_rate"

/mnt/SDCARD/System/usr/trimui/scripts/infoscreen.sh -m "Applying $polling_rate polling rate..." -t 1
pkill trimui_inputd
pkill -KILL MainUI
