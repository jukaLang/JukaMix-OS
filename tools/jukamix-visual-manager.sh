#!/bin/sh
# JukaMix OS - visual / theme manager.
#
# Lists installed themes, reports the currently selected theme (stored under
# the THEMES key of System/etc/jukamix.json for compatibility), shows per-theme
# disk usage, and validates theme structure (preview.png / bg.png presence).
#
# Default mode is read-only. Use --set <theme> to change the selection; this is
# a configuration change and always creates a backup + atomic replace, or is
# skipped under --dry-run.
#
# Exit code: 0 = ok, 1 = problems, 2 = usage error.

set -u

TOOLS_DIR=${0%/*}
[ "$TOOLS_DIR" = "$0" ] && TOOLS_DIR=.
# shellcheck source=lib/jukamix-common.sh
. "$TOOLS_DIR/lib/jukamix-common.sh"

PATH="$JUKAMIX_BIN:$PATH"
export LD_LIBRARY_PATH="$JUKAMIX_LIB:/usr/trimui/lib:${LD_LIBRARY_PATH:-}"

SET_THEME=""
DRY_RUN=0
QUIET_OVERRIDE=0
VERBOSE_OVERRIDE=0

while [ $# -gt 0 ]; do
	case "$1" in
		-h|--help) sed -n '2,40p' "$0"; exit 0 ;;
		--set) SET_THEME="$2"; shift ;;
		--dry-run) DRY_RUN=1 ;;
		-q|--quiet) QUIET_OVERRIDE=1 ;;
		-v|--verbose) VERBOSE_OVERRIDE=1 ;;
		*) jukamix_log ERROR "unknown argument: $1"; exit 2 ;;
	esac
	shift
done

[ "$QUIET_OVERRIDE" = "1" ] && JUKAMIX_QUIET=1
[ "$VERBOSE_OVERRIDE" = "1" ] && JUKAMIX_VERBOSE=1

jukamix_init_log "jukamix-visual-manager"
jukamix_begin

if [ ! -d "$JUKAMIX_THEMES" ]; then
	jukamix_log ERROR "themes directory missing: $JUKAMIX_THEMES"
	exit 1
fi

# Current selection (compat: THEMES key in jukamix.json).
CURRENT="(none)"
if [ -f "$JUKAMIX_ETC/jukamix.json" ] && [ -x "$JUKAMIX_JQ" ]; then
	CURRENT=$("$JUKAMIX_JQ" -r '.["THEMES"] // "(none)"' "$JUKAMIX_ETC/jukamix.json" 2>/dev/null)
fi

if [ -n "$SET_THEME" ]; then
	if [ ! -d "$JUKAMIX_THEMES/$SET_THEME" ]; then
		jukamix_log ERROR "theme not installed: $SET_THEME"
		exit 1
	fi
	if [ "$DRY_RUN" = "1" ]; then
		jukamix_log INFO "[dry-run] would set THEMES=$SET_THEME in jukamix.json"
		exit 0
	fi
	# Build new jukamix.json with THEMES set (preserve other keys).
	if [ -f "$JUKAMIX_ETC/jukamix.json" ] && [ -x "$JUKAMIX_JQ" ]; then
		jukamix_backup_file "$JUKAMIX_ETC/jukamix.json" >/dev/null 2>&1
		_tmp="$JUKAMIX_ETC/jukamix.json.tmp.$$"
		"$JUKAMIX_JQ" --arg t "$SET_THEME" '. + {"THEMES": $t}' "$JUKAMIX_ETC/jukamix.json" >"$_tmp" 2>/dev/null \
			&& mv -f "$_tmp" "$JUKAMIX_ETC/jukamix.json" \
			|| { jukamix_log ERROR "failed to update jukamix.json"; rm -f "$_tmp"; exit 1; }
		jukamix_log INFO "theme set to: $SET_THEME"
	else
		jukamix_log ERROR "jukamix.json or jq unavailable; cannot set theme"
		exit 1
	fi
	exit 0
fi

echo "Visual / theme manager" >&2
echo "Current selection: $CURRENT" >&2
echo "Installed themes:" >&2
for _t in "$JUKAMIX_THEMES"/*/; do
	[ -d "$_t" ] || continue
	_name=${_t%/}; _name=${_name##*/}
	_flag=""
	[ "$_name" = "$CURRENT" ] && _flag=" <-- current"
	# validation
	_v="ok"
	[ -f "$_t/preview.png" ] || [ -f "$_t/bg.png" ] || _v="missing preview/bg"
	# disk usage
	_sz="?"
	if jukamix_have_cmd du; then
		_sz=$(du -sm "$_t" 2>/dev/null | cut -f1)
	fi
	printf '  %s [%s] (%s MB) %s\n' "$_name" "$_v" "$_sz" "$_flag" >&2
done

exit 0
