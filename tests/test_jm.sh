#!/bin/sh
# tests/test_jm.sh - Self-contained test harness for JukaMix OS scripts.
#
# Builds a fake SD card in a temp dir, so it runs on CI and on a dev laptop
# with no TrimUI attached. Exercises the paths that actually break devices:
# corrupt archives, interrupted applies, protected user data, and migrations.
#
#   sh tests/test_jm.sh          # run all
#   sh tests/test_jm.sh cfg      # run tests whose name matches "cfg"

set -u

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
FILTER="${1:-}"
PASS=0
FAIL=0
FAILED_NAMES=""

#-----------------------------------------------------------------------------
# Assertions
#-----------------------------------------------------------------------------

ok()   { PASS=$((PASS + 1)); printf '  \033[32mok\033[0m   %s\n' "$1"; }
nope() { FAIL=$((FAIL + 1)); FAILED_NAMES="$FAILED_NAMES|$1"; printf '  \033[31mFAIL\033[0m %s\n' "$1"; }

assert_eq() {
	if [ "$2" = "$3" ]; then ok "$1"; else
		nope "$1"; printf '        expected: %s\n        actual:   %s\n' "$3" "$2"
	fi
}

assert_ok()      { _d="$1"; shift; if "$@" >/dev/null 2>&1; then ok "$_d succeeds"; else nope "$_d succeeds"; fi; }
assert_fails()   { _d="$1"; shift; if "$@" >/dev/null 2>&1; then nope "$_d fails as expected"; else ok "$_d fails as expected"; fi; }
assert_file()    { if [ -f "$2" ]; then ok "$1"; else nope "$1 (missing $2)"; fi; }
assert_no_file() { if [ ! -e "$2" ]; then ok "$1"; else nope "$1 ($2 should not exist)"; fi; }

assert_contains() {
	if printf '%s' "$2" | grep -q -- "$3"; then ok "$1"; else
		nope "$1"; printf '        %s does not contain %s\n' "$2" "$3"
	fi
}

should_run() {
	[ -z "$FILTER" ] && return 0
	printf '%s' "$1" | grep -q -- "$FILTER"
}

#-----------------------------------------------------------------------------
# Fake SD card
#-----------------------------------------------------------------------------

setup_sd() {
	SD=$(mktemp -d "${TMPDIR:-/tmp}/jmtest.XXXXXX")
	mkdir -p "$SD/System" "$SD/config" "$SD/lib" "$SD/bin" \
		"$SD/Roms/GB" "$SD/BIOS" "$SD/migrations" "$SD/Apps"
	cp "$REPO_ROOT/lib/jm_common.sh" "$SD/lib/" 2>/dev/null ||
		cp "$REPO_ROOT/jm_common.sh" "$SD/lib/"
	cp "$REPO_ROOT/bin/jm-update" "$SD/bin/" 2>/dev/null ||
		cp "$REPO_ROOT/jm-update" "$SD/bin/"
	chmod +x "$SD/bin/jm-update"
	printf 'v1.0.0\n' >"$SD/System/version.txt"
	printf 'PRECIOUS SAVE DATA\n' >"$SD/Roms/GB/pokemon.sav"
	printf 'bios blob\n' >"$SD/BIOS/gba_bios.bin"
	export JM_ROOT="$SD"
	export JM_LOG_LEVEL=3          # keep test output readable
	export JM_RUN_DIR="$SD/tmp"
	export JM_DEVICE_OVERRIDE=tsp
	# shellcheck disable=SC1090
	. "$SD/lib/jm_common.sh"
	jm_init "test"
}

teardown_sd() { [ -n "${SD:-}" ] && rm -rf "$SD"; }

# make_release <dir> <version> [--corrupt]
# Produces a staged release tree + zip + SHA256SUMS, like build_release.sh does.
make_release() {
	_out="$1"; _ver="$2"; _corrupt="${3:-}"
	_src="$_out/src"
	mkdir -p "$_src/bin" "$_src/System" "$_src/Roms/GB" "$_src/migrations"
	printf '#!/bin/sh\necho hello %s\n' "$_ver" >"$_src/bin/newtool"
	printf '%s\n' "$_ver" >"$_src/System/version.txt"
	# A booby trap: releases must never clobber this.
	printf 'MALICIOUS OVERWRITE\n' >"$_src/Roms/GB/pokemon.sav"
	printf '#!/bin/sh\necho migrated >> "$JM_ROOT/config/migrated.marker"\n' \
		>"$_src/migrations/1.0.0-to-$(printf '%s' "$_ver" | sed 's/^v//').sh"

	( cd "$_src" && find . -type f | sed 's|^\./||' | sort >manifest.txt )
	( cd "$_src" && find . -type f ! -name SHA256SUMS | sed 's|^\./||' |
		while IFS= read -r f; do
			printf '%s  %s\n' "$(sha256sum "$f" | awk '{print $1}')" "$f"
		done >SHA256SUMS )

	( cd "$_src" && zip -qr "$_out/JukaMix-OS_${_ver}.zip" . )
	if [ "$_corrupt" = "--corrupt" ]; then
		# Truncate the zip: simulates a Wi-Fi drop mid-download.
		_sz=$(wc -c <"$_out/JukaMix-OS_${_ver}.zip")
		dd if="$_out/JukaMix-OS_${_ver}.zip" of="$_out/trunc.zip" \
			bs=1 count=$((_sz / 2)) 2>/dev/null
		mv -f "$_out/trunc.zip" "$_out/JukaMix-OS_${_ver}.zip"
	fi
	printf '%s\n' "$_out/JukaMix-OS_${_ver}.zip"
}

#-----------------------------------------------------------------------------
# Tests
#-----------------------------------------------------------------------------

test_cfg() {
	printf '\ncfg: key=value helpers\n'
	_f="$SD/config/test.cfg"
	printf '# comment\nfoo=bar\nnum = 42 \n' >"$_f"
	assert_eq "cfg_get reads a value"        "$(jm_cfg_get "$_f" foo)"        "bar"
	assert_eq "cfg_get trims whitespace"    "$(jm_cfg_get "$_f" num)"        "42"
	assert_eq "cfg_get returns default"     "$(jm_cfg_get "$_f" nope fallback)" "fallback"
	jm_cfg_set "$_f" foo baz
	assert_eq "cfg_set overwrites"          "$(jm_cfg_get "$_f" foo)"        "baz"
	jm_cfg_set "$_f" foo baz
	assert_eq "cfg_set is idempotent"       "$(grep -c '^foo=' "$_f")"       "1"
	assert_eq "cfg_set preserves comments"  "$(grep -c '^# comment' "$_f")"  "1"
	jm_cfg_set "$_f" fresh 1
	assert_eq "cfg_set adds new keys"       "$(jm_cfg_get "$_f" fresh)"      "1"
}

test_atomic() {
	printf '\natomic: writes and mode preservation\n'
	_f="$SD/config/atomic.txt"
	printf 'original\n' >"$_f"
	chmod 755 "$_f"
	printf 'replaced\n' | jm_atomic_write "$_f"
	assert_eq "content replaced"      "$(cat "$_f")"              "replaced"
	assert_eq "mode preserved"        "$(stat -c '%a' "$_f")"     "755"
	assert_eq "no temp files left"    "$(ls -1 "$SD/config" | grep -c '^\.jm\.' || true)" "0"
}

test_lock() {
	printf '\nlock: mutual exclusion and stale recovery\n'
	assert_ok "jm_lock acquires" jm_lock demo 1
	# A stale lock from a dead pid must be reclaimed, not block forever.
	rm -rf "$JM_RUN_DIR/lock.demo"
	mkdir -p "$JM_RUN_DIR/lock.stale"
	printf '999999\n' >"$JM_RUN_DIR/lock.stale/pid"
	assert_ok "stale lock reclaimed" jm_lock stale 2
	jm_unlock stale
}

test_device() {
	printf '\ndevice: detection and capabilities\n'
	JM_DEVICE_CACHE=""; JM_DEVICE_OVERRIDE=brick
	assert_eq "brick detected"        "$(jm_device)" "brick"
	assert_contains "brick is 4:3"    "$(jm_device_caps)" "1024x768"
	assert_fails "brick has no analog" jm_has_analog
	JM_DEVICE_CACHE=""; JM_DEVICE_OVERRIDE=tg5050
	assert_eq "tg5050 detected"       "$(jm_device)" "tg5050"
	assert_ok "tg5050 has analog"     jm_has_analog
	JM_DEVICE_CACHE=""; JM_DEVICE_OVERRIDE=tsp
}

test_protected() {
	printf '\nprotected: user data classification\n'
	for p in Roms/GB/game.gb BIOS/scph1001.bin Saves/x.srm Themes/mine/bg.png \
		Profiles/me.json Data/ports/ccleste/run.sh; do
		if jm_is_protected_path "$p"; then ok "protected: $p"; else nope "protected: $p"; fi
	done
	for p in bin/jm-update System/version.txt Emus/GB/launch.sh; do
		if jm_is_protected_path "$p"; then nope "writable: $p"; else ok "writable: $p"; fi
	done
}

test_verify() {
	printf '\nverify: sha256\n'
	_f="$SD/config/blob"
	printf 'known content\n' >"$_f"
	_h=$(jm_sha256 "$_f")
	assert_ok "correct hash verifies"   jm_verify_sha256 "$_f" "$_h"
	assert_fails "wrong hash rejected"  jm_verify_sha256 "$_f" "0000000000000000000000000000000000000000000000000000000000000000"
	assert_eq "hash is lowercase hex"   "$(printf '%s' "$_h" | grep -c '^[0-9a-f]\{64\}$')" "1"
}

test_exec_bits() {
	printf '\nexec bits: FAT/exFAT repair\n'
	mkdir -p "$SD/Apps/Thing"
	printf '#!/bin/sh\ntrue\n' >"$SD/Apps/Thing/launch.sh"
	printf 'not a script\n'    >"$SD/Apps/Thing/readme.txt"
	chmod 644 "$SD/Apps/Thing/launch.sh" "$SD/Apps/Thing/readme.txt"
	jm_fix_exec_bits "$SD/Apps"
	if [ -x "$SD/Apps/Thing/launch.sh" ]; then ok "launch.sh made executable"; else nope "launch.sh made executable"; fi
	if [ -x "$SD/Apps/Thing/readme.txt" ]; then nope "plain text left alone"; else ok "plain text left alone"; fi
}

test_update_dry_run() {
	printf '\nupdate: dry run touches nothing\n'
	_rel=$(mktemp -d "${TMPDIR:-/tmp}/jmrel.XXXXXX")
	_zip=$(make_release "$_rel" v1.1.0)
	JM_ROOT="$SD" sh "$SD/bin/jm-update" apply --from-zip "$_zip" --dry-run >/dev/null 2>&1
	assert_eq "version unchanged"   "$(cat "$SD/System/version.txt")" "v1.0.0"
	assert_no_file "no new binary installed" "$SD/bin/newtool"
	rm -rf "$_rel"
}

test_update_apply() {
	printf '\nupdate: successful apply\n'
	_rel=$(mktemp -d "${TMPDIR:-/tmp}/jmrel.XXXXXX")
	_zip=$(make_release "$_rel" v1.1.0)
	JM_ROOT="$SD" sh "$SD/bin/jm-update" apply --from-zip "$_zip" >/dev/null 2>&1
	assert_file "new file installed"       "$SD/bin/newtool"
	assert_eq   "version stamped"          "$(cat "$SD/System/version.txt")" "v1.1.0"
	assert_eq   "USER SAVE PRESERVED"      "$(cat "$SD/Roms/GB/pokemon.sav")" "PRECIOUS SAVE DATA"
	assert_file "migration ran"            "$SD/config/migrated.marker"
	assert_eq   "migration recorded once"  "$(wc -l <"$SD/config/migrations.done" | tr -d ' ')" "1"
	if [ -x "$SD/bin/newtool" ]; then ok "installed script is executable"; else nope "installed script is executable"; fi

	# Re-apply: migrations must not run twice.
	JM_ROOT="$SD" sh "$SD/bin/jm-update" apply --from-zip "$_zip" >/dev/null 2>&1
	assert_eq "migration still recorded once" "$(wc -l <"$SD/config/migrations.done" | tr -d ' ')" "1"
	assert_eq "marker written once"           "$(wc -l <"$SD/config/migrated.marker" | tr -d ' ')" "1"
	rm -rf "$_rel"
}

test_update_corrupt() {
	printf '\nupdate: corrupt archive is rejected cleanly\n'
	_before=$(cat "$SD/System/version.txt")
	_rel=$(mktemp -d "${TMPDIR:-/tmp}/jmrel.XXXXXX")
	_zip=$(make_release "$_rel" v2.0.0 --corrupt)
	JM_ROOT="$SD" sh "$SD/bin/jm-update" apply --from-zip "$_zip" >/dev/null 2>&1
	assert_eq "version untouched after corrupt archive" "$(cat "$SD/System/version.txt")" "$_before"
	assert_eq "user save still intact" "$(cat "$SD/Roms/GB/pokemon.sav")" "PRECIOUS SAVE DATA"
	rm -rf "$_rel"
}

test_update_rollback() {
	printf '\nupdate: rollback restores replaced files\n'
	# Simulate an interrupted transaction by hand-crafting a journal.
	mkdir -p "$SD/System/updates/backup/bin"
	printf 'ORIGINAL TOOL\n' >"$SD/bin/sometool"
	cp "$SD/bin/sometool" "$SD/System/updates/backup/bin/sometool"
	printf 'CLOBBERED\n' >"$SD/bin/sometool"
	printf 'orphan\n'    >"$SD/bin/orphan"
	{
		printf 'BEGIN\tv1.1.0\t0\n'
		printf 'REPLACE\tbin/sometool\t%s\n' "$SD/System/updates/backup/bin/sometool"
		printf 'ADD\tbin/orphan\t-\n'
	} >"$SD/System/updates/journal"

	JM_ROOT="$SD" sh "$SD/bin/jm-update" rollback >/dev/null 2>&1
	assert_eq   "replaced file restored" "$(cat "$SD/bin/sometool")" "ORIGINAL TOOL"
	assert_no_file "added file removed"  "$SD/bin/orphan"
	assert_eq   "journal cleared"        "$(wc -c <"$SD/System/updates/journal" | tr -d ' ')" "0"
}

test_space() {
	printf '\nspace: preflight guard\n'
	assert_ok "tiny requirement passes"      jm_require_space 1 "$SD"
	assert_fails "absurd requirement fails"  jm_require_space 999999999999 "$SD"
}

#-----------------------------------------------------------------------------
# Runner
#-----------------------------------------------------------------------------

ALL="cfg atomic lock device protected verify exec_bits update_dry_run update_apply update_corrupt update_rollback space"

printf 'JukaMix test harness\nrepo: %s\n' "$REPO_ROOT"
command -v zip >/dev/null 2>&1 || { printf 'SKIP: zip not available\n'; exit 0; }

setup_sd
trap teardown_sd EXIT
printf 'sandbox: %s\n' "$SD"

for t in $ALL; do
	should_run "$t" || continue
	"test_$t"
done

printf '\n----------------------------------------\n'
printf 'passed: %s   failed: %s\n' "$PASS" "$FAIL"
if [ "$FAIL" -gt 0 ]; then
	printf 'failures:%s\n' "$(printf '%s' "$FAILED_NAMES" | tr '|' '\n')"
	exit 1
fi
printf 'all green\n'
exit 0
