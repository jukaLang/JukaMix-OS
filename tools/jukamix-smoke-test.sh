#!/bin/sh
# JukaMix OS - non-destructive smoke test.
#
# Runs a battery of safe, read-only checks that exercise the toolchain and
# runtime helpers without touching user data or system configuration:
#   - shell sanity (the script itself runs)
#   - jq can parse a sample document
#   - 7zz reports a version
#   - file can inspect a sample
#   - temporary directory is writable
#   - the performance governor control file is writable (if on-device)
#   - a trivial external command executes
#
# Exit code: 0 = all passed, 1 = one or more failed, 2 = setup error.

set -u

TOOLS_DIR=${0%/*}
[ "$TOOLS_DIR" = "$0" ] && TOOLS_DIR=.
# shellcheck source=lib/jukamix-common.sh
. "$TOOLS_DIR/lib/jukamix-common.sh"

PATH="$JUKAMIX_BIN:$PATH"
export LD_LIBRARY_PATH="$JUKAMIX_LIB:/usr/trimui/lib:${LD_LIBRARY_PATH:-}"

QUIET_OVERRIDE=0
VERBOSE_OVERRIDE=0

while [ $# -gt 0 ]; do
	case "$1" in
		-h|--help) sed -n '2,30p' "$0"; exit 0 ;;
		-q|--quiet) QUIET_OVERRIDE=1 ;;
		-v|--verbose) VERBOSE_OVERRIDE=1 ;;
		*) jukamix_log ERROR "unknown argument: $1"; exit 2 ;;
	esac
	shift
done

[ "$QUIET_OVERRIDE" = "1" ] && JUKAMIX_QUIET=1
[ "$VERBOSE_OVERRIDE" = "1" ] && JUKAMIX_VERBOSE=1

jukamix_init_log "jukamix-smoke-test"
jukamix_begin

PASS=0; FAIL=0

check() {
	_name="$1"; _cmd="$2"
	if eval "$_cmd" >/dev/null 2>&1; then
		PASS=$((PASS+1))
		[ "$JUKAMIX_QUIET" != "1" ] && printf '[PASS] %s\n' "$_name" >&2
	else
		FAIL=$((FAIL+1))
		[ "$JUKAMIX_QUIET" != "1" ] && printf '[FAIL] %s\n' "$_name" >&2
	fi
	unset _name _cmd
}

# 1. jq parse
check "jq-parse" "[ -x \"$JUKAMIX_JQ\" ] && printf '{\"a\":1}' | \"$JUKAMIX_JQ\" -e .a >/dev/null"

# 2. 7zz version
check "7zz-version" "[ -x \"$JUKAMIX_SEVENZ\" ] && \"$JUKAMIX_SEVENZ\" i >/dev/null 2>&1"

# 3. file inspect a known file
check "file-inspect" "jukamix_have_cmd file && file \"$0\" >/dev/null 2>&1"

# 4. writable temp dir
_tmp=$(jukamix_mktempdir)
if [ -n "$_tmp" ] && [ -d "$_tmp" ]; then
	check "tmp-writable" "touch \"$_tmp/x\" && rm -f \"$_tmp/x\""
	rm -rf "$_tmp" 2>/dev/null
else
	FAIL=$((FAIL+1)); [ "$JUKAMIX_QUIET" != "1" ] && printf '[FAIL] tmp-writable\n' >&2
fi

# 5. governor writable (only meaningful on-device)
if [ -w /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]; then
	check "governor-writable" "true"
else
	[ "$JUKAMIX_QUIET" != "1" ] && printf '[SKIP] governor-writable (off-device)\n' >&2
fi

# 6. trivial command
check "trivial-cmd" "true"

[ "$JUKAMIX_QUIET" != "1" ] && printf '---- smoke summary: pass=%s fail=%s ----\n' "$PASS" "$FAIL" >&2

if [ "$FAIL" -gt 0 ]; then
	exit 1
fi
exit 0
