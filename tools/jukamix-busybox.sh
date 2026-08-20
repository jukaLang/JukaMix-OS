#!/bin/sh
# JukaMix OS - busybox applet installer.
#
# The SD card ships a full busybox 1.36.1 binary (aarch64) but no applet
# links, so `tar`, `gunzip`, `sha256sum`, `crond`, `httpd`, ... are missing
# unless the stock rootfs happens to provide them. This script symlinks the
# useful applets into System/bin (which is first on PATH) so every JukaMix
# script can rely on them regardless of firmware.
#
# It is idempotent and never overwrites an existing System/bin entry, so the
# real wget/curl/jq binaries keep winning.
#
# Usage:
#   jukamix-busybox.sh --list                 show the applets it would install
#   jukamix-busybox.sh --install              install the applet links
#   jukamix-busybox.sh --install --root DIR   install for a staged tree

set -u

ROOT="${JUKAMIX_ROOT:-/mnt/SDCARD}"
BIN="$ROOT/System/bin"
BB="$ROOT/System/usr/trimui/scripts/busybox"
[ -f "$BB" ] || BB="$ROOT/System/bin/busybox"

# Curated applets used across the OS (file/archive, text, system, network).
APPLETS='tar gzip gunzip zcat unzip sha256sum sha512sum md5sum cmp dd sync stat realpath readlink basename dirname wc head tail cut tr sort uniq sed awk grep find xargs ps top kill killall free df du uptime mount umount sleep date uname hostname mktemp chmod chown ln mkdir rm mv cp cat echo printf sh ash vi less more httpd ntpd ping nslookup nc crond hwclock dmesg hexdump strings xargs rev'

case "${1:-}" in
	--list)
		printf '%s\n' $APPLETS
		;;
	--install)
		shift
		while [ "$#" -gt 0 ]; do
			case "$1" in
				--root) ROOT="$2"; shift 2 ;;
				*) break ;;
			esac
		done
		BIN="$ROOT/System/bin"
		BB="$ROOT/System/usr/trimui/scripts/busybox"
		[ -f "$BB" ] || BB="$ROOT/System/bin/busybox"
		[ -f "$BB" ] || { echo "busybox binary not found: $BB" >&2; exit 1; }
		[ -d "$BIN" ] || { echo "System/bin not found: $BIN" >&2; exit 1; }
		# Link the binary itself into System/bin for discoverability.
		[ -e "$BIN/busybox" ] || ln -s "$BB" "$BIN/busybox" 2>/dev/null
		_n=0
		for _a in $APPLETS; do
			[ -e "$BIN/$_a" ] && continue
			if ln -s busybox "$BIN/$_a" 2>/dev/null; then
				_n=$((_n + 1))
			fi
		done
		echo "installed $_n busybox applet link(s) in $BIN"
		unset _a _n
		;;
	-h|--help)
		sed -n '2,18p' "$0"; exit 0 ;;
	*)
		echo "usage: $0 [--list|--install] [--root DIR]" >&2
		exit 2
		;;
esac
