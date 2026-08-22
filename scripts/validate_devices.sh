#!/bin/sh
# JukaMix OS - release device validation.
#
# Verifies a built (or staged) JukaMix OS tree ships everything the flagship
# devices need, and that the on-device detection/capability layers resolve each
# device correctly. It runs against the repo root or a staged release directory
# and optionally cross-checks the generated OTA manifest.txt.
#
# Usage:
#   validate_devices.sh [ROOT] [--devices "tsp tg5050"] \
#       [--version X.Y.Z] [--manifest /path/to/manifest.txt]
#
# Exits non-zero if any check fails, so it can gate a release build or CI job.

set -u

usage() {
	cat <<'EOF'
Usage: validate_devices.sh [ROOT] [options]

Validates a JukaMix OS tree against every requested device.

Options:
  --devices "tsp tg5050 brick"  Devices to validate (default: tsp tg5050 brick)
  --version X.Y.Z               Expected version stamp (optional)
  --manifest PATH               OTA manifest.txt to cross-check (optional)
  -h, --help                    Show this help
EOF
}

ROOT=""
DEVICES="tsp tg5050 brick"
VERSION=""
MANIFEST=""

while [ "$#" -gt 0 ]; do
	case "$1" in
		-h|--help) usage; exit 0 ;;
		--devices)
			[ "$#" -ge 2 ] || { echo "missing value for --devices" >&2; exit 2; }
			DEVICES="$2"; shift 2 ;;
		--version)
			[ "$#" -ge 2 ] || { echo "missing value for --version" >&2; exit 2; }
			VERSION="$2"; shift 2 ;;
		--manifest)
			[ "$#" -ge 2 ] || { echo "missing value for --manifest" >&2; exit 2; }
			MANIFEST="$2"; shift 2 ;;
		-*) echo "unknown option: $1" >&2; exit 2 ;;
		*) ROOT="$1"; shift ;;
	esac
done

ROOT="${ROOT:-.}"
[ -d "$ROOT" ] || { echo "release root not found: $ROOT" >&2; exit 2; }
ROOT=$(CDPATH= cd -- "$ROOT" && pwd)

TAB=$(printf '\t')
PASS=0
FAIL=0

ok()  { PASS=$((PASS+1)); printf '[PASS] %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '[FAIL] %s\n' "$1"; }

# Device-specific files that MUST be present for each device. The combined
# archive ships all of these; detection picks the right ones at boot.
device_files() {
	case "$1" in
		tsp)
			printf '%s\n' \
				"System/resources/tsp_inputd" \
				"System/usr/trimui/scripts/tsp_cpufreq.sh" \
				"Profiles/DEVICE-OVERRIDES/tsp_base.cfg"
			;;
		tg5050)
			# The Smart Pro S (A523) uses its stock firmware input daemon
			# (/usr/trimui/bin/trimui_inputd) rather than a shipped resource
			# binary — the TSP (A133) daemon does not map its gamepad.
			printf '%s\n' \
				"System/usr/trimui/scripts/tg5050_cpufreq.sh" \
				"System/usr/trimui/scripts/tg5050_thermal_manager.sh" \
				"Profiles/DEVICE-OVERRIDES/tg5050_base.cfg" \
				"RetroArch/.retroarch/autoconfig/TrimUI-Smart-Pro-S-tg5050.cfg"
			;;
		brick)
			# The Brick reuses the Smart Pro input daemon selection path (it
			# copies the stock /usr/trimui/bin/trimui_inputd instead) and the
			# shared tsp cpufreq ladder (same A133 Plus SoC, see
			# apply_game_profile.sh), so only the base profile is Brick-specific.
			printf '%s\n' \
				"Profiles/DEVICE-OVERRIDES/brick_base.cfg" \
				"System/usr/trimui/scripts/tsp_cpufreq.sh"
			;;
		brick_pro)
			# Brick Pro uses the same A133 Plus SoC as TSP; it reuses the TSP
			# inputd and cpufreq ladder. Only the base profile is Brick Pro-specific.
			printf '%s\n' \
				"Profiles/DEVICE-OVERRIDES/brick_pro_base.cfg" \
				"System/usr/trimui/scripts/tsp_cpufreq.sh"
			;;
	esac
}

# Files shared by every supported device (detection glue + capability data).
common_files() {
	printf '%s\n' \
		"System/usr/trimui/scripts/device_detection.sh" \
		"System/usr/trimui/scripts/inputd_resolve.sh" \
		"System/usr/trimui/scripts/inputd_switcher.sh" \
		"System/usr/trimui/scripts/common_launcher.sh" \
		"System/usr/trimui/scripts/cpufreq_default.sh" \
		"System/usr/trimui/scripts/apply_game_profile.sh" \
		"System/usr/trimui/scripts/Duplicate Finder.py" \
		"System/usr/trimui/scripts/ROM Archive Tester.py" \
		"System/usr/trimui/scripts/Boxart Optimizer.py" \
		"Apps/SystemTools/Menu/TOOLS/Find Duplicate Roms.sh" \
		"Apps/SystemTools/Menu/TOOLS/Test ROM Archives.sh" \
		"Apps/SystemTools/Menu/TOOLS/Optimize Boxart Images.sh" \
		"System/bin/jm-glibc" \
		"System/lib/glibc/ld-linux-aarch64.so.1" \
		"System/lib/glibc/libc.so.6" \
		"System/lib/glibc/libm.so.6" \
		"tools/lib/jukamix-common.sh" \
		"tools/lib/jukamix-device.sh" \
		"tools/data/compatibility-db.txt" \
		"tools/data/device-capabilities.txt"
}

require_file() {
	_d="$1"; _r="$2"
	if [ -f "$ROOT/$_r" ]; then ok "$_d: $_r"; else bad "$_d: missing $_r"; fi
}

TMPF="${TMPDIR:-/tmp}/jukamix-validate-devices.$$"
trap 'rm -f "$TMPF"' EXIT INT TERM

# ---- common files -----------------------------------------------------------
common_files > "$TMPF"
while IFS= read -r _rel; do
	[ -n "$_rel" ] || continue
	require_file common "$_rel"
done < "$TMPF"

# ---- version stamp ----------------------------------------------------------
if [ -n "$VERSION" ]; then
	_vf="$ROOT/System/usr/trimui/jukamix-version.txt"
	if [ -f "$_vf" ]; then
		_got=$(tr -d '[:space:]' < "$_vf")
		if [ "$_got" = "$VERSION" ]; then ok "version stamp: $VERSION"; else bad "version stamp: got [$_got] want [$VERSION]"; fi
	else
		bad "version stamp missing: System/usr/trimui/jukamix-version.txt"
	fi
fi

# ---- per-device checks ------------------------------------------------------
for _dev in $DEVICES; do
	case "$_dev" in
		tsp|tg5050|brick|brick_pro) ;;
		*) bad "unsupported device: $_dev"; continue ;;
	esac

	printf '%s\n' "--- device: $_dev ---"

	device_files "$_dev" > "$TMPF"
	while IFS= read -r _rel; do
		[ -n "$_rel" ] || continue
		require_file "$_dev" "$_rel"
	done < "$TMPF"

	# The standalone detection script must map the device code to the right profile.
	case "$_dev" in
		tsp)        _profile=trimui-smart-pro ;;
		tg5050)     _profile=trimui-smart-pro-s ;;
		brick)      _profile=trimui-brick ;;
		brick_pro)  _profile=trimui-brick-pro ;;
	esac
	# scripts/detect_device.sh is host-side scaffolding, excluded from the
	# release image; validate it when present (repo/CI runs), otherwise the
	# capability checks below are the authoritative device mapping.
	if [ -f "$ROOT/scripts/detect_device.sh" ]; then
		_det=$(JUKAMIX_DEVICE_FORCE="$_dev" sh "$ROOT/scripts/detect_device.sh" 2>/dev/null)
		printf '%s\n' "$_det" | grep -q "^device_code=$_dev\$" \
			&& ok "$_dev: detect_device code" \
			|| bad "$_dev: detect_device code wrong: [$(printf '%s' "$_det" | tr '\n' ' ')]"
		printf '%s\n' "$_det" | grep -q "^device_profile=$_profile\$" \
			&& ok "$_dev: detect_device profile" \
			|| bad "$_dev: detect_device profile wrong: [$(printf '%s' "$_det" | tr '\n' ' ')]"
	else
		printf '[skip] %s: scripts/detect_device.sh not in image (host-side only)\n' "$_dev"
	fi

	# The capability layer must resolve each device to its real hardware:
	# tsp/tg5050 are horizontal 720p with analog sticks and rumble; the brick
	# is a vertical 4:3 touchscreen with no analog sticks or rumble.
	_cap_list="horizontal_display analog_sticks rumble opengl stereo_audio"
	case "$_dev" in
		tsp|tg5050|brick_pro)
			_cap_exp="horizontal_display:SUPPORTED analog_sticks:SUPPORTED rumble:SUPPORTED opengl:SUPPORTED stereo_audio:SUPPORTED"
			;;
		brick)
			_cap_list="horizontal_display vertical_display analog_sticks rumble touchscreen opengl stereo_audio"
			_cap_exp="horizontal_display:INCOMPATIBLE vertical_display:SUPPORTED analog_sticks:UNTESTED rumble:UNTESTED touchscreen:SUPPORTED opengl:SUPPORTED stereo_audio:SUPPORTED"
			;;
	esac
	if [ -f "$ROOT/tools/lib/jukamix-device.sh" ]; then
		_caps=$(
			JUKAMIX_ROOT="$ROOT" \
			JUKAMIX_LIB_DIR="$ROOT/tools/lib" \
			JUKAMIX_TOOLS_DIR="$ROOT/tools" \
			JUKAMIX_DEVICE_DB="$ROOT/tools/data/compatibility-db.txt" \
			JUKAMIX_DEVICE_FORCE="$_dev" \
			sh -c '
				. "$JUKAMIX_LIB_DIR/jukamix-device.sh"
				for c in '"$_cap_list"'; do
					printf "%s=%s\n" "$c" "$(jukamix_capability "$c")"
				done
			'
		)
		for _cap in $_cap_exp; do
			_name=${_cap%%:*}; _exp=${_cap#*:}
			_got=$(printf '%s\n' "$_caps" | sed -n "s/^${_name}=//p")
			if [ "$_got" = "$_exp" ]; then ok "$_dev: capability $_name=$_got"; else bad "$_dev: capability $_name=[$_got] want $_exp"; fi
		done
	else
		bad "$_dev: missing tools/lib/jukamix-device.sh"
	fi

	# Device rows in the capability/compatibility data files.
	if grep -q "^$_dev|" "$ROOT/tools/data/device-capabilities.txt" 2>/dev/null; then
		ok "$_dev: device-capabilities.txt row"
	else
		bad "$_dev: missing row in tools/data/device-capabilities.txt"
	fi
	if grep -q "^$_dev|" "$ROOT/tools/data/compatibility-db.txt" 2>/dev/null; then
		ok "$_dev: compatibility-db.txt row"
	else
		bad "$_dev: missing row in tools/data/compatibility-db.txt"
	fi
done

# ---- OTA manifest -----------------------------------------------------------
if [ -n "$MANIFEST" ]; then
	printf '%s\n' "--- OTA manifest ---"
	if [ ! -f "$MANIFEST" ]; then
		bad "manifest not found: $MANIFEST"
	else
		{
			common_files
			for _dev in $DEVICES; do device_files "$_dev"; done
		} > "$TMPF"
		while IFS= read -r _rel; do
			[ -n "$_rel" ] || continue
			if grep -F "install${TAB}${_rel}${TAB}" "$MANIFEST" >/dev/null 2>&1; then
				ok "manifest: $_rel"
			else
				bad "manifest missing: $_rel"
			fi
		done < "$TMPF"
	fi
fi

# ---- summary ----------------------------------------------------------------
printf '\n'
printf 'device validation: pass=%d fail=%d (devices: %s)\n' "$PASS" "$FAIL" "$DEVICES"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
