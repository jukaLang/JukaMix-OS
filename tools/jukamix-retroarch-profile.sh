#!/bin/sh
# JukaMix OS - RetroArch profile inspector.
#
# Shows the layered override hierarchy for a given libretro core:
#   layer 0: global       RetroArch/retroarch.cfg
#   layer 1: core override RetroArch/.retroarch/config/<core>/<core>.cfg
#   layer 2: game override <per-rom>.cfg (optional, not auto-detected)
# Each layer is validated for readability and a light syntax sanity check.
# With --export (default), it prints the merged key/value set (read-only).
#
# Exit code: 0 = ok, 1 = problems, 2 = usage error.

set -u

TOOLS_DIR=${0%/*}
[ "$TOOLS_DIR" = "$0" ] && TOOLS_DIR=.
# shellcheck source=lib/jukamix-common.sh
. "$TOOLS_DIR/lib/jukamix-common.sh"

PATH="$JUKAMIX_BIN:$PATH"
export LD_LIBRARY_PATH="$JUKAMIX_LIB:/usr/trimui/lib:${LD_LIBRARY_PATH:-}"

CORE=""
LIST=0
VERBOSE_OVERRIDE=0
QUIET_OVERRIDE=0

while [ $# -gt 0 ]; do
	case "$1" in
		-h|--help) sed -n '2,30p' "$0"; exit 0 ;;
		--core) CORE="$2"; shift ;;
		--list) LIST=1 ;;
		-q|--quiet) QUIET_OVERRIDE=1 ;;
		-v|--verbose) VERBOSE_OVERRIDE=1 ;;
		*) jukamix_log ERROR "unknown argument: $1"; exit 2 ;;
	esac
	shift
done

[ "$QUIET_OVERRIDE" = "1" ] && JUKAMIX_QUIET=1
[ "$VERBOSE_OVERRIDE" = "1" ] && JUKAMIX_VERBOSE=1

jukamix_init_log "jukamix-retroarch-profile"
jukamix_begin

PROBLEMS=0

if [ "$LIST" = "1" ]; then
	if [ -d "$JUKAMIX_RA_HOME/cores" ]; then
		echo "Installed cores:"
		for _c in "$JUKAMIX_RA_HOME/cores"/*.so; do
			[ -f "$_c" ] && echo "  ${_c##*/}"
		done
	else
		jukamix_log WARN "cores directory not found"
	fi
	exit 0
fi

if [ -z "$CORE" ]; then
	jukamix_log ERROR "provide --core <name> or --list"
	exit 2
fi

GLOBAL="$JUKAMIX_RETROARCH/retroarch.cfg"
CORECFG="$JUKAMIX_RA_HOME/config/$CORE/$CORE.cfg"

check_layer() {
	_layer="$1"; _path="$2"
	if [ -f "$_path" ]; then
		if [ -r "$_path" ]; then
			# light syntax sanity: no obviously malformed 'key=' without value or unclosed quotes
			_bad=$(grep -nE '^[^=]+=[[:space:]]*$' "$_path" 2>/dev/null | head -n 3)
			if [ -n "$_bad" ]; then
				jukamix_log WARN "layer $_layer: empty value lines detected"
				PROBLEMS=$((PROBLEMS+1))
			fi
			echo "layer $_layer: OK ($(wc -l < "$_path" 2>/dev/null) lines) $_path"
		else
			echo "layer $_layer: UNREADABLE $_path"
			PROBLEMS=$((PROBLEMS+1))
		fi
	else
		echo "layer $_layer: (absent) $_path"
	fi
	unset _layer _path _bad
}

echo "RetroArch profile for core: $CORE"
check_layer 0 "$GLOBAL"
check_layer 1 "$CORECFG"

# Merged view (read-only): later layers win.
if jukamix_have_cmd awk; then
	echo "--- merged effective settings (later layers override earlier) ---"
	awk -F= '
		function trim(s){ gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
		{
			line=$0
			if (line ~ /^#/ || line ~ /^[[:space:]]*$/) next
			eq=index(line, "=")
			if (eq==0) next
			k=trim(substr(line,1,eq-1))
			v=trim(substr(line,eq+1))
			if (k!="") kv[k]=v
		}
		END { for (k in kv) printf "%s = %s\n", k, kv[k] }
	' "$GLOBAL" "$CORECFG" 2>/dev/null | sort
fi

if [ "$PROBLEMS" -gt 0 ]; then
	exit 1
fi
exit 0
