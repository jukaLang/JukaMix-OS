#!/bin/sh
# JukaMix OS - host-safe test suite.
#
# Runs under any POSIX shell. It performs:
#   1. Syntax checks (ash -n) for every tool and the shared library.
#   2. --help smoke checks for every tool.
#   3. Unit checks for the shared library helpers.
#   4. Functional checks against the fixture tree under tools/tests/fixtures/.
#
# The suite never requires device-only binaries (7zz/jq/...); it tolerates
# their absence and asserts on logic that is portable. Set JUKAMIX_TEST_SHELL
# to a POSIX shell (default: sh) and optionally JUKAMIX_TEST_ROOT to override
# the fixture location.

set -u

# Ensure coreutils (dirname/basename/awk/...) are on PATH. Under some host
# POSIX shells (e.g. MSYS ash launched directly) PATH is minimal; this is a
# no-op on the device where these directories are already present.
export PATH="/usr/bin:/bin:/usr/local/bin:$PATH"

# Resolve locations from $0 (no dirname dependency; POSIX-portable).
SCRIPT="$0"
case "$SCRIPT" in
	*/*) TESTDIR=$(cd "${SCRIPT%/*}" && pwd) ;;
	*)   TESTDIR=$(pwd) ;;
esac
case "$TESTDIR" in
	*/*) TOOLS="${TESTDIR%/*}" ;;
	*)   TOOLS="$TESTDIR" ;;
esac
FIXTURE="${JUKAMIX_TEST_ROOT:-$TESTDIR/fixtures/root}"
MINI_MANIFEST="$TESTDIR/fixtures/bios-manifest-mini.txt"
SHELL_BIN="${JUKAMIX_TEST_SHELL:-sh}"
TAB=$(printf '\t')

PASS=0
FAIL=0

ok()   { PASS=$((PASS+1)); printf '[PASS] %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); printf '[FAIL] %s\n' "$1"; }

# Run a tool via the chosen shell with the fixture root.
run_tool() {
	# $1 = tool name; rest = args
	_t="$1"; shift
	JUKAMIX_ROOT="$FIXTURE" JUKAMIX_QUIET=1 "$SHELL_BIN" "$TOOLS/$1" "$@" 2>/dev/null
}
run_tool_out() {
	_t="$1"; shift
	JUKAMIX_ROOT="$FIXTURE" "$SHELL_BIN" "$TOOLS/$1" "$@" 2>&1
}

echo "=== JukaMix OS host-safe test suite ==="
echo "tools:   $TOOLS"
echo "fixture: $FIXTURE"
echo "shell:   $SHELL_BIN"
echo

# ---- 1. Syntax checks ----
echo "--- syntax checks (ash -n) ---"
SYNTAX_FAIL=0
for f in "$TOOLS"/jukamix-*.sh "$TOOLS"/lib/jukamix-*.sh; do
	if "$SHELL_BIN" -n "$f" 2>/dev/null; then
		ok "syntax: $(basename "$f")"
	else
		bad "syntax: $(basename "$f")"
		SYNTAX_FAIL=1
	fi
done
if [ "$SYNTAX_FAIL" -ne 0 ]; then
	echo "Fatal: syntax errors present; aborting."
	exit 2
fi
echo

# ---- 2. --help smoke checks ----
echo "--- --help smoke checks ---"
for f in "$TOOLS"/jukamix-*.sh; do
	n=$(basename "$f")
	if JUKAMIX_ROOT="$FIXTURE" "$SHELL_BIN" "$f" --help >/dev/null 2>&1; then
		ok "help: $n"
	else
		bad "help: $n"
	fi
done
echo

# ---- 3. Library unit checks ----
echo "--- library unit checks ---"
LIB="$TOOLS/lib/jukamix-common.sh"

# redact returns token not equal to input
TOK=$(JUKAMIX_ROOT="$FIXTURE" "$SHELL_BIN" -c ". '$LIB'; jukamix_redact '/private/path/rom.nes'")
if [ -n "$TOK" ] && [ "$TOK" != "/private/path/rom.nes" ]; then
	ok "redact returns anonymized token"
else
	bad "redact returned raw input"
fi

# require_cmds: known command absent from list, bogus present
MISSING=$(JUKAMIX_ROOT="$FIXTURE" "$SHELL_BIN" -c ". '$LIB'; jukamix_require_cmds sh this_cmd_does_not_exist_xyz")
if echo "$MISSING" | grep -q 'this_cmd_does_not_exist_xyz' && ! echo "$MISSING" | grep -q '^sh$'; then
	ok "require_cmds detects missing command"
else
	bad "require_cmds behavior unexpected: [$MISSING]"
fi

# version detection from fixture
VER=$(JUKAMIX_ROOT="$FIXTURE" "$SHELL_BIN" -c ". '$LIB'; jukamix_detect_version; echo \$JUKAMIX_VERSION")
if [ "$VER" = "1.3.0" ]; then
	ok "version detection (1.3.0)"
else
	bad "version detection wrong: [$VER]"
fi

# free space returns a number
FS=$(JUKAMIX_ROOT="$FIXTURE" "$SHELL_BIN" -c ". '$LIB'; jukamix_free_space_mb '$FIXTURE'")
if echo "$FS" | grep -qE '^[0-9]+$'; then
	ok "free_space_mb returns a number ($FS)"
else
	bad "free_space_mb invalid: [$FS]"
fi

# lock fallback
LK=$(JUKAMIX_ROOT="$FIXTURE" JUKAMIX_TMPBASE="$FIXTURE" "$SHELL_BIN" -c ". '$LIB'; jukamix_lock testlock && echo locked; jukamix_unlock testlock; echo unlocked")
if echo "$LK" | grep -q 'locked' && echo "$LK" | grep -q 'unlocked'; then
	ok "lock/unlock fallback works"
else
	bad "lock/unlock failed: [$LK]"
fi
echo

# ---- 4. Functional checks ----
echo "--- functional checks ---"

# doctor runs without crashing (exit 0 or 1)
RC=$(JUKAMIX_ROOT="$FIXTURE" JUKAMIX_QUIET=1 "$SHELL_BIN" "$TOOLS/jukamix-doctor.sh" --no-report >/dev/null 2>&1; echo $?)
if [ "$RC" = "0" ] || [ "$RC" = "1" ]; then
	ok "doctor runs (exit $RC)"
else
	bad "doctor crashed (exit $RC)"
fi

# bios-check with mini manifest: gba required but missing -> non-zero, mentions gba
OUT=$(JUKAMIX_ROOT="$FIXTURE" "$SHELL_BIN" "$TOOLS/jukamix-bios-check.sh" --manifest "$MINI_MANIFEST" --json 2>&1)
if echo "$OUT" | grep -q 'gba_bios.bin'; then
	ok "bios-check reports gba_bios.bin (missing required)"
else
	bad "bios-check did not report gba_bios.bin"
fi

# retroarch-profile --list finds snes9x
OUT=$(JUKAMIX_ROOT="$FIXTURE" "$SHELL_BIN" "$TOOLS/jukamix-retroarch-profile.sh" --list 2>&1)
if echo "$OUT" | grep -q 'snes9x'; then
	ok "retroarch-profile --list finds snes9x"
else
	bad "retroarch-profile --list missing snes9x"
fi

# retroarch-profile --core snes9x shows merged settings
OUT=$(JUKAMIX_ROOT="$FIXTURE" "$SHELL_BIN" "$TOOLS/jukamix-retroarch-profile.sh" --core snes9x 2>&1)
if echo "$OUT" | grep -qi 'video_driver'; then
	ok "retroarch-profile merges global settings"
else
	bad "retroarch-profile did not merge settings"
fi

# portmaster-check on Test port (no manifest entry -> UNTESTED, launcher present)
OUT=$(JUKAMIX_ROOT="$FIXTURE" "$SHELL_BIN" "$TOOLS/jukamix-portmaster-check.sh" --port Test 2>&1)
if echo "$OUT" | grep -qi 'launcher present'; then
	ok "portmaster-check detects launcher"
else
	bad "portmaster-check launcher detection failed"
fi

# portmaster-check on CaveStory (generic PASS row in the matrix): must report
# PASS and must NOT fabricate a "runtime missing" failure (guards matrix alignment)
OUT=$(JUKAMIX_ROOT="$FIXTURE" "$SHELL_BIN" "$TOOLS/jukamix-portmaster-check.sh" --port CaveStory 2>&1)
if echo "$OUT" | grep -qi 'compatibility: PASS'; then
	ok "portmaster-check matrix PASS row honored"
else
	bad "portmaster-check matrix PASS row not honored: [$OUT]"
fi
if echo "$OUT" | grep -qi 'runtime missing'; then
	bad "portmaster-check fabricated a runtime-missing failure (matrix misalignment)"
else
	ok "portmaster-check no false runtime-missing failure"
fi

# visual-manager lists themes and current selection
OUT=$(JUKAMIX_ROOT="$FIXTURE" "$SHELL_BIN" "$TOOLS/jukamix-visual-manager.sh" 2>&1)
if echo "$OUT" | grep -q 'JukaMix - OS' && echo "$OUT" | grep -qi 'current selection'; then
	ok "visual-manager lists themes + selection"
else
	bad "visual-manager output incomplete"
fi

# ---- 5. Device Compatibility Layer ----
echo "--- device compatibility layer ---"
LIB_DEVICE="$TOOLS/lib/jukamix-device.sh"
JUKAMIX_DEVICE_DB="$TOOLS/data/compatibility-db.txt"
JUKAMIX_LIB_DIR="$TOOLS/lib"
# Source the library directly in this shell (avoids a fragile sh -c sub-shell).
if . "$LIB_DEVICE" 2>/dev/null; then
	for _d in tsp tg5050 brick; do
		JUKAMIX_DEVICE_FORCE="$_d"
		_h=$(jukamix_capability horizontal_display)
		case "$_d" in
			tsp|tg5050) _exp=SUPPORTED ;;
			brick)      _exp=INCOMPATIBLE ;;
		esac
		if [ "$_h" = "$_exp" ]; then ok "capability horizontal_display=$_exp for $_d"; else bad "horizontal_display for $_d = [$_h] (want $_exp)"; fi
	done
	_Q=$(jukamix_compat_query tsp '*' '*' horizontal_display)
	[ "$_Q" = "SUPPORTED" ] && ok "compat-db query tsp horizontal_display" || bad "compat-db query = [$_Q]"
	_Q2=$(jukamix_compat_query tg5050 '*' '*' 'port/VVVVVV')
	[ "$_Q2" = "UNTESTED" ] && ok "compat-db tg5050 port/VVVVVV UNTESTED" || bad "port/VVVVVV tg5050 = [$_Q2]"
else
	bad "could not source $LIB_DEVICE"
fi
unset _d _h _exp _Q _Q2

# ---- 6. Safe Mode & Recovery ----
echo "--- safe mode & recovery ---"
RECOVERY_LIB="$TOOLS/lib/jukamix-recovery.sh"
JUKAMIX_LIB_DIR="$TOOLS/lib"
JUKAMIX_TOOLS_DIR="$TOOLS"
JUKAMIX_DEVICE_DB="$TOOLS/data/compatibility-db.txt"
if . "$RECOVERY_LIB" 2>/dev/null; then
	_T="$JUKAMIX_TMPBASE/jukamix-test-$$"
	mkdir -p "$_T"; cp -r "$FIXTURE"/* "$_T"/ 2>/dev/null
	mkdir -p "$_T/Roms" "$_T/Saves"
	export JUKAMIX_ROOT="$_T"
	export JUKAMIX_SUPPORT="$_T/support"
	export JUKAMIX_ETC="$_T/System/etc"
	export JUKAMIX_RA_HOME="$_T/RetroArch/.retroarch"
	export JUKAMIX_FORCE_CONFIRM=yes
	jukamix_boot_begin; jukamix_boot_begin; jukamix_boot_begin
	if jukamix_safe_mode_active; then ok "safe mode engages after repeated crashes"; else bad "safe mode did not engage"; fi
	_BEFORE=$(ls -1 "$_T/BIOS" 2>/dev/null | sort)
	jukamix_reset_defaults >/dev/null 2>&1
	if grep -q '"THEMES": "Default"' "$_T/System/etc/jukamix.json"; then ok "reset-defaults sets THEMES=Default"; else bad "THEMES not set to Default"; fi
	_AFTER=$(ls -1 "$_T/BIOS" 2>/dev/null | sort)
	if [ "$_BEFORE" = "$_AFTER" ] && [ -d "$_T/Roms" ] && [ -d "$_T/Saves" ]; then ok "reset-defaults left BIOS/Roms/Saves untouched"; else bad "user data modified by reset"; fi
	jukamix_boot_ok
	if jukamix_safe_mode_active; then bad "safe mode still active after clean boot"; else ok "clean boot clears safe mode"; fi
	rm -rf "$_T"
else
	bad "could not source $RECOVERY_LIB"
fi
unset _T _BEFORE _AFTER RECOVERY_LIB

# ---- 7. Manifest tool (generate/verify) ----
echo "--- manifest tool ---"
if jukamix_have_cmd find >/dev/null 2>&1 || "$SHELL_BIN" -c 'command -v find' >/dev/null 2>&1; then
	_M=$(mktemp)
	JUKAMIX_ROOT="$FIXTURE" JUKAMIX_SYSTEM="$FIXTURE/System" "$SHELL_BIN" "$TOOLS/jukamix-manifest.sh" --generate --output "$_M" --root "$FIXTURE/System" >/dev/null 2>&1
	if [ -s "$_M" ]; then ok "manifest generate produced output"; else bad "manifest generate empty"; fi
	if JUKAMIX_ROOT="$FIXTURE" JUKAMIX_SYSTEM="$FIXTURE/System" "$SHELL_BIN" "$TOOLS/jukamix-manifest.sh" --verify --manifest "$_M" --root "$FIXTURE/System" >/dev/null 2>&1; then
		ok "manifest verify passes on fresh tree"
	else
		bad "manifest verify failed"
	fi
	rm -f "$_M"
else
	ok "manifest test skipped (find unavailable on host)"
fi

# ---- 8. Verified auto-updater (JukaHubV2 trust model) ----
echo "--- verified updater ---"
LIB_UPDATE="$TOOLS/lib/jukamix-update.sh"
if . "$LIB_UPDATE" 2>/dev/null; then
	# parse_sha256sums was removed with the SHA256SUMS download-verification
	# file; per-file integrity now comes from the manifest.
	jukamix_update_version_gt "1.4.0" "1.3.9" && ok "version_gt 1.4.0>1.3.9" || bad "version_gt wrong"
	jukamix_update_version_gt "1.3.9" "1.4.0" && bad "version_gt false positive" || ok "version_gt 1.3.9>1.4.0 false"
	jukamix_update_version_gt "1.4.0" "1.4.0" && bad "version_gt equal false positive" || ok "version_gt equal false"
	_TF=$(mktemp)
	echo "jukamix" > "$_TF"
	_REAL=$(jukamix_update_sha256 "$_TF")
	jukamix_update_verify_file "$_TF" "$_REAL" && ok "verify_file passes on matching hash" || bad "verify_file rejected valid hash"
	jukamix_update_verify_file "$_TF" "deadbeef" && bad "verify_file accepted wrong hash" || ok "verify_file rejects wrong hash"
	rm -f "$_TF"
else
	bad "could not source $LIB_UPDATE"
fi
unset _SUMS _h _TF _REAL LIB_UPDATE

# ---- 9. Safe transactional OTA updater ----
echo "--- safe OTA updater ---"
LIB_OTA="$TOOLS/lib/jukamix-ota.sh"
if . "$LIB_OTA" 2>/dev/null; then
	_OD="$JUKAMIX_TMPBASE/jukamix-ota-test-$$"
	rm -rf "$_OD"; mkdir -p "$_OD/root/System/sub" "$_OD/root/Roms" "$_OD/root/BIOS" "$_OD/root/Themes" "$_OD/payload/System/sub"
	# user-data guard
	jukamix_ota_is_user_data "/mnt/SDCARD/Roms/game.sfc" && ok "user-data guard: Roms" || bad "guard missed Roms"
	jukamix_ota_is_user_data "/mnt/SDCARD/BIOS/file" && ok "user-data guard: BIOS" || bad "guard missed BIOS"
	jukamix_ota_is_user_data "/mnt/SDCARD/Themes/foo" && ok "user-data guard: Themes" || bad "guard missed Themes"
	jukamix_ota_is_user_data "/mnt/SDCARD/System/sub/x.sh" || ok "non-user-data allowed: System" || bad "guard over-blocked System"
	# Detect whether this filesystem honors exec bits (rtools /tmp is noexec).
	_chmod_ok=1; _tf2="$JUKAMIX_TMPBASE/chmodtest-$$"; : > "$_tf2"; chmod +x "$_tf2"; [ -x "$_tf2" ] && _chmod_ok=0; rm -f "$_tf2"
	_ROOT="$_OD/root"
	# build a valid payload + manifest
	echo "hello" > "$_OD/payload/System/sub/newfile.sh"
	_SHA=$(jukamix_update_sha256 "$_OD/payload/System/sub/newfile.sh")
	printf "install${TAB}System/sub/newfile.sh${TAB}%s/System/sub/newfile.sh${TAB}%s${TAB}executable\n" "$_ROOT" "$_SHA" > "$_OD/payload/manifest.txt"
	_RB="$_OD/rb"; mkdir -p "$_RB"
	if jukamix_ota_apply "$_OD/payload" "$_OD/payload/manifest.txt" "$_RB"; then
		[ -f "$_ROOT/System/sub/newfile.sh" ] && ok "apply installed file" || bad "apply did not install"
		if [ "$_chmod_ok" -eq 0 ]; then
			[ -x "$_ROOT/System/sub/newfile.sh" ] && ok "apply set executable" || bad "executable flag missing"
		else
			ok "exec flag applied (exec-bit check skipped on noexec FS)"
		fi
	else
		bad "apply reported failure on valid manifest"
	fi
	# rollback removes the newly added file
	jukamix_ota_rollback "$_RB"
	[ ! -e "$_ROOT/System/sub/newfile.sh" ] && ok "rollback removed new file" || bad "rollback left file"
	# paths with spaces (real JukaMix tree: "Apps/System Update") must survive
	# the TAB-delimited manifest round-trip
	mkdir -p "$_OD/payload/Apps/System Update" "$_OD/root/Apps"
	echo "spaces" > "$_OD/payload/Apps/System Update/launch.sh"
	_SP_SHA=$(jukamix_update_sha256 "$_OD/payload/Apps/System Update/launch.sh")
	printf "install${TAB}Apps/System Update/launch.sh${TAB}%s/Apps/System Update/launch.sh${TAB}%s\n" "$_ROOT" "$_SP_SHA" > "$_OD/payload/manifest.txt"
	_SPRB="$_OD/rbsp"; mkdir -p "$_SPRB"
	if jukamix_ota_apply "$_OD/payload" "$_OD/payload/manifest.txt" "$_SPRB"; then
		[ -f "$_ROOT/Apps/System Update/launch.sh" ] && ok "apply handles paths with spaces" || bad "spaces path not installed"
	else
		bad "apply failed on spaces path"
	fi
	jukamix_ota_rollback "$_SPRB"
	[ ! -e "$_ROOT/Apps/System Update/launch.sh" ] && ok "rollback removes spaces path" || bad "spaces path left after rollback"
	# remove op deletes a target and rollback restores it
	echo "delete-me" > "$_ROOT/System/sub/old.sh"
	printf "remove${TAB}%s/System/sub/old.sh\n" "$_ROOT" > "$_OD/payload/manifest.txt"
	_RM="$_OD/rbrm"; mkdir -p "$_RM"
	if jukamix_ota_apply "$_OD/payload" "$_OD/payload/manifest.txt" "$_RM"; then
		[ ! -e "$_ROOT/System/sub/old.sh" ] && ok "apply removed file" || bad "remove did not delete"
	else
		bad "apply failed on remove manifest"
	fi
	jukamix_ota_rollback "$_RM"
	[ -f "$_ROOT/System/sub/old.sh" ] && ok "rollback restored removed file" || bad "rollback did not restore"
	# checksum mismatch must refuse and leave target untouched
	echo "tampered" > "$_OD/payload/System/sub/newfile.sh"
	printf "install${TAB}System/sub/newfile.sh${TAB}%s/System/sub/newfile.sh${TAB}%s\n" "$_ROOT" "$_SHA" > "$_OD/payload/manifest.txt"
	_BRB="$_OD/rb2"; mkdir -p "$_BRB"
	jukamix_ota_apply "$_OD/payload" "$_OD/payload/manifest.txt" "$_BRB" && bad "apply accepted bad checksum" || ok "apply refused checksum mismatch"
	[ ! -e "$_ROOT/System/sub/newfile.sh" ] && ok "bad checksum left target untouched" || bad "bad checksum modified target"
	jukamix_ota_rollback "$_BRB"
	# user-data op must be refused
	printf "install${TAB}System/sub/x${TAB}%s/Roms/x\n" "$_ROOT" > "$_OD/payload/manifest.txt"
	_BRB3="$_OD/rb3"; mkdir -p "$_BRB3"
	jukamix_ota_apply "$_OD/payload" "$_OD/payload/manifest.txt" "$_BRB3" && bad "apply allowed user-data target" || ok "apply refused user-data target"
	jukamix_ota_rollback "$_BRB3"
	# signature best-effort (skip if openssl lacks ed25519)
	if openssl genpkey -algorithm ed25519 -out "$_OD/priv.pem" >/dev/null 2>&1 && openssl pkey -in "$_OD/priv.pem" -pubout -out "$_OD/pub.pem" >/dev/null 2>&1; then
		printf "install${TAB}System/sub/newfile.sh${TAB}%s/System/sub/newfile.sh${TAB}%s\n" "$_ROOT" "$_SHA" > "$_OD/payload/manifest.txt"
		if openssl pkeyutl -sign -inkey "$_OD/priv.pem" -rawin -in "$_OD/payload/manifest.txt" -sigfile "$_OD/payload/manifest.txt.sig" >/dev/null 2>&1; then
			jukamix_ota_verify_signature "$_OD/pub.pem" "$_OD/payload/manifest.txt" "$_OD/payload/manifest.txt.sig" >/dev/null 2>&1 && ok "Ed25519 signature verifies" || bad "Ed25519 signature verify failed"
			echo "# tampered" >> "$_OD/payload/manifest.txt"
			jukamix_ota_verify_signature "$_OD/pub.pem" "$_OD/payload/manifest.txt" "$_OD/payload/manifest.txt.sig" >/dev/null 2>&1 && bad "Ed25519 accepted tampered manifest" || ok "Ed25519 rejects tampered manifest"
		else
			ok "Ed25519 signing unavailable in this openssl (verify path skipped)"
		fi
	else
		ok "Ed25519 signature test skipped (openssl ed25519 unavailable)"
	fi
	rm -rf "$_OD"
else
	bad "could not source $LIB_OTA"
fi
unset _OD _RB _BRB _BRB3 _RM _SHA _SPRB _SP_SHA LIB_OTA

# ---- 9b. Config migration runner ----
echo "--- config migration runner ---"
if . "$TOOLS/lib/jukamix-ota.sh" 2>/dev/null; then
	_MD="$JUKAMIX_TMPBASE/jukamix-mig-test-$$"
	rm -rf "$_MD"; mkdir -p "$_MD/migrations" "$_MD/state" "$_MD/tmp"
	cat > "$_MD/migrations/4-to-5.sh" <<'EOF'
#!/bin/sh
echo "migrated-4-5" >> "${JUKAMIX_MIGRATE_MARKER:-/tmp/ignore}"
EOF
	cat > "$_MD/migrations/5-to-6.sh" <<'EOF'
#!/bin/sh
echo "migrated-5-6" >> "${JUKAMIX_MIGRATE_MARKER:-/tmp/ignore}"
EOF
	_MARK="$_MD/marker.txt"
	export JUKAMIX_MIGRATIONS_DIR="$_MD/migrations"
	export JUKAMIX_MIGRATIONS_STATE="$_MD/state/applied-migrations"
	export JUKAMIX_MIGRATE_MARKER="$_MARK"
	jukamix_ota_migrate
	[ -s "$_MD/state/applied-migrations" ] && ok "migrate records applied migrations" || bad "migrate did not record state"
	if [ "$(cat "$_MARK" 2>/dev/null)" = "migrated-4-5
migrated-5-6" ]; then
		ok "migrate runs migrations in numeric order"
	else
		bad "migrate order wrong: [$(cat "$_MARK" 2>/dev/null)]"
	fi
	jukamix_ota_migrate
	[ "$(wc -l < "$_MARK")" -eq 2 ] && ok "migrate skips already-applied migrations" || bad "migrate re-applied migrations"
	rm -rf "$_MD"
else
	bad "could not source ota lib for migrate check"
fi
unset _MD _MARK JUKAMIX_MIGRATIONS_DIR JUKAMIX_MIGRATIONS_STATE JUKAMIX_MIGRATE_MARKER

# ---- 9c. busybox applet installer ----
echo "--- busybox applet installer ---"
BBTOOL="$TOOLS/jukamix-busybox.sh"
if [ -f "$BBTOOL" ]; then
	_BD="$JUKAMIX_TMPBASE/jukamix-bb-test-$$"
	rm -rf "$_BD"; mkdir -p "$_BD/System/bin" "$_BD/System/usr/trimui/scripts"
	printf '#!/bin/sh\nexit 0\n' > "$_BD/System/usr/trimui/scripts/busybox"
	chmod +x "$_BD/System/usr/trimui/scripts/busybox"
	printf '#!/bin/sh\nexit 0\n' > "$_BD/System/bin/wget"
	OUT=$(JUKAMIX_ROOT="$_BD" sh "$BBTOOL" --list 2>&1)
	echo "$OUT" | grep -q 'tar' && ok "busybox list includes tar" || bad "busybox list missing tar"
	OUT=$(JUKAMIX_ROOT="$_BD" sh "$BBTOOL" --install 2>&1)
	echo "$OUT" | grep -q 'installed' && ok "busybox install ran" || bad "busybox install failed: [$OUT]"
	[ -e "$_BD/System/bin/busybox" ] && ok "busybox binary linked into System/bin" || bad "busybox binary not linked"
	[ -f "$_BD/System/bin/wget" ] && ok "busybox install left real wget alone" || bad "busybox install overwrote wget"
	rm -rf "$_BD"
else
	bad "missing $BBTOOL"
fi
unset _BD BBTOOL OUT

# ---- 9d. opkg-compatible package manager ----
echo "--- opkg package manager ---"
LIB_OPKG="$TOOLS/lib/jukamix-opkg.sh"
if [ -f "$LIB_OPKG" ] && command -v tar >/dev/null 2>&1 && command -v gzip >/dev/null 2>&1; then
	_PD="$JUKAMIX_TMPBASE/jukamix-opkg-test-$$"
	rm -rf "$_PD"; mkdir -p "$_PD/src/libdemo/data/usr/lib" "$_PD/src/hello/data/usr/bin" "$_PD/feed"
	cat > "$_PD/src/libdemo/control" <<'EOF'
Package: libdemo
Version: 1.0.0
Architecture: aarch64
Description: Test library dependency
EOF
	echo "libdata" > "$_PD/src/libdemo/data/usr/lib/libdemo.txt"
	cat > "$_PD/src/hello/control" <<'EOF'
Package: hello
Version: 1.2.3
Architecture: aarch64
Depends: libdemo
Description: Test package that depends on libdemo
EOF
	echo "hello v1" > "$_PD/src/hello/data/usr/bin/hello"
	echo "stale" > "$_PD/src/hello/data/usr/bin/hello-old"
	cat > "$_PD/src/hello/postinst" <<'EOF'
#!/bin/sh
# exercise the maintainer-script env (IPKG_INSTROOT) and exec-bit restore
chmod +x "${IPKG_INSTROOT:-/tmp}/usr/bin/hello" 2>/dev/null || true
echo configured > "${IPKG_INSTROOT:-/tmp}/postinst-ran"
EOF
	cat > "$_PD/src/hello/prerm" <<'EOF'
#!/bin/sh
echo removed > "${IPKG_INSTROOT:-/tmp}/prerm-ran"
EOF
	cat > "$_PD/src/hello/postrm" <<'EOF'
#!/bin/sh
echo removed > "${IPKG_INSTROOT:-/tmp}/postrm-ran"
EOF
	sh "$TOOLS/jukamix-mkpackage.sh" "$_PD/src/libdemo" "$_PD/feed" aarch64 >/dev/null 2>&1
	sh "$TOOLS/jukamix-mkpackage.sh" "$_PD/src/hello" "$_PD/feed" aarch64 >/dev/null 2>&1
	sh "$TOOLS/jukamix-mkfeed.sh" "$_PD/feed" >/dev/null 2>&1
	[ -f "$_PD/feed/Packages" ] && ok "mkfeed produced Packages index" || bad "mkfeed produced no index"
	grep -q '^Package: hello$' "$_PD/feed/Packages" && ok "feed index lists hello" || bad "feed index missing hello"

	if . "$LIB_OPKG" 2>/dev/null; then
		JUKAMIX_OPKG_FEED="$_PD/feed"
		JUKAMIX_OPKG_ROOT="$_PD/root"
		JUKAMIX_OPKG_STATE="$_PD/state"
		JUKAMIX_OPKG_ARCH="aarch64"
		mkdir -p "$JUKAMIX_OPKG_ROOT"
		jukamix_opkg_update >/dev/null 2>&1 && ok "opkg update reads local feed" || bad "opkg update failed"
		jukamix_opkg_list | grep -q '^hello$' && ok "opkg list finds hello" || bad "opkg list missing hello"
		jukamix_opkg_install hello >/dev/null 2>&1 && ok "opkg install hello" || bad "opkg install hello failed"
		[ -f "$JUKAMIX_OPKG_ROOT/usr/bin/hello" ] && ok "opkg installed hello payload" || bad "opkg payload missing"
		[ -f "$JUKAMIX_OPKG_ROOT/postinst-ran" ] && ok "opkg ran postinst with IPKG_INSTROOT" || bad "postinst did not run with install root"
		[ -f "$JUKAMIX_OPKG_ROOT/usr/lib/libdemo.txt" ] && ok "opkg resolved libdemo dependency" || bad "dependency not installed"
		jukamix_opkg_list_installed | grep -q '^libdemo ' && ok "opkg records dependency as installed" || bad "dependency not recorded"
		jukamix_opkg_info hello | grep -q 'Depends: libdemo' && ok "opkg info shows metadata" || bad "opkg info missing metadata"

		# upgrade: bump hello to 2.0.0, drop hello-old, keep only latest in feed
		sed -i 's/Version: 1.2.3/Version: 2.0.0/' "$_PD/src/hello/control"
		rm -f "$_PD/src/hello/data/usr/bin/hello-old"
		echo "hello v2" > "$_PD/src/hello/data/usr/bin/hello"
		sh "$TOOLS/jukamix-mkpackage.sh" "$_PD/src/hello" "$_PD/feed" aarch64 >/dev/null 2>&1
		sh "$TOOLS/jukamix-mkfeed.sh" "$_PD/feed" >/dev/null 2>&1
		jukamix_opkg_update >/dev/null 2>&1
		jukamix_opkg_install hello >/dev/null 2>&1 && ok "opkg upgrade hello" || bad "opkg upgrade hello failed"
		grep -q 'hello v2' "$JUKAMIX_OPKG_ROOT/usr/bin/hello" && ok "opkg upgrade wrote new payload" || bad "opkg upgrade payload wrong"
		[ ! -f "$JUKAMIX_OPKG_ROOT/usr/bin/hello-old" ] && ok "opkg upgrade dropped stale file" || bad "opkg upgrade left stale file"
		jukamix_opkg_list_installed | grep -q '^hello 2.0.0' && ok "opkg upgrade recorded new version" || bad "opkg upgrade version not recorded"

		jukamix_opkg_remove hello >/dev/null 2>&1 && ok "opkg remove hello" || bad "opkg remove hello failed"
		[ ! -f "$JUKAMIX_OPKG_ROOT/usr/bin/hello" ] && ok "opkg remove deleted payload" || bad "opkg remove left payload"
		[ -f "$JUKAMIX_OPKG_ROOT/prerm-ran" ] && ok "opkg ran prerm" || bad "opkg prerm not run"
		[ -f "$JUKAMIX_OPKG_ROOT/postrm-ran" ] && ok "opkg ran postrm" || bad "opkg postrm not run"
	else
		bad "could not source $LIB_OPKG"
	fi
	rm -rf "$_PD"
else
	ok "opkg package manager skipped (tar/gzip unavailable)"
fi
unset _PD LIB_OPKG

# ---- 9e. JukaHub auto-installer ----
echo "--- jukahub installer ---"
JHTOOL="$TOOLS/jukamix-jukahub.sh"
if [ -f "$JHTOOL" ] && command -v python3 >/dev/null 2>&1; then
	_JH="$JUKAMIX_TMPBASE/jukamix-jukahub-test-$$"
	rm -rf "$_JH"; mkdir -p "$_JH/fake" "$_JH/root/Apps/Activities" "$_JH/root/Apps/RetroArch"
	printf '#!/bin/sh\necho fake jukahub\n' > "$_JH/fake/JukaHub"
	printf '#!/bin/sh\necho launcher\n' > "$_JH/fake/launch.sh"
	echo '{}' > "$_JH/fake/jukaconfig.json"
	mkdir -p "$_JH/fake/GIFs"; echo gif > "$_JH/fake/GIFs/test.gif"
	( cd "$_JH/fake" && python3 -c '
import sys, zipfile
z = zipfile.ZipFile(sys.argv[1], "w")
for f in ["JukaHub", "launch.sh", "jukaconfig.json", "GIFs/test.gif"]:
    z.write(f, f)
z.close()' "$_JH/JukaHub.zip" )
	_JHSHA=$(sha256sum "$_JH/JukaHub.zip" | awk '{print $1}')
	echo a > "$_JH/root/Apps/Activities/x.sh"
	echo r > "$_JH/root/Apps/RetroArch/x.sh"

	JUKAHUB_ROOT="$_JH/root" sh "$JHTOOL" status | grep -q 'not installed' && ok "jukahub status reports missing" || bad "jukahub status wrong"
	JUKAHUB_ROOT="$_JH/root" JUKAHUB_ARCHIVE="$_JH/JukaHub.zip" JUKAHUB_SHA256="0000000000000000000000000000000000000000000000000000000000000000" sh "$JHTOOL" install >/dev/null 2>&1 && bad "jukahub install accepted bad checksum" || ok "jukahub install refuses bad checksum"
	[ ! -e "$_JH/root/JukaHub" ] && ok "jukahub bad checksum left nothing installed" || bad "jukahub bad checksum left files"
	JUKAHUB_ROOT="$_JH/root" JUKAHUB_ARCHIVE="$_JH/JukaHub.zip" JUKAHUB_SHA256="$_JHSHA" sh "$JHTOOL" install --replace-apps >/dev/null 2>&1 && ok "jukahub install" || bad "jukahub install failed"
	[ -x "$_JH/root/JukaHub/JukaHub" ] && ok "jukahub binary installed and executable" || bad "jukahub binary missing"
	[ -f "$_JH/root/JukaHub/.jukahub-version" ] && ok "jukahub version marker written" || bad "jukahub version marker missing"
	[ -f "$_JH/root/JukaHub/jukaconfig.json" ] && ok "jukahub payload extracted" || bad "jukahub payload missing"
	[ ! -e "$_JH/root/Apps/Activities" ] && ok "jukahub moved replaced app to backup" || bad "jukahub did not move replaced app"
	[ -e "$_JH/root/Apps/RetroArch" ] && ok "jukahub left non-replaced app alone" || bad "jukahub removed non-replaced app"
	JUKAHUB_ROOT="$_JH/root" sh "$JHTOOL" restore-apps >/dev/null 2>&1 && [ -e "$_JH/root/Apps/Activities" ] && ok "jukahub restore-apps brings apps back" || bad "jukahub restore-apps failed"
	JUKAHUB_ROOT="$_JH/root" sh "$JHTOOL" remove >/dev/null 2>&1 && [ ! -e "$_JH/root/JukaHub" ] && ok "jukahub remove uninstalls" || bad "jukahub remove failed"
	[ -f "$_JH/root/System/var/jukamix/state/jukahub-skip" ] && ok "jukahub remove disables auto-install" || bad "jukahub remove did not create skip flag"
	JUKAHUB_ROOT="$_JH/root" sh "$JHTOOL" unskip >/dev/null 2>&1
	JUKAHUB_ROOT="$_JH/root" JUKAHUB_ARCHIVE="$_JH/JukaHub.zip" JUKAHUB_SHA256="$_JHSHA" sh "$JHTOOL" install >/dev/null 2>&1 && ok "jukahub reinstall after unskip" || bad "jukahub reinstall failed"
	[ ! -f "$_JH/root/System/var/jukamix/state/jukahub-skip" ] && ok "jukahub install clears skip flag" || bad "jukahub install kept skip flag"
	rm -rf "$_JH"
else
	bad "missing $JHTOOL or python3"
fi
unset _JH _JHSHA JHTOOL

# ---- 10. OTA manifest generator ----
echo "--- OTA manifest generator ---"
GEN="$TOOLS/make-ota-manifest.sh"
if [ -f "$GEN" ]; then
	_GD="$JUKAMIX_TMPBASE/jukamix-manifest-test-$$"
	rm -rf "$_GD"; mkdir -p "$_GD/System/bin" "$_GD/System" "$_GD/Roms/game" "$_GD/.git" "$_GD/_assets" "$_GD/BIOS" "$_GD/sandbox"
	echo "v1" > "$_GD/System/bin/tool.sh"; chmod +x "$_GD/System/bin/tool.sh"
	echo "data" > "$_GD/System/conf.txt"
	echo "rom" > "$_GD/Roms/game/a.sfc"
	echo "bios" > "$_GD/BIOS/snes.bin"
	echo "x" > "$_GD/.git/config"
	echo "y" > "$_GD/_assets/foo"
	_GM="$_GD/manifest.txt"
	if sh "$GEN" "$_GD" "$_GM" "$_GD/sandbox" >/dev/null 2>&1; then
		grep -q "install${TAB}System/bin/tool.sh" "$_GM" && ok "manifest includes OS file" || bad "manifest missing OS file"
		! grep -q 'Roms/game' "$_GM" && ok "manifest excludes Roms" || bad "manifest leaked Roms"
		! grep -q 'BIOS/snes' "$_GM" && ok "manifest excludes BIOS" || bad "manifest leaked BIOS"
		! grep -q '/.git/' "$_GM" && ok "manifest excludes .git" || bad "manifest leaked .git"
		! grep -q '_assets' "$_GM" && ok "manifest excludes _assets" || bad "manifest leaked _assets"
		# exec flag is only emitted on filesystems that honor exec bits
		_tf3="$JUKAMIX_TMPBASE/exectest-$$"; : > "$_tf3"; chmod +x "$_tf3"; _execok=0; [ -x "$_tf3" ] && _execok=1; rm -f "$_tf3"
		if [ "$_execok" -eq 1 ]; then
			grep -q 'executable' "$_GM" && ok "manifest marks executable" || bad "manifest missing executable flag"
		else
			ok "executable flag skipped on noexec FS"
		fi
		# the generated manifest must apply cleanly via jukamix_ota_apply
		if . "$TOOLS/lib/jukamix-ota.sh" 2>/dev/null; then
			_gp="$_GD/payload"; rm -rf "$_gp"; mkdir -p "$_gp/System/bin" "$_gp/System"
			cp "$_GD/System/bin/tool.sh" "$_gp/System/bin/tool.sh"
			cp "$_GD/System/conf.txt" "$_gp/System/conf.txt"
			_grb="$_GD/rb"; mkdir -p "$_grb"
			if jukamix_ota_apply "$_gp" "$_GM" "$_grb"; then
				[ -f "$_GD/sandbox/System/bin/tool.sh" ] && ok "generated manifest applies" || bad "apply did not install from generated manifest"
			else
				bad "generated manifest failed to apply"
			fi
			jukamix_ota_rollback "$_grb"
		else
			bad "could not source ota lib for apply check"
		fi
	else
		bad "make-ota-manifest.sh failed"
	fi
	rm -rf "$_GD"
else
	bad "missing $GEN"
fi
unset _GD _GM _gp _grb GEN _execok _tf3

# ---- 10b. Incremental OTA patch generator ----
echo "--- incremental patch generator ---"
PATCHGEN="$TOOLS/make-ota-patch.sh"
if [ -f "$PATCHGEN" ]; then
	_PD="$JUKAMIX_TMPBASE/jukamix-patch-test-$$"
	rm -rf "$_PD"; mkdir -p "$_PD/old/System/bin" "$_PD/new/System/bin" "$_PD/out"
	printf '#!/bin/sh\nkeep\n' > "$_PD/old/System/bin/keep.sh"; cp "$_PD/old/System/bin/keep.sh" "$_PD/new/System/bin/keep.sh"
	printf '#!/bin/sh\ndel\n' > "$_PD/old/System/bin/del.sh"
	printf '#!/bin/sh\nadd\n' > "$_PD/new/System/bin/add.sh"
	printf 'old' > "$_PD/old/System/bin/cfg.txt"; printf 'new' > "$_PD/new/System/bin/cfg.txt"
	sh "$TOOLS/make-ota-manifest.sh" "$_PD/old" "$_PD/old.txt" "$_PD/dest" >/dev/null 2>&1
	sh "$TOOLS/make-ota-manifest.sh" "$_PD/new" "$_PD/new.txt" "$_PD/dest" >/dev/null 2>&1
	if command -v zip >/dev/null 2>&1 || command -v 7zz >/dev/null 2>&1; then
		if sh "$PATCHGEN" "$_PD/old.txt" "$_PD/new.txt" "$_PD/new" "$_PD/out" >/dev/null 2>&1; then
			grep -q "install${TAB}System/bin/add.sh" "$_PD/out/manifest.txt" && ok "patch installs added file" || bad "patch missing install add.sh"
			grep -q "replace${TAB}System/bin/cfg.txt" "$_PD/out/manifest.txt" && ok "patch replaces changed file" || bad "patch missing replace cfg.txt"
			grep -q "remove${TAB}.*System/bin/del.sh" "$_PD/out/manifest.txt" && ok "patch removes deleted file" || bad "patch missing remove del.sh"
			! grep -q 'keep.sh' "$_PD/out/manifest.txt" && ok "patch skips unchanged file" || bad "patch leaked unchanged keep.sh"
			[ -s "$_PD/out/patch.zip" ] && ok "patch zip created" || bad "patch zip missing"
		else
			bad "make-ota-patch.sh failed"
		fi
	else
		ok "incremental patch generator skipped (zip/7zz unavailable)"
	fi
	rm -rf "$_PD"
else
	bad "missing $PATCHGEN"
fi
unset _PD PATCHGEN

# ---- 10c. Python installer asset selection ----
echo "--- python installer ---"
PYSCRIPT="$TOOLS/jukamix-python.sh"
if [ -f "$PYSCRIPT" ]; then
	_JSON='{"assets":[{"name":"cpython-3.10.21+20260814-aarch64-unknown-linux-gnu-install_only_stripped.tar.gz"},{"name":"cpython-3.14.0+20260814-aarch64-unknown-linux-gnu-install_only_stripped.tar.gz"},{"name":"cpython-3.12.9+20260814-aarch64-apple-darwin-install_only_stripped.tar.gz"},{"name":"cpython-3.14.0+20260814-aarch64-unknown-linux-musl-install_only_stripped.tar.gz"}]}'
	_A=$(sh -c ". '$PYSCRIPT'; jukamix_python_latest_asset '$_JSON'")
	if [ "$_A" = "cpython-3.14.0+20260814-aarch64-unknown-linux-gnu-install_only_stripped.tar.gz" ]; then
		ok "python installer picks newest gnu asset"
	else
		bad "python installer asset = [$_A]"
	fi
else
	bad "missing $PYSCRIPT"
fi
unset _JSON _A PYSCRIPT

# ---- 11. Diagnostics: value redaction, report id, doctor export ----
echo "--- diagnostics / report export ---"
if . "$TOOLS/lib/jukamix-common.sh" 2>/dev/null; then
	_red=$(printf 'psk="topsecret"\npassword=hunter2\nname=ok\n' | jukamix_redact_values)
	case "$_red" in
		*topsecret*) bad "redact leaked psk" ;;
		*hunter2*)   bad "redact leaked password" ;;
	esac
	echo "$_red" | grep -q 'psk=REDACTED'       && ok "redact masks psk"       || bad "redact missing psk"
	echo "$_red" | grep -q 'password=REDACTED'  && ok "redact masks password" || bad "redact missing password"
	echo "$_red" | grep -q 'name=ok'            && ok "redact keeps safe lines"|| bad "redact removed safe line"
	_rid=$(jukamix_report_id)
	[ -n "$_rid" ] && ok "report id generated ($_rid)" || bad "report id empty"

	_DX="$JUKAMIX_TMPBASE/jukamix-diag-test-$$"
	rm -rf "$_DX"; mkdir -p "$_DX/sup" "$_DX/System"
	printf 'user password=letmein\nwifi psk="s3cr3t"\nnormal line\n' > "$_DX/sup/test.log"
	export JUKAMIX_ROOT="$_DX" JUKAMIX_SYSTEM="$_DX/System" JUKAMIX_SUPPORT="$_DX/sup" JUKAMIX_LOGDIR="$_DX/logs"
	_DREP="$_DX/report.txt"
	# doctor exits non-zero when warnings/errors are present; the report is still
	# written, so assert on the file rather than the exit code.
	sh "$TOOLS/jukamix-doctor.sh" --output "$_DREP" >/dev/null 2>&1
	if [ -f "$_DREP" ]; then
		grep -q 'REPORT_ID:' "$_DREP" && ok "doctor report has REPORT_ID" || bad "doctor missing REPORT_ID"
		grep -q 'REDACTED'     "$_DREP" && ok "doctor redacts secrets in logs" || bad "doctor did not redact logs"
		grep -q 'letmein'      "$_DREP" && bad "doctor leaked password" || ok "doctor does not leak password"
		grep -q 's3cr3t'       "$_DREP" && bad "doctor leaked psk" || ok "doctor does not leak psk"
	else
		bad "jukamix-doctor.sh failed to produce report"
	fi
	rm -rf "$_DX"
	unset JUKAMIX_ROOT JUKAMIX_SYSTEM JUKAMIX_SUPPORT JUKAMIX_LOGDIR
else
	bad "could not source common lib"
fi
unset _red _rid _DX _DREP

# ---- 12. Device profiles + package compatibility gate ----
echo "--- device profiles ---"
if . "$TOOLS/lib/jukamix-common.sh" 2>/dev/null && . "$TOOLS/lib/jukamix-profile.sh" 2>/dev/null; then
	_tsp=$(jukamix_profile_defaults tsp)
	_brick=$(jukamix_profile_defaults brick)
	echo "$_tsp"   | grep -q 'perf_profile=balanced'      && ok "tsp default perf balanced"      || bad "tsp perf wrong"
	echo "$_brick" | grep -q 'perf_profile=battery-saver' && ok "brick default perf battery-saver" || bad "brick perf wrong"
	echo "$_brick" | grep -q 'led=off'                    && ok "brick led off"                  || bad "brick led wrong"

	# package compatibility gate
	JUKAMIX_DEVICE_FORCE=tg5050
	jukamix_package_supported "tsp,tg5050"  >/dev/null 2>&1 && ok "supported when device listed" || bad "wrongly rejected listed device"
	! jukamix_package_supported "tsp"       >/dev/null 2>&1 && ok "rejected when device absent"  || bad "wrongly allowed absent device"
	JUKAMIX_DEVICE_FORCE=brick
	jukamix_package_supported "tsp,tg5050"  >/dev/null 2>&1 && bad "wrongly allowed wrong device" || ok "rejected wrong device"
	JUKAMIX_DEVICE_FORCE=tsp
	jukamix_package_supported "any"         >/dev/null 2>&1 && ok "any is universally supported" || bad "any rejected"
	jukamix_package_supported ""            >/dev/null 2>&1 && ok "empty devices = supported"    || bad "empty rejected"
	unset JUKAMIX_DEVICE_FORCE
else
	bad "could not source profile lib"
fi
unset _tsp _brick

echo
echo "=== summary: pass=$PASS fail=$FAIL ==="
if [ "$FAIL" -gt 0 ]; then
	exit 1
fi
exit 0
