# Installation Guide

## Quick Start

1. **Format** your microSD card as **FAT32** (single partition)
2. **Download** the latest `JukaMix_<stamp>.zip` from [Releases](https://github.com/jukaLang/JukaMix-OS/releases/latest)
3. **Extract** to the card root (so `Apps/`, `Emus/`, `Roms/`, `System/` sit at the top level)
4. **Insert** the card and power on — first boot takes a few minutes

## Supported Devices

| Device | Code | SoC | Display | Notes |
|--------|------|-----|---------|-------|
| TrimUI Smart Pro | `tsp` | Allwinner A133 Plus | 1280×720 (16:9) | Dual analog sticks |
| TrimUI Smart Pro S | `tg5050` | Allwinner A523 | 1280×720 (16:9) | Fastest SoC |
| TrimUI Brick | `brick` | Allwinner A133 Plus | 1024×768 (4:3, touch) | Vertical, no analog |
| TrimUI Brick Pro | `brick_pro` | Allwinner A133 Plus | 1280×720 (16:9) | Same as TSP |

One image works on **all devices** — the OS auto-detects and tunes itself.

## How the rootfs Works

JukaMix OS uses **Buildroot** to create minimal Linux root filesystem images (`rootfs*.ext2`). These are separate from the SD card contents:

### Build Process

```
build-rootfs.sh
  ├── TG5050 (Full Tier): rootfs-tg5050.ext2 (1GB)
  │   └── Includes: QT6, Wayland, Mesa3D, Python, Node.js
  └── TSP/Brick (Minimal): rootfs-tsp-brick.ext2 (512MB)
      └── Includes: Python, Node.js (no QT6/Wayland)
```

### CI/CD Integration

The GitHub Actions workflow downloads **pre-built** rootfs images from:
- `https://github.com/jukaLang/JukaMix-OS/releases/download/BuildRootFS/rootfs-tg5050.ext2`
- `https://github.com/jukaLang/JukaMix-OS/releases/download/BuildRootFS/rootfs-tsp-brick.ext2`

These are uploaded separately from the release zip and are used for chroot development (not shipped in the user-facing SD card image).

### On-Device Usage

The rootfs enables **chroot** environments for running Linux software:
```bash
# Mount the rootfs
sudo mount -o loop rootfs-tg5050.ext2 /mnt/buildroot

# Chroot into it
sudo chroot /mnt/buildroot /bin/bash
```

This is used by the `JukaMix Buildroot` app for development and debugging.

## Package System (.ipk)

JukaMix uses an **opkg-compatible** package system for installing apps and updates:

### What are .ipk files?

`.ipk` files are gzip tarballs (Debian/Entware format) containing:
- `debian-binary` — format version
- `control.tar.gz` — package metadata
- `data.tar.gz` — files to install

Example: `hello_1.2.3_aarch64.ipk` installs a "hello" package.

### Installing Packages

```bash
# Update package list
jm-opkg update

# Install a package
jm-opkg install <package-name>

# List installed packages
jm-opkg list-installed

# Remove a package
jm-opkg remove <package-name>
```

### Building Your Own Package

```bash
# Package structure
packages/myapp/
  control          # Metadata (Package, Version, Architecture, Description)
  data/            # Files to install (relative to /mnt/SDCARD)
    usr/bin/myapp  # Installed as /mnt/SDCARD/usr/bin/myapp
  postinst         # Optional: runs after install

# Build the package
sh tools/jukamix-mkpackage.sh packages/myapp dist/feed aarch64

# Build the feed index
sh tools/jukamix-mkfeed.sh dist/feed
```

### Publishing Packages

The CI workflow automatically:
1. Builds all packages in `packages/`
2. Creates a feed index (`Packages`/`Packages.gz`)
3. Uploads everything to the GitHub release

On-device, `jm-opkg` reads from `releases/latest/download` to always get the newest packages.

## First Boot Setup

1. **Firmware Check** — If your TrimUI firmware is too old, a wizard runs automatically
2. **Device Detection** — The OS identifies your device and applies correct settings
3. **Default Theme** — JukaMix OS theme is applied
4. **PortMaster Setup** — Self-heals if broken

## Adding Content

### ROMs
Place ROM files in `Roms/<SYSTEM>/`:
```
Roms/
  GBA/          # Game Boy Advance
  N64/          # Nintendo 64
  PS/           # PlayStation
  DC/           # Dreamcast
  ...
```

### BIOS Files
Place BIOS files in `BIOS/`:
```
BIOS/
  scph1001.bin  # PlayStation
  dc_boot.bin   # Dreamcast
  ...
```

### Themes
Drop theme `.7z` files into `Themes/`:
```
Themes/
  MyTheme.7z
```

## Updating

### Over Wi-Fi
1. Open **Apps → JukaMix Control Center → System Update**
2. Confirm download
3. Updates apply transactionally (auto-rollback on failure)

### Offline
1. Download `JukaMix_<stamp>.zip` on any computer
2. Copy to SD card root
3. Open **Apps → System Update**

## Troubleshooting

### Stock Launcher Appears
- Ensure SD card is selected as boot source in device Settings
- Brick boots from SD automatically

### Games Not Showing
- Verify ROMs are in the correct `Roms/<SYSTEM>/` folder
- Check file extensions match the system's `extlist` in `config.json`

### Performance Issues
- Check per-game profiles in `Profiles/<system>/<game>.cfg`
- Use the Key Remapper app to customize controls
- Verify CPU governor is set correctly for your device

## Building from Source

### Requirements
- Linux (Ubuntu 22.04+)
- build-essential, libncurses-dev, python3, git, wget, curl
- ~10GB free disk space

### Build Rootfs
```bash
# Build all devices
./build-rootfs.sh

# Build specific device
./build-rootfs.sh tg5050   # Smart Pro S only
./build-rootfs.sh tsp      # TSP/Brick/Brick Pro only
```

### Build Release
```bash
# Full release build
scripts/build_release.sh

# With specific version stamp
scripts/build_release.sh 0820202614
```
