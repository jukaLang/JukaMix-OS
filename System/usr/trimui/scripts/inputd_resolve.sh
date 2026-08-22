#!/bin/sh
# inputd_resolve.sh — single source of truth for input-daemon selection.
#
# IMPORTANT: this file is SOURCED by both inputd_switcher.sh and
# inputd_launcher.sh. It must never contain a top-level `exit` (or `return`):
# a trailing `exit` here would terminate the caller's shell (inputd_switcher.sh
# runs inside °customization.sh during boot; inputd_launcher.sh runs inside
# _FirmwareCheck.sh). Keep this file to function definitions and variables.
#
# Mapping:
#   tsp       → dedicated tsp_inputd (A133, polling-rate support)
#   brick     → tsp_inputd (same A133 input hardware)
#   brick_pro → brick_pro_inputd if present, else tsp_inputd
#   tg5050    → stock firmware daemon (A523; the TSP binary does not decode its
#               gamepad, so no resource binary is installed)
#   unknown   → tsp_inputd (last resort)
#
# Non-dedicated choices log a warning (stderr + /tmp/log/messages) so the
# fallback is visible instead of failing silently. A device-specific binary
# that is byte-identical to tsp_inputd is also flagged: that is the exact
# "disguised duplicate" bug that shipped tg5050_inputd as a renamed tsp_inputd.

INPUTD_RES_DIR="/mnt/SDCARD/System/resources"
INPUTD_RES_APP_DIR="/mnt/SDCARD/trimui/app"
INPUTD_RES_STOCK="/usr/trimui/bin/trimui_inputd"

inputd_device_code() {
	if [ -r /etc/trimui_device.txt ]; then
		tr -d '[:space:]' < /etc/trimui_device.txt 2>/dev/null | head -n 1
	else
		echo "unknown"
	fi
}

# Log a warning to stderr and the on-device message log (best effort).
inputd_warn() {
	_msg="$1"
	echo "inputd_resolve: $_msg" >&2
	mkdir -p /tmp/log 2>/dev/null
	echo "inputd_resolve: $_msg" >> /tmp/log/messages 2>/dev/null
}

# Warn when a device-specific binary is really tsp_inputd under a new name.
inputd_warn_if_disguised_dup() {
	_dedicated="$1"
	if [ -f "$INPUTD_RES_DIR/tsp_inputd" ] && [ -f "$_dedicated" ] \
		&& cmp -s "$_dedicated" "$INPUTD_RES_DIR/tsp_inputd" 2>/dev/null; then
		inputd_warn "'$_dedicated' is byte-identical to tsp_inputd, not a real device-specific build"
	fi
}

# Echoes the path of the input daemon to use for the given device (defaults to
# auto-detection). Warnings go to stderr + /tmp/log/messages so the stdout
# value stays clean for command substitution.
inputd_resolve() {
	_dev="${1:-$(inputd_device_code)}"
	_dev=$(printf '%s' "$_dev" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')

	case "$_dev" in
		tg5050)
			inputd_warn "$_dev has no dedicated daemon; using stock firmware inputd"
			echo "$INPUTD_RES_STOCK"
			;;
		brick_pro|brickpro)
			if [ -f "$INPUTD_RES_DIR/brick_pro_inputd" ]; then
				inputd_warn_if_disguised_dup "$INPUTD_RES_DIR/brick_pro_inputd"
				echo "$INPUTD_RES_DIR/brick_pro_inputd"
			else
				inputd_warn "$_dev has no dedicated daemon; using tsp_inputd"
				echo "$INPUTD_RES_DIR/tsp_inputd"
			fi
			;;
		brick|tsp)
			echo "$INPUTD_RES_DIR/tsp_inputd"
			;;
		*)
			inputd_warn "unknown device '$_dev'; using tsp_inputd"
			echo "$INPUTD_RES_DIR/tsp_inputd"
			;;
	esac
}
