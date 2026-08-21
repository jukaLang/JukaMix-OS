# Installation Guide

## Quick Start (TL;DR)

1. **Format** your microSD card as **FAT32** (single partition)
2. **Download** the latest `JukaMix_<stamp>.zip` from [Releases](https://github.com/jukaLang/JukaMix-OS/releases/latest)
3. **Extract** to the card root (so `Apps/`, `Emus/`, `Roms/`, `System/` sit at the top level)
4. **Insert** the card and power on — first boot takes a few minutes

---

## Supported Devices

| Device | Code | SoC | Display | Notes |
|--------|------|-----|---------|-------|
| TrimUI Smart Pro | `tsp` | Allwinner A133 Plus | 1280×720 (16:9) | Dual analog sticks |
| TrimUI Smart Pro S | `tg5050` | Allwinner A523 | 1280×720 (16:9) | Fastest SoC |
| TrimUI Brick | `brick` | Allwinner A133 Plus | 1024×768 (4:3, touch) | Vertical, no analog |
| TrimUI Brick Pro | `brick_pro` | Allwinner A133 Plus | 1280×720 (16:9) | Same as TSP |

**One image works on all devices** — the OS auto-detects and tunes itself.

---

## What You Need

| Item | Requirement |
|------|-------------|
| **microSD card** | FAT32, 32 GB or larger recommended |
| **Card reader** | USB or built-in — any works |
| **Computer** | Windows, macOS, or Linux |
| **TrimUI device** | Smart Pro, Smart Pro S, Brick, or Brick Pro |

---

## Step-by-Step Installation

### Step 1: Format the SD Card

Your card must be formatted as **FAT32** with a **single partition**.

#### Windows

1. Insert the SD card into your computer
2. Open **File Explorer** and right-click the card drive
3. Select **Format**
4. Set **File system** to **FAT32**
5. Click **Start**

> **Cards over 32 GB?** Windows may only offer exFAT/NTFS. Use one of these tools instead:
> - [Rufus](https://rufus.ie) — lightweight, portable
> - [guiformat](https://www.ridgecrop.demon.co.uk/guiformat.htm) — simple FAT32 formatter
> - [Raspberry Pi Imager](https://www.raspberrypi.com/software/) — has a FAT32 option

#### macOS

1. Open **Disk Utility** (search with Spotlight)
2. Select your SD card in the sidebar (be careful to pick the right disk!)
3. Click **Erase** in the top toolbar
4. Set **Format** to **MS-DOS (FAT32)**
5. Click **Erase** and wait for completion

#### Linux

```bash
# First, identify your SD card (e.g., /dev/sdb)
lsblk

# Unmount any mounted partitions
sudo umount /dev/sdX*

# Format as FAT32 (THIS ERASES ALL DATA!)
sudo mkfs.vfat -F 32 /dev/sdX1
```

---

### Step 2: Download JukaMix OS

👉 **[Download Latest Release](https://github.com/jukaLang/JukaMix-OS/releases/latest)**

You'll see files like:
- `JukaMix_0821202601.zip` — **this is the one you want**
- `rootfs-tg5050.ext2` — Buildroot image (not needed for normal install)
- `rootfs-tsp-brick.ext2` — Buildroot image (not needed for normal install)
- `manifest.txt` — OTA update manifest (not needed for fresh install)
- `Packages` / `Packages.gz` — Package index (not needed for fresh install)

> **Version stamp format:** `MMDDYYYYHH`
> Example: `0821202601` = August 21, 2026 at 01:00

---

### Step 3: Extract to the SD Card Root

Extract the zip contents **directly to the root of the SD card** — **NOT into a subfolder**.

#### What You Should See

After extracting, your SD card should have this structure at the root:

```
SD Card/
├── Apps/              ← JukaMix apps and tools
├── BIOS/              ← BIOS files go here
├── Emus/              ← Emulator launchers and configs
├── Imgs/              ← Game artwork (boxart, screenshots)
├── Profiles/          ← Per-game performance profiles
├── RetroArch/         ← RetroArch config and cores
├── Roms/              ← Your ROM files go here
├── Saves/             ← Game saves (auto-created)
├── States/            ← Save states (auto-created)
├── System/            ← JukaMix system files
├── Themes/            ← UI themes go here
├── trimui/            ← TrimUI firmware and bootloader
└── BIOS/              ← BIOS files
```

#### Common Mistakes

❌ **DO NOT** create a subfolder like `JukaMix/` and extract into it
❌ **DO NOT** extract inside an existing folder like `SD Card/JukaMix/`
✅ **DO** extract so `Apps/`, `Emus/`, etc. are at the card root

#### Extraction Tools

| OS | Tool | How to Use |
|----|------|------------|
| **Windows** | [7-Zip](https://www.7-zip.org/) | Right-click zip → "Extract Here" |
| **Windows** | WinRAR | Double-click zip → drag contents to SD card |
| **macOS** | Built-in | Double-click zip → drag contents to SD card |
| **Linux** | `unzip` | `unzip JukaMix_*.zip -d /path/to/sdcard` |

---

### Step 4: First Boot

1. **Safely eject** the SD card from your computer
2. **Insert** the card into your TrimUI device
3. **Power on** the device

#### What to Expect

| Phase | What Happens |
|-------|--------------|
| **0-30 seconds** | Screen may be black or show TrimUI logo |
| **30-60 seconds** | JukaMix logo appears |
| **1-3 minutes** | System initializes, applies default settings |
| **3-5 minutes** | Menu loads — you're ready! |

> **First boot takes 2-5 minutes** — this is normal. The system is creating default configurations.

---

### Step 5: Firmware Update (If Prompted)

If your TrimUI firmware is older than JukaMix requires, a firmware wizard runs automatically.

#### How to Update Firmware

1. **Read the prompt** — it tells you the current vs. required firmware version
2. **Press A** to start the update
3. **Do NOT:**
   - Remove the SD card
   - Turn off the device
   - Press any other buttons
4. **Wait** for the device to power off automatically
5. **Power back on** — the firmware will be flashed

> This only happens once. The required firmware version is in `trimui/firmwares/MinFwVersion.txt`.

---

### Step 6: Add Your Content

#### ROMs

Place ROM files in `Roms/<SYSTEM>/`:

```
Roms/
├── GBA/          Game Boy Advance
├── NES/          Nintendo Entertainment System
├── SNES/         Super Nintendo
├── N64/          Nintendo 64
├── PS/           PlayStation
├── PSP/          PlayStation Portable
├── NDS/          Nintendo DS
├── DC/           Dreamcast
├── Genesis/      Sega Genesis/Mega Drive
├── MAME/         Arcade
└── ...           [100+ systems supported](../Emus/)
```

#### BIOS Files

Place BIOS files in `BIOS/`:

```
BIOS/
├── scph1001.bin    PlayStation BIOS
├── dc_boot.bin     Dreamcast BIOS
├── dc_flash.bin    Dreamcast VMU BIOS
├── gb_bios.bin     Game Boy BIOS
├── gba_bios.bin    Game Boy Advance BIOS
└── ...             [See each emulator folder for requirements]
```

> **Tip:** Check `Emus/<platform>/` for which BIOS files each system needs. Most systems work without BIOS, but some (PS1, Dreamcast) require them.

#### Themes

Drop theme files into `Themes/`:

```
Themes/
├── MyTheme.7z      ← Just drop it here
└── AnotherTheme.7z ← Appears in theme selector automatically
```

---

## Troubleshooting

### Stock Launcher Appears Instead of JukaMix

**Cause:** The SD card isn't set as the boot source.

**Fix:**
- **Smart Pro:** Go to **Settings → Boot Source → SD Card**
- **Smart Pro S:** Go to **Settings → Boot Source → SD Card**
- **Brick/Brick Pro:** Boots from SD automatically (no setting needed)

If the option doesn't appear, try:
1. Remove the SD card
2. Reformat as FAT32
3. Re-extract the JukaMix archive
4. Try again

---

### Screen Flickering or Menu Crashes

**Cause:** Corrupted or incomplete installation.

**Fix:**
1. Power off (hold power button for 5 seconds)
2. Remove SD card
3. On a computer, delete `System/usr/trimui/jukamix-version.txt` from the card
4. Reinsert card and power on

If this persists:
1. Re-extract the entire JukaMix archive to the card
2. Check for file corruption (re-download if needed)

---

### Games Not Showing Up

**Cause:** ROMs in wrong folder or wrong file extension.

**Fix:**
1. Verify ROMs are in the correct `Roms/<SYSTEM>/` folder
2. Check file extensions match what the system expects:
   - GBA: `.gba`
   - NES: `.nes`
   - SNES: `.sfc`, `.smc`
   - N64: `.n64`, `.z64`, `.v64`
   - PS1: `.bin`, `.cue`, `.iso`
   - PSP: `.iso`, `.cso`
   - NDS: `.nds`
3. Refresh the game list (restart the emulator launcher)

---

### BIOS Errors

**Cause:** Missing or incorrect BIOS files.

**Fix:**
1. Check which BIOS files your system needs:
   - Look in `Emus/<platform>/` for documentation
   - Common requirements:
     - **PS1:** `scph1001.bin` (or `scph5501.bin`, `scph7001.bin`)
     - **Dreamcast:** `dc_boot.bin`, `dc_flash.bin`
     - **Saturn:** `sega_101.bin`, `mpr-17933.bin`
2. Place BIOS files in `BIOS/`
3. Restart the emulator

---

### Performance Issues (Lag, Slow Games)

**Fix:**
1. **Check per-game profiles:** Some games have custom settings in `Profiles/<system>/<game>.cfg`
2. **Use the Key Remapper:** Customize controls for better ergonomics
3. **Check CPU governor:** Go to **System Tools → CPU Governor** and set to "performance"
4. **Close background apps:** Some apps may consume resources
5. **Check device temperature:** Overheating can cause throttling

---

### Wi-Fi Not Working

**Fix:**
1. Go to **Settings → Wi-Fi**
2. Select your network and enter password
3. If it doesn't connect:
   - Toggle Wi-Fi off and on
   - Reboot the device
   - Check if your router uses 2.4GHz (5GHz may not be supported)

---

### Sound Not Working

**Fix:**
1. Check volume isn't muted (press volume buttons)
2. Go to **Settings → Sound**
3. Check headphone jack connection
4. Restart the device

---

### Card Not Recognized

**Fix:**
1. Remove the card and reinsert it
2. Try a different card reader
3. Try a different SD card
4. Reformat as FAT32 and re-extract JukaMix

---

## Building from Source

### Requirements

- Linux (Ubuntu 22.04+)
- `build-essential`, `libncurses-dev`, `python3`, `git`, `wget`, `curl`
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

---

## Getting Help

- **Discord:** [Join the community](https://discord.gg/R9qgJjh5jG)
- **GitHub Issues:** [Report bugs](https://github.com/jukaLang/JukaMix-OS/issues)
- **Wiki:** [Read the docs](https://github.com/jukaLang/JukaMix-OS/wiki)

---

## FAQ

**Q: Can I use the same SD card for multiple devices?**
A: Yes! One image works on all four supported devices.

**Q: Will JukaMix delete my ROMs or saves?**
A: No. JukaMix protects user data paths — ROMs, BIOS, saves, and themes are never modified by updates.

**Q: Can I go back to stock TrimUI firmware?**
A: Yes. Remove the SD card and the device boots stock. Or reformat the card.

**Q: How do I update JukaMix?**
A: Connect to Wi-Fi → Open **Apps → JukaMix Control Center → System Update** → Confirm.

**Q: What if my device firmware is too old?**
A: JukaMix includes a firmware updater that runs automatically on first boot.

**Q: Do I need to install anything?**
A: No. JukaMix is ready to use after extraction. Just add your ROMs and BIOS files.

**Q: Can I use a USB drive instead of an SD card?**
A: No. TrimUI devices boot from SD cards only.

**Q: How much storage do I need?**
A: 32 GB minimum recommended. The OS takes ~2 GB; the rest is for ROMs and saves.
