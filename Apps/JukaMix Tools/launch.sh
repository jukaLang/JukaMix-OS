#!/bin/sh
# JukaMix Tools - menu launcher.
#
# Presents a restrained, read-only/diagnostic subset of the JukaMix OS toolset
# using the project's existing shellect selector. Configuration-changing tools
# (jukamix-launch, jukamix-safe-extract, jukamix-update, and the mutating modes
# of jukamix-backup / jukamix-visual-manager / jukamix-bios-check) remain
# available from the command line for advanced use.
#
# The tools are expected at JUKAMIX_TOOLS_DIR (default /mnt/SDCARD/System/jukamix);
# override with the environment variable if deployed elsewhere.

PATH="/mnt/SDCARD/System/bin:$PATH"
export LD_LIBRARY_PATH="/mnt/SDCARD/System/lib:/usr/trimui/lib:$LD_LIBRARY_PATH"

JUKAMIX_TOOLS_DIR="${JUKAMIX_TOOLS_DIR:-/mnt/SDCARD/System/jukamix}"
[ -d "$JUKAMIX_TOOLS_DIR" ] || JUKAMIX_TOOLS_DIR="/mnt/SDCARD/tools"
SHELLECT="/mnt/SDCARD/System/usr/trimui/scripts/shellect.sh"

# label|script|default-args
MENU='Doctor (system diagnostics)|jukamix-doctor.sh|--no-report
Smoke test (toolchain sanity)|jukamix-smoke-test.sh|
PortMaster preflight check|jukamix-portmaster-check.sh|--port
RetroArch profile inspector|jukamix-retroarch-profile.sh|--list
BIOS checker|jukamix-bios-check.sh|
Storage doctor|jukamix-storage-doctor.sh|
Theme / visual manager|jukamix-visual-manager.sh|
Startup profiler (report)|jukamix-startup-profiler.sh|--report
Backup utility (all)|jukamix-backup.sh|--what all'

pick() {
	_list="$1"
	if [ -x "$SHELLECT" ]; then
		printf '%s\n' "$_list" | "$SHELLECT" -t "JukaMix Tools" -b "Press A to select" 2>/dev/null
	else
		_i=1
		echo "$_list" | while IFS= read -r _l; do
			echo "  $_i) $_l"; _i=$((_i+1))
		done
		printf 'Select: ' >&2; read -r _c 2>/dev/null
		echo "$_list" | sed -n "${_c}p"
	fi
}

labels=$(echo "$MENU" | cut -d'|' -f1)

while true; do
	choice=$(pick "$labels")
	[ -z "$choice" ] && exit 0
	line=$(echo "$MENU" | grep "^$(echo "$choice" | sed 's/[][\.*^$/]/\\&/g')|")
	[ -z "$line" ] && continue
	script=$(echo "$line" | cut -d'|' -f2)
	args=$(echo "$line" | cut -d'|' -f3)
	if [ -x "$JUKAMIX_TOOLS_DIR/$script" ]; then
		"$JUKAMIX_TOOLS_DIR/$script" $args
	else
		echo "Tool not found: $JUKAMIX_TOOLS_DIR/$script" >&2
		sleep 2
	fi
done
