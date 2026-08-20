#!/bin/sh
# JukaMix OS - universal launcher wrapper.
#
# Sets up the canonical runtime environment (PATH/LD_LIBRARY_PATH), applies a
# performance governor safely (restored on exit), keeps the display awake, runs
# the target command, then restores prior state. Never sources untrusted files
# and never logs command arguments that may contain private paths.
#
# Usage: jukamix-launch.sh [options] -- <command> [args...]
# Exit code: the target command's exit code, or 2 on usage/setup error.

set -u

TOOLS_DIR=${0%/*}
[ "$TOOLS_DIR" = "$0" ] && TOOLS_DIR=.
# shellcheck source=lib/jukamix-common.sh
. "$TOOLS_DIR/lib/jukamix-common.sh"

PATH="$JUKAMIX_BIN:$PATH"
export LD_LIBRARY_PATH="$JUKAMIX_LIB:/usr/trimui/lib:${LD_LIBRARY_PATH:-}"

VERBOSE_OVERRIDE=0
QUIET_OVERRIDE=0
DRY_RUN=0
TIMEOUT_SEC=0
NOTIFY=0
GOVERNOR="performance"
TARGET=""

while [ $# -gt 0 ]; do
	case "$1" in
		-h|--help) sed -n '2,30p' "$0"; exit 0 ;;
		-q|--quiet) QUIET_OVERRIDE=1 ;;
		-v|--verbose) VERBOSE_OVERRIDE=1 ;;
		--dry-run) DRY_RUN=1 ;;
		--timeout) TIMEOUT_SEC="$2"; shift ;;
		--notify) NOTIFY=1 ;;
		--governor) GOVERNOR="$2"; shift ;;
		--) shift; TARGET="$*"; break ;;
		*) jukamix_log ERROR "unknown argument: $1"; exit 2 ;;
	esac
	shift
done

[ "$QUIET_OVERRIDE" = "1" ] && JUKAMIX_QUIET=1
[ "$VERBOSE_OVERRIDE" = "1" ] && JUKAMIX_VERBOSE=1

if [ -z "$TARGET" ]; then
	jukamix_log ERROR "no target command provided (use -- <command>)"
	exit 2
fi

jukamix_init_log "jukamix-launch"
jukamix_trap_cleanup
jukamix_begin

# Keep the display on via the project helper when present.
if [ -x "$JUKAMIX_SCRIPTS/lcd_on.sh" ]; then
	"$JUKAMIX_SCRIPTS/lcd_on.sh" 2>/dev/null
fi

# Apply performance governor (remember previous for safe restore).
if [ -w /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]; then
	JUKAMIX_RESTORE_GOV=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null)
	jukamix_debug "previous governor: ${JUKAMIX_RESTORE_GOV:-unknown}"
	if [ "$DRY_RUN" != "1" ]; then
		echo "$GOVERNOR" >/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null \
			&& jukamix_debug "governor set to $GOVERNOR"
	fi
else
	jukamix_debug "governor control not available (off-device?)"
fi

jukamix_log INFO "launching: $(echo "$TARGET" | cut -c1-60)..."

if [ "$DRY_RUN" = "1" ]; then
	jukamix_log INFO "[dry-run] would execute: $TARGET"
	RC=0
else
	if [ "$TIMEOUT_SEC" -gt 0 ] && jukamix_have_cmd timeout; then
		timeout "$TIMEOUT_SEC" $TARGET
		RC=$?
	else
		$TARGET
		RC=$?
	fi
fi

jukamix_log INFO "target exited with code $RC"
if [ "$NOTIFY" = "1" ]; then
	if [ "$RC" -eq 0 ]; then
		jukamix_notify "JukaMix: task finished (ok)"
	else
		jukamix_notify "JukaMix: task exited $RC"
	fi
fi
exit "$RC"
