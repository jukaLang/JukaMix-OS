#!/bin/sh
# JukaMix Control Center - unified controller-friendly interface.
#
# Brings diagnostics, RetroArch profiles, PortMaster tools, backups and
# recovery into ONE menu (no scattered scripts). Two interface modes:
#   simple   - the everyday essentials
#   advanced - full menus (overlay/shader, BIOS, all tools)
#
# Uses the device's shellect selector for controller navigation (no keyboard
# required). Destructive actions always confirm first and back up beforehand.
#
# Usage:
#   launch.sh            Normal start (auto-enters Recovery if Safe Mode armed)
#   launch.sh --recovery Emergency recovery launcher (startup hook entry point)

set -u

# ---- environment ------------------------------------------------------------
JUKAMIX_TOOLS_DIR="${JUKAMIX_TOOLS_DIR:-/mnt/SDCARD/System/jukamix}"
[ -d "$JUKAMIX_TOOLS_DIR" ] || JUKAMIX_TOOLS_DIR="/mnt/SDCARD/tools"
JUKAMIX_LIB_DIR="${JUKAMIX_LIB_DIR:-$JUKAMIX_TOOLS_DIR/lib}"
export PATH="$JUKAMIX_TOOLS_DIR:$JUKAMIX_BIN:$PATH"
export LD_LIBRARY_PATH="$JUKAMIX_LIB:/usr/trimui/lib:${LD_LIBRARY_PATH:-}"

# shellcheck source=lib/jukamix-common.sh
. "$JUKAMIX_LIB_DIR/jukamix-common.sh"
# shellcheck source=lib/jukamix-device.sh
. "$JUKAMIX_LIB_DIR/jukamix-device.sh"
# shellcheck source=lib/jukamix-recovery.sh
. "$JUKAMIX_LIB_DIR/jukamix-recovery.sh"
# shellcheck source=lib/jukamix-update.sh
. "$JUKAMIX_LIB_DIR/jukamix-update.sh"
# shellcheck source=lib/jukamix-ota.sh
. "$JUKAMIX_LIB_DIR/jukamix-ota.sh"
# shellcheck source=lib/jukamix-opkg.sh
. "$JUKAMIX_LIB_DIR/jukamix-opkg.sh"

RECOVERY_ONLY=0
for _a in "$@"; do
	[ "$_a" = "--recovery" ] && RECOVERY_ONLY=1
done
unset _a

# ---- UI helpers --------------------------------------------------------------
cc_select() {
	# $1 title; $2 newline-separated options; echoes the chosen line.
	_title="$1"; _opts="$2"
	if [ -x "$JUKAMIX_SHELLECT" ]; then
		printf '%s\n' "$_opts" | "$JUKAMIX_SHELLECT" -t "$_title" -b "Press A to select" 2>/dev/null
	else
		_i=1
		printf '%s\n' "$_opts" | while IFS= read -r _l; do
			echo "  $_i) $_l"; _i=$((_i+1))
		done
		printf 'Select: ' >&2; read -r _c 2>/dev/null
		printf '%s\n' "$_opts" | sed -n "${_c}p"
	fi
	unset _title _opts _i _l _c
}

cc_info() {
	_t="$1"
	[ -x "$JUKAMIX_INFOSCREEN" ] && "$JUKAMIX_INFOSCREEN" -m "$_t" -t 6 2>/dev/null
	printf '%s\n' "$_t"
	unset _t
}

cc_mode() {
	_m=$(jukamix_state_get cc_mode 2>/dev/null)
	[ -z "$_m" ] && _m="simple"
	printf '%s\n' "$_m"
	unset _m
}

cc_build_menu() {
	if [ "$(cc_mode)" = "advanced" ]; then
		printf '%s\n' \
			"Device Information" "Storage Status" "RetroArch" "PortMaster" \
			"Overlay & Shader" "BIOS Check" "Diagnostics" "Backup" "Recovery" "System Update" "Packages" "JukaHub" "Settings"
	else
		printf '%s\n' \
			"Device Information" "Storage Status" "RetroArch" "PortMaster" \
			"Diagnostics" "Backup" "Recovery" "System Update" "Packages" "JukaHub" "Settings"
	fi
}

# ---- feature handlers --------------------------------------------------------
cc_device_info() {
	jukamix_device_summary | cc_info
}

cc_storage() {
	"$JUKAMIX_TOOLS_DIR/jukamix-storage-doctor.sh" 2>&1 | cc_info
}

cc_retroarch() {
	while true; do
		_s=$(cc_select "RetroArch" "Launch RetroArch\nProfile Inspector\nList Cores\nBack")
		case "$_s" in
			"Launch RetroArch")
				_ra=$(jukamix_have_cmd retroarch && command -v retroarch || echo "$JUKAMIX_BIN/retroarch")
				if [ -x "$_ra" ]; then
					"$JUKAMIX_TOOLS_DIR/jukamix-launch.sh" -- retroarch
				else
					cc_info "RetroArch binary not found on this device."
				fi ;;
			"Profile Inspector"|"List Cores")
				"$JUKAMIX_TOOLS_DIR/jukamix-retroarch-profile.sh" --list 2>&1 | cc_info ;;
			"Back"|"") return 0 ;;
		esac
	done
}

cc_portmaster() {
	while true; do
		_s=$(cc_select "PortMaster" "Preflight Check\nCompatibility Status\nBack")
		case "$_s" in
			"Preflight Check")
				"$JUKAMIX_TOOLS_DIR/jukamix-portmaster-check.sh" 2>&1 | cc_info ;;
			"Compatibility Status")
				jukamix_detect_all 2>/dev/null
				_out=$(jukamix_compat_query "$JUKAMIX_DEVICE" "*" "*" "port/VVVVVV" 2>/dev/null)
				cc_info "PortMaster on $JUKAMIX_DEVICE_NAME:\nVerified status: ${_out:-UNTESTED}\nNot every port is verified for this device." ;;
			"Back"|"") return 0 ;;
		esac
	done
}

cc_diagnostics() {
	while true; do
		_s=$(cc_select "Diagnostics" "Run Diagnostics\nExport Report (GitHub)\nBack")
		case "$_s" in
			"Run Diagnostics")
				"$JUKAMIX_TOOLS_DIR/jukamix-doctor.sh" --no-report 2>&1 | cc_info ;;
			"Export Report (GitHub)")
				_out="$JUKAMIX_SUPPORT/jukamix-diag-export.txt"
				_path=$("$JUKAMIX_TOOLS_DIR/jukamix-doctor.sh" --archive --archive-output "$_out" 2>&1 | tail -n1)
				cc_info "Report exported:\n$_path\nREPORT_ID is inside the file.\nAttach it to your GitHub issue." ;;
			"Back"|"") return 0 ;;
		esac
	done
}

cc_backup() {
	if [ "$(jukamix_confirm 'Create a timestamped backup of config, saves and BIOS?')" = "yes" ]; then
		"$JUKAMIX_TOOLS_DIR/jukamix-backup.sh" --what all 2>&1 | cc_info
	fi
}

cc_overlay_shader() {
	while true; do
		_s=$(cc_select "Overlay & Shader" "Show Current\nReset to JukaMix Default\nBack")
		case "$_s" in
			"Show Current")
				_cfg="$JUKAMIX_RA_HOME/retroarch.cfg"
				if [ -f "$_cfg" ]; then
					_ov=$(grep -i '^input_overlay' "$_cfg" 2>/dev/null | head -n1)
					_sh=$(grep -i '^video_shader' "$_cfg" 2>/dev/null | head -n1)
					cc_info "Overlay: ${_ov:-none}\nShader: ${_sh:-none}"
				else
					cc_info "No RetroArch config found."
				fi ;;
			"Reset to JukaMix Default")
				if [ "$(jukamix_confirm 'Clear overlay and shader overrides? Current config is backed up first.')" = "yes" ]; then
					_cfg="$JUKAMIX_RA_HOME/retroarch.cfg"
					if [ -f "$_cfg" ]; then
						jukamix_backup_file "$_cfg" 2>/dev/null
						sed -i '/^input_overlay/d; /^video_shader/d' "$_cfg" 2>/dev/null
						cc_info "Overlay/shader overrides cleared."
					else
						cc_info "No RetroArch config to reset."
					fi
				fi ;;
			"Back"|"") return 0 ;;
		esac
	done
}

cc_bios() {
	"$JUKAMIX_TOOLS_DIR/jukamix-bios-check.sh" 2>&1 | cc_info
}

cc_update() {
	jukamix_ota_run
}

cc_packages() {
	command -v jukamix_opkg_update >/dev/null 2>&1 || { cc_info "Package manager unavailable on this device."; return 1; }
	while true; do
		_s=$(cc_select "Packages" "Update Package Index\nList Available\nInstall Package\nRemove Package\nUpgrade All\nBack")
		case "$_s" in
			"Update Package Index")
				cc_info "$(jukamix_opkg_update 2>&1)" ;;
			"List Available")
				_out=$(jukamix_opkg_list 2>&1 | head -200)
				cc_info "${_out:-No packages available.}" ;;
			"Install Package")
				_avail=$(jukamix_opkg_list 2>&1)
				[ -n "$_avail" ] || { cc_info "No packages available. Run Update Package Index first."; continue; }
				_pkg=$(cc_select "Install Package" "$_avail")
				[ -n "$_pkg" ] || continue
				if [ "$(jukamix_confirm "Install ${_pkg}?")" = "yes" ]; then
					cc_info "$(jukamix_opkg_install "$_pkg" 2>&1)"
				fi ;;
			"Remove Package")
				_inst=$(jukamix_opkg_list_installed 2>&1 | awk '{print $1}')
				[ -n "$_inst" ] || { cc_info "No packages installed."; continue; }
				_pkg=$(cc_select "Remove Package" "$_inst")
				[ -n "$_pkg" ] || continue
				if [ "$(jukamix_confirm "Remove ${_pkg}?")" = "yes" ]; then
					cc_info "$(jukamix_opkg_remove "$_pkg" 2>&1)"
				fi ;;
			"Upgrade All")
				cc_info "$(jukamix_opkg_upgrade 2>&1)" ;;
			"Back"|"") return 0 ;;
		esac
	done
}

cc_jukahub() {
	_jkt="$JUKAMIX_TOOLS_DIR/jukamix-jukahub.sh"
	[ -f "$_jkt" ] || { cc_info "JukaHub installer not found on this device."; return 1; }
	while true; do
		_s=$(cc_select "JukaHub" "Install or Update\nStatus\nRestore Replaced Apps\nRemove\nBack")
		case "$_s" in
			"Install or Update")
				if [ "$(jukamix_confirm 'Download and install JukaHub? Apps it supersedes are moved to a restorable backup.')" = "yes" ]; then
					cc_info "$(sh "$_jkt" install --replace-apps 2>&1)"
				fi ;;
			"Status")
				cc_info "$(sh "$_jkt" status 2>&1)" ;;
			"Restore Replaced Apps")
				cc_info "$(sh "$_jkt" restore-apps 2>&1)" ;;
			"Remove")
				if [ "$(jukamix_confirm 'Remove JukaHub? It is moved to backups and auto-install is disabled.')" = "yes" ]; then
					cc_info "$(sh "$_jkt" remove 2>&1)"
				fi ;;
			"Back"|"") return 0 ;;
		esac
	done
}

cc_recovery_menu() {
	while true; do
		_s=$(cc_select "Recovery" "Safe Mode Status\nReset to Defaults\nRestore Last Backup\nRepair System Files\nBack")
		case "$_s" in
			"Safe Mode Status")
				_cr=$(jukamix_crash_count)
				if jukamix_safe_mode_active; then _sm="ACTIVE"; else _sm="off"; fi
				cc_info "Crashes since last good boot: $_cr\nSafe Mode: $_sm" ;;
			"Reset to Defaults")     jukamix_reset_defaults ;;
			"Restore Last Backup")   jukamix_restore_last_known_good ;;
			"Repair System Files")   jukamix_repair_owned "" ;;
			"Back"|"") return 0 ;;
		esac
	done
}

cc_settings() {
	while true; do
		_s=$(cc_select "Settings" "Toggle Interface Mode\nAbout\nBack")
		case "$_s" in
			"Toggle Interface Mode")
				if [ "$(cc_mode)" = "simple" ]; then jukamix_state_set cc_mode advanced
				else jukamix_state_set cc_mode simple; fi
				cc_info "Interface mode is now: $(cc_mode)" ;;
			"About")
				cc_info "JukaMix Control Center\nUnifies diagnostics, RetroArch profiles, PortMaster tools, backups and recovery in one controller-friendly interface." ;;
			"Back"|"") return 0 ;;
		esac
	done
}

cc_dispatch() {
	case "$1" in
		"Device Information") cc_device_info ;;
		"Storage Status")     cc_storage ;;
		"RetroArch")          cc_retroarch ;;
		"PortMaster")         cc_portmaster ;;
		"Diagnostics")        cc_diagnostics ;;
		"Backup")             cc_backup ;;
		"Overlay & Shader")   cc_overlay_shader ;;
		"BIOS Check")         cc_bios ;;
		"Recovery")           cc_recovery_menu ;;
		"System Update")      cc_update ;;
		"Packages")           cc_packages ;;
		"JukaHub")            cc_jukahub ;;
		"Settings")           cc_settings ;;
		"")                   return 1 ;;
	esac
}

# ---- main -------------------------------------------------------------------
jukamix_boot_begin

if [ "$RECOVERY_ONLY" = "1" ]; then
	cc_recovery_menu
	jukamix_boot_ok
	exit 0
fi

if jukamix_safe_mode_active; then
	cc_info "Safe Mode: repeated crashes detected. Opening Recovery."
	cc_recovery_menu
fi

while true; do
	_sel=$(cc_select "JukaMix Control Center" "$(cc_build_menu)")
	[ -z "$_sel" ] && break
	cc_dispatch "$_sel" || break
done

jukamix_boot_ok
exit 0
