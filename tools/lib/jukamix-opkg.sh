#!/bin/sh
# JukaMix OS - built-in, opkg-compatible package client.
#
# A dependency-light package manager for JukaMix packages. It speaks the same
# formats as opkg/Entware so one feed serves both:
#   * Packages / Packages.gz     package index (Package/Version/Filename/...)
#   * <name>_<version>_<arch>.ipk  gzip tarball: debian-binary, control.tar.gz,
#                                  data.tar.gz, optional pre/post scripts
#
# Packages install under $JUKAMIX_OPKG_ROOT (default /mnt/SDCARD) so the
# read-only internal firmware is never touched. Installed files are tracked in
# $JUKAMIX_OPKG_STATE so they can be removed/upgraded later.
#
# Commands:
#   jukamix_opkg_update                  fetch the package index
#   jukamix_opkg_list                    list available packages
#   jukamix_opkg_list_installed          list installed packages
#   jukamix_opkg_info <name>             show package metadata
#   jukamix_opkg_files <name>            list files owned by an installed package
#   jukamix_opkg_install <name...>       install (resolves dependencies)
#   jukamix_opkg_remove <name...>        uninstall
#   jukamix_opkg_upgrade                 upgrade installed packages
#
# Source this file; do not exec it. Requires a POSIX sh + tar/gunzip (busybox).

if [ "${0##*/}" = "jukamix-opkg.sh" ]; then
	cat >&2 <<'NOTE'
jukamix-opkg.sh is a library. Use the jm-opkg wrapper instead:
  jm-opkg update && jm-opkg install <name>
NOTE
	exit 0
fi

JUKAMIX_OPKG_ROOT="${JUKAMIX_OPKG_ROOT:-${JUKAMIX_ROOT:-/mnt/SDCARD}}"
JUKAMIX_OPKG_STATE="${JUKAMIX_OPKG_STATE:-$JUKAMIX_OPKG_ROOT/System/var/jukamix/opkg}"
JUKAMIX_OPKG_ARCH="${JUKAMIX_OPKG_ARCH:-$(uname -m 2>/dev/null)}"
[ -n "$JUKAMIX_OPKG_ARCH" ] || JUKAMIX_OPKG_ARCH="aarch64"

# Locate the shipped busybox binary (fallback for tar/gunzip/sha256sum when
# the stock firmware doesn't provide those applets).
jukamix_opkg_busybox() {
	_bb=$(command -v busybox 2>/dev/null)
	[ -n "$_bb" ] || {
		for _p in /mnt/SDCARD/System/usr/trimui/scripts/busybox /mnt/SDCARD/System/bin/busybox; do
			[ -e "$_p" ] && { _bb=$_p; break; }
		done
	}
	printf '%s' "$_bb"
}

# tar wrapper: prefer a real tar, otherwise busybox tar.
jukamix_opkg_tar() {
	if command -v tar >/dev/null 2>&1; then
		tar "$@"
	else
		_bb=$(jukamix_opkg_busybox)
		[ -n "$_bb" ] && "$_bb" tar "$@"
	fi
}

# gunzip wrapper: prefer a real gunzip, otherwise busybox gunzip.
jukamix_opkg_gunzip() {
	if command -v gunzip >/dev/null 2>&1; then
		gunzip "$@"
	else
		_bb=$(jukamix_opkg_busybox)
		[ -n "$_bb" ] && "$_bb" gunzip "$@"
	fi
}

# sha256 wrapper: real sha256sum, busybox, or openssl. Prints hex digest only.
jukamix_opkg_sha256() {
	if command -v sha256sum >/dev/null 2>&1; then
		sha256sum "$1" 2>/dev/null | awk '{print $1}'
	elif command -v openssl >/dev/null 2>&1; then
		openssl dgst -sha256 "$1" 2>/dev/null | awk '{print $NF}'
	else
		_bb=$(jukamix_opkg_busybox)
		[ -n "$_bb" ] && "$_bb" sha256sum "$1" 2>/dev/null | awk '{print $1}'
	fi
}

jukamix_opkg_log() {
	_level="$1"; shift
	printf 'jm-opkg[%s] %s\n' "$_level" "$*" >&2
	unset _level
}

# Resolve the feed URL from the environment or the shipped opkg.conf.
if [ -z "${JUKAMIX_OPKG_FEED:-}" ]; then
	for _c in "$JUKAMIX_OPKG_ROOT/System/etc/opkg/opkg.conf" "/etc/opkg/opkg.conf"; do
		[ -f "$_c" ] || continue
		JUKAMIX_OPKG_FEED=$(sed -n 's|^[[:space:]]*src/gz[[:space:]][^[:space:]]*[[:space:]]*||p' "$_c" | head -n1)
		[ -n "$JUKAMIX_OPKG_FEED" ] && break
	done
	unset _c
fi

# Fetch a URL (or copy a local path) into a file.
jukamix_opkg_download() {
	_url="$1"; _out="$2"
	rm -f "$_out"
	case "$_url" in
		/*|./*|../*)
			[ -f "$_url" ] && cp "$_url" "$_out" ;;
		*)
			if command -v curl >/dev/null 2>&1; then
				# -f: fail on HTTP errors instead of saving a 404 page as a
				# "successful" download (a missing feed must error, not
				# produce an empty index).
				curl -k -sfL "$_url" -o "$_out" || { rm -f "$_out"; return 1; }
			elif command -v wget >/dev/null 2>&1; then
				wget -q "$_url" -O "$_out" || { rm -f "$_out"; return 1; }
			else
				jukamix_opkg_log ERROR "no downloader available (curl/wget)"
				return 1
			fi
			;;
	esac
	[ -f "$_out" ]
	unset _url _out
}

# Compare dotted versions: returns 0 when $1 > $2.
jukamix_opkg_ver_gt() {
	_a=$(printf '%s' "$1" | tr -d '[:alpha:]-' | awk -F. '{printf("%d%03d%03d%03d", $1+0, $2+0, $3+0, $4+0)}')
	_b=$(printf '%s' "$2" | tr -d '[:alpha:]-' | awk -F. '{printf("%d%03d%03d%03d", $1+0, $2+0, $3+0, $4+0)}')
	[ -n "$_a" ] && [ -n "$_b" ] && [ "$_a" -gt "$_b" ]
	unset _a _b
}

# Emit one package stanza from the index (Package: line through blank line).
jukamix_opkg_stanza() {
	awk -v name="$1" '
		$1 == "Package:" && $2 == name { on = 1; next }
		on && $0 == "" { exit }
		on { print }
	' "${JUKAMIX_OPKG_STATE}/Packages" 2>/dev/null
}

# Emit a single field from a package stanza on stdin.
jukamix_opkg_stanza_field() {
	awk -v k="$1" '
		{
			idx = index($0, ":")
			if (idx == 0) next
			key = substr($0, 1, idx - 1)
			val = substr($0, idx + 1)
			sub(/^[ \t]+/, "", val)
			if (key == k && !done) { print val; done = 1 }
		}
	'
}

# List dependency names from a Depends: value (drops version/alternation).
jukamix_opkg_dep_names() {
	printf '%s\n' "$1" | tr ',' '\n' | sed 's/[|].*//' | \
		sed -E 's/[[:space:]]*\([^)]*\)[[:space:]]*//g' | \
		tr -d '[:space:]' | sed '/^$/d'
}

# Download and refresh the package index into the state dir.
jukamix_opkg_update() {
	mkdir -p "$JUKAMIX_OPKG_STATE" 2>/dev/null
	[ -n "$JUKAMIX_OPKG_FEED" ] || { jukamix_opkg_log ERROR "no package feed configured (set JUKAMIX_OPKG_FEED)"; return 1; }

	if jukamix_opkg_download "$JUKAMIX_OPKG_FEED/Packages.gz" "$JUKAMIX_OPKG_STATE/Packages.gz" \
		&& [ -s "$JUKAMIX_OPKG_STATE/Packages.gz" ]; then
		jukamix_opkg_gunzip -c "$JUKAMIX_OPKG_STATE/Packages.gz" > "$JUKAMIX_OPKG_STATE/Packages" 2>/dev/null \
			|| cp "$JUKAMIX_OPKG_STATE/Packages.gz" "$JUKAMIX_OPKG_STATE/Packages"
		rm -f "$JUKAMIX_OPKG_STATE/Packages.gz"
	elif jukamix_opkg_download "$JUKAMIX_OPKG_FEED/Packages" "$JUKAMIX_OPKG_STATE/Packages"; then
		:
	else
		jukamix_opkg_log ERROR "could not fetch package index from $JUKAMIX_OPKG_FEED"
		return 1
	fi
	[ -s "$JUKAMIX_OPKG_STATE/Packages" ] || { jukamix_opkg_log ERROR "package index is empty"; return 1; }
	jukamix_opkg_log INFO "package index updated ($(grep -c '^Package:' "$JUKAMIX_OPKG_STATE/Packages") packages)"
	return 0
}

# Print available package names (optionally matching a filter).
jukamix_opkg_list() {
	[ -f "$JUKAMIX_OPKG_STATE/Packages" ] || jukamix_opkg_update >/dev/null 2>&1 || return 1
	awk '$1=="Package:"{print $2}' "$JUKAMIX_OPKG_STATE/Packages" | grep -i "${1:-}"
}

# Print installed package names.
jukamix_opkg_list_installed() {
	[ -d "$JUKAMIX_OPKG_STATE/installed" ] || return 0
	for _f in "$JUKAMIX_OPKG_STATE/installed"/*; do
		[ -f "$_f" ] || continue
		printf '%s %s\n' "$(basename "$_f")" "$(awk '$1=="Version:"{print $2; exit}' "$_f")"
	done
	unset _f
}

jukamix_opkg_info() {
	[ -n "${1:-}" ] || { jukamix_opkg_log ERROR "usage: info <name>"; return 2; }
	_st=$(jukamix_opkg_stanza "$1")
	[ -n "$_st" ] || { jukamix_opkg_log ERROR "package not found in index: $1"; return 1; }
	printf 'Package: %s\n%s\n' "$1" "$_st"
	unset _st
}

jukamix_opkg_files() {
	[ -n "${1:-}" ] || { jukamix_opkg_log ERROR "usage: files <name>"; return 2; }
	_f="$JUKAMIX_OPKG_STATE/files/$1"
	[ -f "$_f" ] || { jukamix_opkg_log ERROR "package not installed: $1"; return 1; }
	cat "$_f"
	unset _f
}

# Is a package recorded as installed?
jukamix_opkg_installed() {
	[ -f "$JUKAMIX_OPKG_STATE/installed/$1" ]
}

# Install one already-downloaded .ipk into the root, registering its files.
# $1 = .ipk path. Sets nothing; returns 0 on success.
jukamix_opkg_install_ipk() {
	_ipk="$1"
	_tmp="${JUKAMIX_OPKG_STATE}/tmp.$$"
	rm -rf "$_tmp"; mkdir -p "$_tmp"

	# 1. Unpack the ipk: debian-binary, control.tar.gz, data.tar.gz, scripts.
	jukamix_opkg_tar xzf "$_ipk" -C "$_tmp" 2>/dev/null || { jukamix_opkg_log ERROR "invalid ipk: $1"; rm -rf "$_tmp"; return 1; }
	jukamix_opkg_tar xzf "$_tmp/control.tar.gz" -C "$_tmp" control 2>/dev/null \
		|| { jukamix_opkg_log ERROR "ipk has no control: $1"; rm -rf "$_tmp"; return 1; }

	_pkg=$(awk '$1=="Package:"{print $2; exit}' "$_tmp/control")
	[ -n "$_pkg" ] || { jukamix_opkg_log ERROR "ipk control has no Package"; rm -rf "$_tmp"; return 1; }

	# 2. Reject unsafe payload paths (absolute or escaping with ..).
	if jukamix_opkg_tar tzf "$_tmp/data.tar.gz" 2>/dev/null | grep -E '(^/|(^|/)\.\.(/|$))' >/dev/null; then
		jukamix_opkg_log ERROR "refusing unsafe paths in $1"
		rm -rf "$_tmp"; return 1
	fi

	# 3. Pre-install hook. Maintainer scripts see the install root via
	# IPKG_INSTROOT (opkg convention) and JUKAMIX_OPKG_ROOT.
	[ -f "$_tmp/preinst" ] && IPKG_INSTROOT="$JUKAMIX_OPKG_ROOT" JUKAMIX_OPKG_ROOT="$JUKAMIX_OPKG_ROOT" sh "$_tmp/preinst" install

	# 4. Install payload and record the files it owns.
	_before=$(jukamix_opkg_tar tzf "$_tmp/data.tar.gz" 2>/dev/null | sed 's#^\./##' | grep -v '/$')
	jukamix_opkg_tar xzf "$_tmp/data.tar.gz" -C "$JUKAMIX_OPKG_ROOT" 2>/dev/null \
		|| { jukamix_opkg_log ERROR "extract failed for $1"; rm -rf "$_tmp"; return 1; }

	mkdir -p "$JUKAMIX_OPKG_STATE/files" "$JUKAMIX_OPKG_STATE/installed"
	printf '%s\n' "$_before" > "$JUKAMIX_OPKG_STATE/files/$_pkg"

	# 5. Register metadata (full control stanza).
	cat "$_tmp/control" > "$JUKAMIX_OPKG_STATE/installed/$_pkg"

	# 6. Post-install hook.
	[ -f "$_tmp/postinst" ] && IPKG_INSTROOT="$JUKAMIX_OPKG_ROOT" JUKAMIX_OPKG_ROOT="$JUKAMIX_OPKG_ROOT" sh "$_tmp/postinst" configure

	rm -rf "$_tmp"
	jukamix_opkg_log INFO "installed $_pkg"
	unset _ipk _tmp _pkg _before
	return 0
}

# Install packages by name, resolving dependencies. Accepts multiple names.
jukamix_opkg_install() {
	[ -n "${1:-}" ] || { jukamix_opkg_log ERROR "usage: install <name...>"; return 2; }
	[ -f "$JUKAMIX_OPKG_STATE/Packages" ] || jukamix_opkg_update >/dev/null 2>&1 || return 1

	_rc=0
	for _want in "$@"; do
		jukamix_opkg_install_one "$_want" 0 || _rc=1
	done
	return $_rc
}

# Internal: install a single package by name (depth-limited dependency walk).
jukamix_opkg_install_one() {
	_name="$1"; _depth="${2:-0}"
	[ "$_depth" -gt 8 ] && { jukamix_opkg_log ERROR "dependency depth exceeded at $_name"; return 1; }

	_st=$(jukamix_opkg_stanza "$_name")
	[ -n "$_st" ] || { jukamix_opkg_log ERROR "package not in index: $_name (run update first)"; return 1; }

	_arch=$(printf '%s\n' "$_st" | jukamix_opkg_stanza_field Architecture)
	[ -z "$_arch" ] && _arch="all"
	if [ "$_arch" != "all" ] && [ "$_arch" != "$JUKAMIX_OPKG_ARCH" ]; then
		jukamix_opkg_log ERROR "$_name is for architecture $_arch, this device is $JUKAMIX_OPKG_ARCH"
		return 1
	fi

	_deps=$(printf '%s\n' "$_st" | jukamix_opkg_stanza_field Depends)
	for _d in $(jukamix_opkg_dep_names "$_deps"); do
		jukamix_opkg_installed "$_d" && continue
		# Run the recursive call in a subshell: POSIX sh has no local
		# variables, so an in-shell recursive call would clobber this
		# frame's $_name/$_st/$_deps. A subshell isolates those while the
		# install's on-disk side effects still persist.
		( jukamix_opkg_install_one "$_d" "$((_depth + 1))" ) || return 1
	done

	_ver=$(printf '%s\n' "$_st" | jukamix_opkg_stanza_field Version)
	if jukamix_opkg_installed "$_name"; then
		_old=$(awk '$1=="Version:"{print $2; exit}' "$JUKAMIX_OPKG_STATE/installed/$_name")
		if ! jukamix_opkg_ver_gt "$_ver" "$_old"; then
			jukamix_opkg_log INFO "$_name is already installed (v$_old)"
			return 0
		fi
		jukamix_opkg_log INFO "upgrading $_name v$_old -> v$_ver"
		# Drop the previous version's files so stale paths don't linger.
		while IFS= read -r _f; do
			[ -n "$_f" ] && rm -f "$JUKAMIX_OPKG_ROOT/$_f" 2>/dev/null
		done < "$JUKAMIX_OPKG_STATE/files/$_name"
	fi

	_fn=$(printf '%s\n' "$_st" | jukamix_opkg_stanza_field Filename)
	_sha=$(printf '%s\n' "$_st" | jukamix_opkg_stanza_field SHA256sum)
	[ -n "$_fn" ] || { jukamix_opkg_log ERROR "$_name has no Filename"; return 1; }

	_ipk="${JUKAMIX_OPKG_STATE}/cache/$_fn"
	mkdir -p "${JUKAMIX_OPKG_STATE}/cache"
	if [ ! -f "$_ipk" ]; then
		jukamix_opkg_download "$JUKAMIX_OPKG_FEED/$_fn" "$_ipk" || { jukamix_opkg_log ERROR "download failed: $_fn"; return 1; }
	fi

	if [ -n "$_sha" ]; then
		_got=$(jukamix_opkg_sha256 "$_ipk")
		if [ "$_got" != "$_sha" ]; then
			jukamix_opkg_log ERROR "checksum mismatch for $_fn"
			rm -f "$_ipk"
			return 1
		fi
	fi

	jukamix_opkg_install_ipk "$_ipk" || { rm -f "$_ipk"; return 1; }
	# Record feed metadata so remove/upgrade can locate the cached .ipk.
	{
		printf 'Filename: %s\n' "$_fn"
		[ -n "$_sha" ] && printf 'SHA256sum: %s\n' "$_sha"
	} >> "$JUKAMIX_OPKG_STATE/installed/$_name"
	unset _name _depth _st _arch _deps _d _ver _old _fn _sha _ipk _got
	return 0
}

# Remove installed packages by name.
jukamix_opkg_remove() {
	[ -n "${1:-}" ] || { jukamix_opkg_log ERROR "usage: remove <name...>"; return 2; }
	_rc=0
	for _name in "$@"; do
		if ! jukamix_opkg_installed "$_name"; then
			jukamix_opkg_log WARN "not installed: $_name"
			continue
		fi
		_tmp="${JUKAMIX_OPKG_STATE}/tmp.$$"
		rm -rf "$_tmp"; mkdir -p "$_tmp"
		# Recover prerm/postrm only when the package is still cached.
		_fn=$(awk '$1=="Filename:"{print $2; exit}' "$JUKAMIX_OPKG_STATE/installed/$_name")
		_ipk="${JUKAMIX_OPKG_STATE}/cache/$_fn"
		[ -f "$_ipk" ] && jukamix_opkg_tar xzf "$_ipk" -C "$_tmp" prerm postrm 2>/dev/null
		[ -f "$_tmp/prerm" ] && IPKG_INSTROOT="$JUKAMIX_OPKG_ROOT" JUKAMIX_OPKG_ROOT="$JUKAMIX_OPKG_ROOT" sh "$_tmp/prerm" remove
		while IFS= read -r _f; do
			[ -n "$_f" ] && rm -f "$JUKAMIX_OPKG_ROOT/$_f" 2>/dev/null
		done < "$JUKAMIX_OPKG_STATE/files/$_name"
		[ -f "$_tmp/postrm" ] && IPKG_INSTROOT="$JUKAMIX_OPKG_ROOT" JUKAMIX_OPKG_ROOT="$JUKAMIX_OPKG_ROOT" sh "$_tmp/postrm" remove
		rm -rf "$_tmp"
		rm -f "$JUKAMIX_OPKG_STATE/files/$_name" "$JUKAMIX_OPKG_STATE/installed/$_name"
		jukamix_opkg_log INFO "removed $_name"
	done
	unset _name _tmp _fn _ipk _f
	return "$_rc"
}

# Upgrade every installed package that has a newer version in the index.
jukamix_opkg_upgrade() {
	[ -f "$JUKAMIX_OPKG_STATE/Packages" ] || jukamix_opkg_update >/dev/null 2>&1 || return 1
	_names=$(jukamix_opkg_list_installed | awk '{print $1}')
	[ -n "$_names" ] && jukamix_opkg_install $_names
	unset _names
}
