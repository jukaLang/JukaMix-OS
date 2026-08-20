<div align="center">

<img src="_assets/readme/JukaMix-Logo.png" alt="JukaMix OS" width="420">

### One OS for every TrimUI handheld.

Smart Pro · Smart Pro S · Brick — auto-detected, auto-tuned.

[![Latest Release](https://img.shields.io/github/v/release/jukaLang/JukaMix-OS?style=for-the-badge&color=6c5ce7)](https://github.com/jukaLang/JukaMix-OS/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/jukaLang/JukaMix-OS/total?style=for-the-badge&color=00b894)](https://github.com/jukaLang/JukaMix-OS/releases)
[![License](https://img.shields.io/github/license/jukaLang/JukaMix-OS?style=for-the-badge)](LICENSE)
[![Discord](https://img.shields.io/badge/Discord-5865F2?style=for-the-badge&logo=discord&logoColor=white)](https://discord.gg/R9qgJjh5jG)
[![Patreon](https://img.shields.io/badge/Patreon-F96854?style=for-the-badge&logo=patreon&logoColor=white)](https://www.patreon.com/c/JukaLang)
[![Stars](https://img.shields.io/github/stars/jukaLang/JukaMix-OS?style=for-the-badge&color=fdcb6e)](https://github.com/jukaLang/JukaMix-OS/stargazers)

**[⬇️ Download](https://github.com/jukaLang/JukaMix-OS/releases/latest)** ·
**[📖 Docs](https://github.com/jukaLang/JukaMix-OS/wiki)** ·
**[💬 Discord](https://discord.gg/R9qgJjh5jG)** ·
**[🎨 Themes](Themes/)**

</div>

---

## Why JukaMix?

JukaMix OS builds on CrossMix OS to deliver a more powerful, customizable experience — with
improved settings, new features, updated emulators, and additional apps. It's completely free
and open source.

| | JukaMix OS |
|---|---|
| **Every TrimUI handheld** | Smart Pro, Smart Pro S and Brick from one image — performance profiles, emulator tuning and PortMaster setup adapt automatically to the running device |
| **Updates that can't brick you** | Transactional updates: every replaced file is backed up and journaled before it's touched, and any failure or interrupted update rolls back automatically |
| **Your data is untouchable** | ROMs, BIOS, saves, states, screenshots and themes are protected paths — the updater refuses to modify them |
| **No computer needed** | Wi-Fi → Control Center → System Update. A background checker toasts you when a release lands |
| **Integrity-checked updates** | Every file in an update is verified against the release manifest before it's applied |
| **Self-healing PortMaster** | Missing, broken, or copied without exec bits? It repairs itself on launch |
| **Built for creators** | Themes, icon packs, backgrounds, "Best" templates and automatic overlays |

---

## JukaMix vs other CFWs

On the Smart Pro / Smart Pro S / Brick you have a handful of custom-firmware options. They
split into three philosophies (the last one on different hardware):

- **Keep the stock firmware** — JukaMix, CrossMix, and (historically) Tomato run as a layer on
  top of the TrimUI firmware, so you keep its drivers, hardware video decode and power
  management. Everything is on the SD card: remove it and the device is stock again.
- **Replace the OS** — Knulli, Spruce, NextUI and MinUI boot their own system. You gain
  control and polish, but trade away the stock firmware's device-specific tuning.
- **Go Android** — GammaOS swaps the stock OS for a debloated, performance-tuned Android
  build: Play Store, the whole Android app ecosystem, a Daijisho front-end and root. On the
  TrimUI Smart Pro and Brick the lightweight **GammaOS Nano** variant runs directly (same
  Allwinner A133P as its Android port); the full Android "Next" line covers the other
  Android handhelds. Only the Smart Pro S (A523) is out of reach.

| CFW | Devices | Base | Updates | Standout | Watch out |
|---|---|---|---|---|---|
| **JukaMix OS** | Smart Pro, Smart Pro S, Brick | Stock firmware + CrossMix framework | Transactional, in-app over Wi-Fi | One image tuned for all three devices; updates that can't brick you | Younger project; TrimUI devices only |
| **CrossMix-OS** | Smart Pro (+ Brick in newer releases) | Stock firmware | Full-image | The mature upstream that JukaMix builds on | Full-image updates only; Smart Pro S not covered |
| **Knulli** | Broad — many handhelds | Batocera / EmulationStation, standalone OS | Full-image reflash | Desktop-grade emulation: scrapers, themes, Bluetooth, netplay | Heavier and slower to boot; higher idle power draw |
| **Tomato OS** | Original TrimUI Smart only | Stock firmware | Full-image | Pioneering enhanced OS (70+ emulators, ports) for its day | Discontinued; not for the Smart Pro / Smart Pro S / Brick |
| **Spruce** | Smart Pro, Smart Pro S, Brick + Miyoo/Anbernic family | Custom Python UI, own system | OTA, in-app over Wi-Fi | Polished UI, Game Switcher, Theme Garden, Game Nursery, Syncthing | TrimUI support is a newer port; more Miyoo-tuned |
| **NextUI** | Brick, Smart Pro, Smart Pro S | MinUI fork with rebuilt emulation engine | Full-image | Fast, low-latency, feature-packed (shaders, WiFi, LEDs, cheats, paks) | PolyForm **non-commercial** license |
| **MinUI** | Many devices — TrimUI builds are **Legacy** | Minimal libretro launcher | Full-image | Zero-config: boots straight to games, auto-resume | No settings, boxart or themes by default; TrimUI builds being retired |
| **GammaOS / Next / Nano** | Android handhelds (Anbernic, AYANEO, Retroid, …) + TrimUI Smart Pro & Brick via **Nano** (A133P) | LineageOS-based Android (12, now 13/14; Nano = lightweight micro-OS) | Full reflash (fastboot / SD image) | The whole Android ecosystem: Play Store, Android apps, Daijisho, root; Nano = console-style home | Needs a PC to flash; full-image updates; some Nano releases launch Patreon-gated |

### JukaMix OS

**Advantages** — runs on the stock TrimUI firmware (its drivers, hardware video decode and
sleep behavior stay intact); one image covers the Smart Pro, Smart Pro S and Brick with
per-device CPU/game profiles applied automatically; transactional updates that back up,
journal and roll back; the updater refuses to touch `Roms/`, `BIOS/`, saves or themes;
self-healing PortMaster, Python, glibc and the Wi-Fi Control Center; GPL-3.0 open source.

**Disadvantages** — TrimUI devices only; it's a layer on the stock firmware, so it inherits
stock quirks (and a TrimUI firmware update can change behavior underneath it); younger and
smaller community than CrossMix or Knulli.

### CrossMix-OS

**Advantages** — the mature, battle-tested upstream that JukaMix forks; huge community, wiki
and theme/icon ecosystem; same stock-firmware benefits; first-class PortMaster integration.

**Disadvantages** — releases are full-image installs (no transactional, rollback-safe
updates); no per-device capability layer, so Smart Pro S coverage and device-specific tuning
are left to the user; updates can overwrite your data if you're not careful.

### Knulli

**Advantages** — a true standalone OS (Batocera base) with EmulationStation's whole world:
automatic scraping, thousands of themes, Bluetooth controllers, netplay, per-system config;
one setup carries across many handhelds, not just TrimUI.

**Disadvantages** — much heavier: slower boot and higher power draw than the stock-based
options; full-image reflash to update; on TrimUI devices the hardware acceleration and
sleep/power behaviour historically lag the stock firmware's.

### Tomato OS

**Advantages** — in its time (2022–2023) a pioneering enhanced OS for the original TrimUI
Smart, with 70+ built-in emulators, ports and customization.

**Disadvantages** — built for the original TrimUI Smart only and no longer maintained; it
does **not** run on the Smart Pro, Smart Pro S or Brick. Listed here mainly so you don't
install it by mistake.

### Spruce

**Advantages** — sleek, heavily themeable Python UI (Theme Garden with 80+ themes); Game
Switcher for save-state juggling; autosave on shutdown / autoresume on boot; OTA updates;
Game Nursery for free ports and homebrew; network services (Syncthing, Samba, SSH,
RetroAchievements) and native Pico-8; covers all three TrimUI devices plus the Miyoo and
Anbernic families.

**Disadvantages** — a separate OS rather than a stock-firmware layer; TrimUI support is a
newer port, so features and tuning are still more Miyoo-focused; you manage your own system
partition and updates.

### NextUI

**Advantages** — takes MinUI's simplicity and rebuilds the emulation engine: fixes MinUI's
screen tearing and sync stutter, ~20 ms lower latency, shaders, overlays and high-quality
audio resampling; WiFi, Bluetooth audio, cheats, game-time tracking, LED control, deep
sleep and battery stats; an active community **pak** ecosystem (pak store, music player,
netplay) built specifically for the Brick, Smart Pro and Smart Pro S.

**Disadvantages** — licensed under **PolyForm Noncommercial 1.0.0** (since August 2026), so
commercial use is prohibited even though it started GPL-3.0; MinUI-minimal roots mean some
niceties (scraping, art) come via third-party paks.

### MinUI

**Advantages** — the definition of simple: no settings, no boxart, no themes, no cruft; boots
fast, sips battery, auto-sleeps, and resumes exactly where you left off; the same card works
across many different handhelds.

**Disadvantages** — by design it has none of the comforts (scraping, artwork, PortMaster,
Wi-Fi apps) and no tuning; and on TrimUI specifically the Smart Pro and Brick builds are
marked **Legacy** — the project says they "will be retired in a future update", so it's a
risky pick for a daily driver.

### GammaOS / GammaOS Next / GammaOS Nano

**Advantages** — turns a handheld into a clean, debloated, performance-tuned device: a
LineageOS base (Android 12, now Android 13/14 with GammaOS Next), the **Full** edition ships
Google Play and Play Services (Lite skips Google for extra headroom), the Daijisho
front-end preconfigured with RetroArch, Aurora Store, Magisk root, performance governors
with quick-settings tiles, and system-wide extras (shaders, BFI, HDMI docking, LED sync) on
supported panels. On the TrimUI Smart Pro and Brick the lightweight **GammaOS Nano** variant
boots a fast console-style home directly — it is built on the same Allwinner A133P Android
port, runs entirely from the SD card, and leaves the stock firmware untouched. Above all it
unlocks the **entire Android ecosystem** — Play Store apps, Android ports, cloud streaming
— which no Linux firmware can offer.

**Disadvantages** — flashing needs a PC (fastboot/ADB + drivers, or the SD-card tool for
Nano), updates are full reflashes, and you're managing an Android device (app updates,
battery, background behavior) rather than a focused game console. Some Nano releases launch
as Patreon-exclusive early access before going public, and the full Android "Next" line
covers Android handhelds only — the Smart Pro S (A523 SoC) is not supported.

> The short version: want the stock experience with safe updates across all three devices?
> That's JukaMix. Want a completely different, feature-dense OS? Knulli or NextUI. Want
> bare-bones speed? MinUI. Want a polished all-rounder with a big family of devices? Spruce.
> Want the Android ecosystem — even on the Smart Pro or Brick? GammaOS (Nano on TrimUI,
> Next on Android handhelds) is the pick.

---

## Install

> First time on JukaMix? Start here. Already running it? Skip to [Updating](#updating).

**What you need:** a microSD card (FAT32, 32 GB or larger recommended — it holds the OS *and*
your ROMs), a card reader, and any computer. One image works on all three devices — there is no
per-device download.

### 1. Format the card

Format the card as **FAT32**, single partition. Windows: right-click the card → **Format** →
FAT32 (for cards over 32 GB, where the built-in formatter only offers exFAT/NTFS, use
[Rufus](https://rufus.ie), the Raspberry Pi Imager, or guiformat). macOS: **Disk Utility** →
**Erase** → MS-DOS (FAT).

### 2. Download

Grab the latest `JukaMix_<stamp>.zip` (e.g. `JukaMix_0820202614.zip`) from the
[latest release](https://github.com/jukaLang/JukaMix-OS/releases/latest). The stamp is the build
date+hour — `MMDDYYYYHH`, so `0820202614` is August 20, 2026 at 14:00.

### 3. Extract to the card root

Extract the archive to the **root** of the SD card so that `Apps/`, `Emus/`, `Roms/`,
`System/` and `trimui/` sit at the top level — **not inside a subfolder**. 7-Zip on Windows
preserves the layout and file permissions.

### 4. First boot

Eject the card safely, insert it into the handheld, and power on. First boot takes a few minutes
while the system initialises.

**If your device's TrimUI firmware is older than the version JukaMix requires** (see
`trimui/firmwares/MinFwVersion.txt` on the card), a firmware-update wizard runs on first boot:
it verifies the bundled firmware archive, extracts it, and backs up your settings. **When it
prompts, press A and let the device power off, then power back on** — the built-in updater
flashes the firmware. Don't remove the card or interrupt power during this step; it happens only
once.

If the stock launcher appears instead of JukaMix, make sure the SD card is selected as the boot
source in the device's Settings (Smart Pro) — the Brick boots from SD automatically.

### 5. Add your content

Drop ROMs into `Roms/<platform>/` and BIOS files into `BIOS/` (see `Emus/<platform>/` for which
BIOS each system expects), then re-enter the system to refresh the game lists. Themes, icon packs
and backgrounds are drop-in — see [Customise it](#customise-it).

<details>
<summary><b>Upgrading from CrossMix-OS?</b></summary>

Back up `Roms/`, `BIOS/`, `Saves/` and `Screenshots/` to your computer first, then follow the
steps above and copy your data back. Saves and settings are migrated by the installer where
possible, but a manual backup is always the safe move.

</details>

---

## Updating

Updating is one tap, no computer required:

1. Connect the handheld to Wi-Fi.
2. Open **Apps → JukaMix Control Center → System Update** (or the standalone **System Update** app).
3. Confirm the download.

JukaMix resolves the latest GitHub release and — when the release ships a `manifest.txt` —
applies the change transactionally, verifying every file against the manifest as it's applied.
Every replaced file is backed up and journaled, pending config migrations (`migrations/*-to-*.sh`)
run once in order, and any failure rolls the update back automatically. Releases that ship only a
full image fall back to the classic full-image installer, which also migrates saves and settings.

<details>
<summary><b>Offline update (no Wi-Fi)</b></summary>

1. Download the latest `JukaMix_<stamp>.zip` from GitHub Releases on any computer.
2. Copy it to the **root** of the SD card.
3. Open **Apps → System Update** and apply it — or just reboot, and the legacy updater picks up
   the archive from the SD root.

</details>

---

## Supported devices

| Device | Code | SoC | GPU | Display | Notes |
|---|---|---|---|---|---|
| **TrimUI Smart Pro** | `tsp` | Allwinner A133 Plus | Mali-G31 | 1280×720 (16:9) | Flagship target, dual analog |
| **TrimUI Smart Pro S** | `tg5050` | Allwinner A523 | Mali-G57 | 1280×720 (16:9) | Fastest of the three, dual analog |
| **TrimUI Brick** | `brick` | Allwinner A133 Plus | Mali-G31 | 1024×768 (4:3, touch) | No analog sticks, no rumble |

Every emulator launcher tunes the CPU to its device's own ceiling via
`cpufreq.sh ondemand 2 "${JUKAMIX_CPUFREQ_MAX:-6}"`: **Smart Pro S** runs at up to
2.0 GHz, **Smart Pro** at 1.8 GHz and **Brick** at 1.6 GHz (the `[recommended_defaults]` of each
`Profiles/DEVICE-OVERRIDES/*_base.cfg`). Launchers written for the faster A523 are clamped to the
closest valid frequency on the A133 instead of being rejected, so the same image tunes every
device correctly.

**Per-game profiles** in `Profiles/<system>/` (e.g. `Profiles/DC/SonicAdventure.cfg`) apply
automatically when that game launches. The applier (`apply_game_profile.sh`) clamps each
profile's frequencies to the running device's ladder, so a profile tuned on the Smart Pro S
applies safely on the Smart Pro and Brick too — a profile verified for another device warns, and
`--strict` refuses it.

---

## PortMaster, made simple

PortMaster ships pre-installed in **Apps → PortMaster**, with a second entry in the **PORTS** tab.
Both entry points self-heal: if PortMaster is missing, broken, or was copied onto the SD card
without execute permissions, it is repaired automatically on launch. Ports live in `Data/ports/`
and appear in the PORTS tab automatically.

Drop any port zip into `Apps/PortMaster/PortMaster/autoinstall/` and open the PortMaster app —
it installs them for you.

<details>
<summary><b>The <code>jm-portmaster</code> CLI</b></summary>

From the terminal or over SSH:

```bash
jm-portmaster status    # what is installed, where, and how healthy
jm-portmaster install   # download + install the latest official release
jm-portmaster ensure    # install only if missing/broken (no-op when healthy)
jm-portmaster fix       # repair exec bits, Data/ports, launcher (offline)
jm-portmaster launch    # ensure, then open the PortMaster GUI
```

Downloads are checksum-verified against PortMaster's published MD5.

**Offline install:** grab `trimui.portmaster.zip` from the PortMaster-GUI releases page, copy it
to the SD card, then run:

```bash
jm-portmaster install --from-zip /mnt/SDCARD/trimui.portmaster.zip
```

</details>

---

## Built-in tools

Python 3.11 ships in the image (`System/bin/python3.11` with Pillow and pip), and
several utilities are built on top of it. Find them under **Apps → System Tools → TOOLS**:

| Tool | What it does |
|---|---|
| **Find Duplicate Roms** | Hashes every ROM per system (size + md5) and stashes exact duplicates into `Data/duplicates/<system>/`. Files are moved, never deleted. |
| **Test ROM Archives** | Checksum-tests every `.zip` per system and stashes broken archives into `Data/archives-corrupt/<system>/`. Also moved, never deleted. |
| **Optimize Boxart Images** | Shrinks boxart in `Imgs/` down to 512 px with Pillow and re-saves optimized; only overwrites when the result is smaller. |
| **M3U Playlist Generator** | Creates multi-disc playlists from `(Disc 1)`/`[Disc 2]`-style files in `Roms/`. |

Add your own Python tools the same way: a script in `System/usr/trimui/scripts/` plus a launcher
in `Apps/SystemTools/Menu/TOOLS/` that calls `python3.11` (see the existing entries for the
`LD_LIBRARY_PATH`/`PATH` setup and the `TOTAL_*=` output convention the UI parses).

**Recent-glibc software:** the image bundles glibc **2.44** in `System/lib/glibc/` (loader + core
libs), so anything built against a newer glibc than the firmware ships still runs. Use the
`jm-glibc` wrapper — `jm-glibc /path/to/binary [args…]` — which invokes the bundled loader
directly; update the runtime from the Debian `libc6` package (see `System/lib/glibc/README.md`).

---

## Customise it

JukaMix is built for creators. Everything below is drop-in — no rebuild required.

| Folder | What goes there |
|---|---|
| `Themes/` | Full UI themes |
| `Icons/` | Icon packs |
| `Backgrounds/` | Wallpapers per system |
| `Best/` | Curated game-collection templates |

Made something good? Open a PR — community themes and icon packs are very welcome.
See [CONTRIBUTING.md](CONTRIBUTING.md) for the format spec and submission process.

Best pack folders must not contain spaces — the on-device name comes from the pack's
`config.json` `label`, not the folder name (see `Best/FreeGamesCollection/`).

---

## Repository layout

A few boundaries are worth knowing before you poke around:

| Path | What it is |
|---|---|
| `System/bin/`, `System/lib/` | Prebuilt runtime payload shipped in the image: third-party binaries (`bash`, `curl`, `7zz`, `ffmpeg`, …) and shared libraries, installed at `/mnt/SDCARD/System/bin` and `/mnt/SDCARD/System/lib`. `System/bin` is on `PATH` on-device. |
| `bin/`, `lib/`, `migrations/`, `config/` | JukaMix's own tooling (`jm-update`, `jm-opkg`, `jm-portmaster`, …). `install.sh` copies these into `System/usr/jukamix/{bin,lib,migrations}` on the device. `/mnt/SDCARD/bin` is added to `PATH` (after `System/bin`, so nothing is shadowed) — `jm-opkg`, `jm-doctor`, etc. are invocable directly. |
| `scripts/`, `tests/`, `schemas/`, `packages/` | Host-side build and validation tooling, **excluded from the release image and the OTA manifest**. Never needed on the SD card. |
| `tools/` | Build tooling that **also ships** in the image — JukaHub, System Update and `jukamix-validate` read `/mnt/SDCARD/tools/` on-device. |
| `Roms/`, `BIOS/`, `Saves/`, `States/`, `Pictures/screenshots/`, `Themes/` | Protected user-data paths — an update never modifies them. The repo tracks only scaffolding (`.gitkeep`) and OS-provided content such as emulator bezels or machine definitions; user files never belong in git. |
| `MANIFEST.json` | Release build artifact, generated into `dist/` by `scripts/build_release.sh`. Never committed, never part of the image. |
| `trimui/firmwares/` | TrimUI firmware blobs are fetched on demand (see `scripts/fetch_firmware.sh`), not tracked in git. |
| `RetroArch/.retroarch/cores/cores.7z` | Compressed RetroArch cores archive (~335MB, 165 cores). Too large for git; hosted at [jukaLang/Packages](https://github.com/jukaLang/Packages/releases/tag/cores) and downloaded at build time via `scripts/fetch_cores.sh`. Never committed to git. |

---

## Contributing

Issues and pull requests are welcome — see [CONTRIBUTING.md](CONTRIBUTING.md) to get started,
and [SUPPORT.md](SUPPORT.md) if you need help rather than want to file a bug.
Join the conversation on [Discord](https://discord.gg/R9qgJjh5jG).

<details>
<summary><b>Release pipeline (maintainers)</b></summary>

```bash
scripts/build_release.sh            # defaults to today's date+hour stamp
scripts/build_release.sh 0820202614  # or pass an explicit stamp
```

Stamps the build, fetches the firmware blobs, restores exec bits, and publishes into `dist/`:

| Asset | Purpose |
|---|---|
| `JukaMix_0820202614.zip` | The full SD-card image (stamp = `MMDDYYYYHH`) |
| `manifest.txt` | Incremental OTA manifest. **This is the transactional updater's source of truth**: when a release ships it, updates apply incrementally; without it, updates fall back to the full-image installer. `manifest.json` is accepted as a fallback by the updater, but `manifest.txt` always wins. |

Before archiving it runs `scripts/validate_devices.sh` to confirm the combined image ships the
device-specific files, profiles, and detection data for every supported device — Smart Pro
(`tsp`), Smart Pro S (`tg5050`) and Brick (`brick`) — and that each one resolves to the right
hardware profile and capabilities.

Publishing is automatic: every push to `main` (or a manual run of the [release workflow](.github/workflows/JukaMix-OS%20Release.yml))
builds the image and **publishes** the release with the archive and manifest. The stamp is
generated at build time from the date+hour (`MMDDYYYYHH`, e.g. `JukaMix_0820202614`), so every
build is a new version. Rebuilding within the same hour overwrites that hour's release, so
`releases/latest` always points at the newest build; on-device update checkers simply report no
update until the first release exists.

</details>

---

## Attribution

JukaMix OS is an independently maintained derivative of **CrossMix-OS**, originally created by
**Cizia**. It is not affiliated with or endorsed by the CrossMix-OS maintainers. CrossMix-OS and
all included third-party components remain subject to their respective licenses and copyrights.

JukaMix builds on the extensive work of the CrossMix-OS project, **PortMaster** (Kloptops),
**Schmurtzm's** scripts, and the many contributors acknowledged upstream. Full upstream credits,
including Cizia's own notes on the features that make CrossMix what it is, live in the
**[CrossMix-OS repository](https://github.com/cizia64/CrossMix-OS)**; what JukaMix changed on top
of that baseline is documented in [CHANGELOG.md](CHANGELOG.md).

Licensed under [GPL-3.0](LICENSE).

<div align="center">
<sub>Made by the Juka project · <a href="https://discord.gg/R9qgJjh5jG">Discord</a> · <a href="https://github.com/jukaLang">GitHub</a></sub>
</div>
