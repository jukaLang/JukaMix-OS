#!/bin/sh
# inputd_launcher.sh - Launch the correct inputd binary for the current device
#
# Device selection lives in inputd_resolve.sh (single source of truth, shared
# with inputd_switcher.sh).
#
# Usage:
#   . /mnt/SDCARD/System/usr/trimui/scripts/inputd_launcher.sh
#   launch_inputd

# shellcheck source=../scripts/inputd_resolve.sh
. /mnt/SDCARD/System/usr/trimui/scripts/inputd_resolve.sh

launch_inputd() {
	# Check if already running
	if pgrep -f trimui_inputd >/dev/null 2>&1; then
		return 0
	fi

	local inputd_binary=""

	# Resolve the correct daemon for this device (warns on fallback).
	inputd_binary="$(inputd_resolve)"

	# Fallback chain when the resolved binary is missing from the image.
	if [ ! -f "$inputd_binary" ]; then
		inputd_binary="$INPUTD_RES_APP_DIR/trimui_inputd"
	fi
	if [ ! -f "$inputd_binary" ]; then
		inputd_binary="$INPUTD_RES_DIR/tsp_inputd"
	fi

	if [ -f "$inputd_binary" ]; then
		echo "inputd_launcher: Using $inputd_binary for device=$(inputd_device_code)"
		cd "$(dirname "$inputd_binary")" || return 1
		"./$(basename "$inputd_binary")" &
		return $?
	else
		echo "inputd_launcher: ERROR - No inputd binary found" >&2
		return 1
	fi
}

# Auto-launch if sourced with --launch flag
if [ "$1" = "--launch" ]; then
	launch_inputd
fi
