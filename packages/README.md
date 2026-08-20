# JukaMix Packages

JukaMix OS ships an opkg-compatible package channel so users can install and
update system components (apps, emulators, tools, libraries) without flashing
a full OS image.

## Package layout

Each package is a directory with a Debian-style `control` file and a `data/`
tree of files to install:

```
packages/
  hello/
    control          # metadata (Package, Version, Architecture, Depends, ...)
    data/
      usr/bin/hello  # installed relative to /mnt/SDCARD
    postinst         # optional: runs after install
```

`control` is a standard opkg control file (`Depends` is optional and can be
omitted when a package has no dependencies):

```
Package: hello
Version: 1.2.3
Architecture: aarch64
Depends: libc, busybox (>= 1.36)
Description: Prints hello
```

Maintainer scripts (`preinst`/`postinst`/`prerm`/`postrm`) receive the package
destination root as `IPKG_INSTROOT` (opkg convention) and `JUKAMIX_OPKG_ROOT`.
Use `postinst` to restore executable bits: the SD card is FAT/exFAT, so a
Windows or archive checkout loses `chmod +x` on scripts and binaries.

## Building

Build a single package and the feed index on any machine with `tar` + `gzip`:

```sh
sh tools/jukamix-mkpackage.sh packages/hello dist/feed aarch64
sh tools/jukamix-mkfeed.sh    dist/feed
```

This produces `hello_1.2.3_aarch64.ipk` plus a `Packages`/`Packages.gz` index
with SHA256 checksums. The `.ipk` is a gzip tarball containing
`debian-binary`, `control.tar.gz`, `data.tar.gz` and any `preinst`/`postinst`/
`prerm`/`postrm` scripts (the Entware/opkg layout).

## Publishing

The release workflow (`.github/workflows/JukaMix-OS Release.yml`) builds every
package in `packages/` and uploads the feed — the `*.ipk` files plus
`Packages`/`Packages.gz` — to each GitHub release. The on-device
`System/etc/opkg/opkg.conf` points at the stable
`releases/latest/download` URL, so `jm-opkg` always resolves the newest feed
with no per-build stamping. Locally, `scripts/build_release.sh` also produces
`dist/feed/` for manual publishing to any static host.

The device then installs with `jm-opkg` (the CLI wrapper in `bin/`, on `PATH`
via `/mnt/SDCARD/bin`; the JukaMix Control Center also manages packages
directly):

```sh
jm-opkg update
jm-opkg install hello
jm-opkg list-installed
```

## On-device install target

Packages install under `/mnt/SDCARD` (configured as `dest sd` in
`opkg.conf`), so the read-only internal firmware is never touched. Installed
files and package metadata are tracked under
`/mnt/SDCARD/System/var/jukamix/opkg/` for later `remove`/`upgrade`.
