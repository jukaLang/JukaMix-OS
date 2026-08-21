# Changelog — JukaMix OS vs CrossMix-OS

JukaMix OS is a fork of [CrossMix-OS](https://github.com/cizia64/CrossMix-OS)
(upstream remote: `cizia64/CrossMix-OS`). This changelog documents what differs
from the upstream baseline, grounded in a file-by-file comparison of the two
trees (22,919 upstream files) plus the fork-point diff against CrossMix's
initial commit (40 added, 163 deleted, 345 modified, 82 renamed).

Current build stamp: `JukaMix_0820202614` — builds are named after the build date+hour
(`MMDDYYYYHH`, e.g. August 20, 2026 at 14:00) and stamped into
`System/usr/trimui/jukamix-version.txt`.

## 1. Brick support + per-device layer

CrossMix has **zero** `Profiles/` files and no device abstraction at all —
every script assumes the Smart Pro. JukaMix adds a real device layer:

- `System/usr/trimui/scripts/device_detection.sh` — identifies the running
  device (`tsp` / `tg5050` / `brick`) and exports `DEVICE_CODE` for every other
  script.
- `Profiles/` — per-device capability profiles: `tsp_base.cfg`,
  `tg5050_base.cfg`, `brick_base.cfg`, plus per-game profiles
  (`Profiles/<system>/<game>.cfg`) tagged with the device they were tuned on.
- `inputd_switcher.sh` — swaps input daemon configuration per device.
- `apply_game_profile.sh` — applies per-game CPU/GPU settings with explicit
  three-device mapping, `Device:`-tag enforcement (warn on mismatch, refuse
  under `--strict`), and a `--quiet` mode; wired into `common_launcher.sh` as a
  guarded background hook so profiles activate at launch time.
- One image ships for **all three devices** (Smart Pro, Smart Pro S, Brick);
  the launcher framework adapts at runtime.

## 2. CPU tuning

- Clamp-not-reject: out-of-range frequencies are clamped to the device's
  capability ladder instead of being rejected, so one tuned profile can't
  break a different device.
- Bidirectional hardware ceiling: the cpufreq helper tracks the hardware's
  actual OPP table both ways (A523 raises the step, low-ceiling kernels pull
  it down) and reads the sysfs ceiling in a newline-immune way.
- `cpufreq_default.sh` — single source of truth for per-device default ceilings
  (tg5050 → 8, tsp → 7, brick → 6), sourced by `common_launcher.sh`, the DOOM
  GZDoom branch, and the music/video ffmpeg launchers (which previously ran
  silently capped at 1.6 GHz on every device).
- 118 device-aware launcher defaults across `Emus/`.

## 3. Update system

- `jm-update` — transactional updater: every replaced file is backed up and
  journaled before it's touched, pending config migrations run once in order,
  and any failure or interrupted update rolls back automatically.
- OTA engine (`tools/lib/jukamix-ota.sh`, `jukamix-update.sh`) — incremental
  updates driven by `manifest.txt`, with per-file SHA-256 verification against
  the manifest before anything is applied.
- Deliberately simple: **no SHA256SUMS download-verification file, no
  signing**. Signature verification was removed entirely (the updater already
  treated it as best-effort); integrity comes from the per-file hashes inside
  the manifest.
- Dead hotfixes removed; the user-data paths (`Roms/`, `BIOS/`, `Saves/`,
  `States/`, `Pictures/screenshots/`, `Themes/`) are protected — the updater
  refuses to modify them.

## 4. `jm-*` CLI tools (18) + on-device tooling

- `bin/` hosts 19 `jm-*` tools (`jm-update`, `jm-portmaster`, `jm-glibc`,
  `jm-opkg`, `jm-validate`, …) copied into `System/usr/jukamix/{bin,lib,
  migrations}` on the device; `System/usr/trimui/scripts` and the update
  tooling put `/mnt/SDCARD/bin` on `PATH` (after `System/bin`, so nothing is
  shadowed), and the rest can be invoked by full path.
- 12 on-device scripts under `System/usr/jukamix/` — recovery guards, config
  migrations, and the `*_cpufreq.sh` per-device helpers (also JukaMix-only;
  CrossMix has no per-device CPU helpers at all).

## 5. Python tooling

- Three new Python tools on top of the Python 3.11/Pillow runtime inherited
  from CrossMix (image prep, rom metadata, and a helper for Best-pack assets).

## 6. glibc + package channel

- glibc 2.44 bundled and switchable via `jm-glibc` (system-wide switch to a
  modern glibc for apps that need it — newest glibc where possible).
- `jm-opkg` + a packages channel for installing extra software on-device.

## 7. Build / release pipeline

- `scripts/build_release.sh` — reproducible release build that stages the
  image, stamps the build, restores executable bits, extracts RetroArch cores,
  generates the OTA manifest, validates, and zips.
- Releases are named `JukaMix_<MMDDYYYYHH>` (date+hour, e.g.
  `JukaMix_0820202614`) — the stamp defaults to the build time, so every build
  is a new version.
- `scripts/validate_devices.sh` — 58-check release gate covering every device
  (tsp, tg5050, brick): required files, device detection, capability
  resolution, launcher wiring, manifest cross-check.
- CI auto-creates a release on every build (`.github/workflows/JukaMix-OS
  Release.yml`) — no manual release step; each build is stamped with the
  date+hour and published as `JukaMix_<MMDDYYYYHH>.zip` + `manifest.txt`.
- Firmware blobs are fetched on demand (`scripts/fetch_firmware.sh`), never
  committed; the first-boot firmware wizard ships in the image.
- JukaHub's patch index is version-stamped at build time so the shipped
  `packages.json` always references the release that contains it.
- `scripts/validate.sh` gained a POSIX-compliance gate that scans every
  on-device `.sh` for bashisms (CI-enforced regression guard for section 9).
- Pipeline hardening: the executable-bit restore now exits 0 explicitly (GNU
  `find -exec … +` propagates a non-zero inner status, which aborted the build
  under `set -e`); CI stamps the version + JukaHub index *before* generating
  the OTA manifest and running the device gate (so manifest checksums and the
  version check match the shipped zip); and the CI zip excludes now mirror
  `build_release.sh` (user-data dirs `Roms`/`ROMs`/`BIOS`/`Saves`/`States` and
  stray OS chrome never ship).

## 8. Repo hygiene

- User data (`Roms/`, `BIOS/`, `Profiles/`, `Pictures/screenshots/`) reduced
  to `.gitkeep`-style scaffolding — tracking those paths would let a careless
  full-image install overwrite saves.
- `Best/FreeGamesCollection` — renamed to remove the spaces that broke
  unquoted shell expansions (the on-device name comes from `config.json`
  `label`).
- Image-exclusion boundaries documented: host-side `scripts/`, `tests/`,
  `schemas/`, `packages/` never ship; `MANIFEST.json` is a build artifact in
  `dist/`, never committed.
- `.VolumeIcon.icns` / `autorun.inf` removed from the checksum surface.

## 9. POSIX hardening (the device shell is busybox ash)

The TrimUI firmware runs busybox ash, and the first-boot firmware check
symlinks `/bin/bash` → busybox — so *no* script gets a real bash. Every
bashism below was a real crash on-device:

- `source` → `.` in ~430 scripts (the `Emus/*/default.sh` launcher set, PortMaster,
  apps, tools).
- `[[ ]]` → `[ ]` / `case` (PortMaster, Scraper, SystemTools label scripts).
- `${var//…}` → POSIX `sed`/`tr`/`case` rewrites (romscript launcher, scraper,
  PSX detector, overlay scripts).
- `let x++` → `$((x + 1))` (scraper, CUE generator).
- `&>` → `> file 2>&1` (scraper_old).
- Hundreds of unquoted-expansion fixes (`$RA_DIR` and friends).
- All changes verified with `bash --posix -n`; the CI gate in
  `scripts/validate.sh` scans all 651 on-device scripts for regressions.

## 10. Removed apps

MusicPlayer, SmartLed, FileManager, EbookReader, random, Reboot, and assorted
OS chrome were dropped — either superseded by JukaMix tooling or dead weight
on all three devices.

## 11. Documentation

- README overhaul: accurate install flow (first-boot firmware wizard, FAT32
  formatter caveat, extract-to-root), Updating section matching the real
  transactional flow, honest feature rows, working Discord invite,CFW comparison (JukaMix vs CrossMix, Knulli, Tomato, NextUI, MinUI, GammaOS).
- `jukamix-version.txt` — renamed from CrossMix's `crossmix-version.txt`, now
  holds the date+hour build stamp.
- `CONTRIBUTING.md` added (Best-pack format spec, shell rules, PR process);
  dead links removed; `CHANGELOG.md` (this file) documents the fork delta.

## Unchanged from CrossMix

The launcher framework (`common_launcher.sh`, load/save flow), RetroArch
bundling, themes, PortMaster, the Scraper, and the content directory layout
carry over from upstream and remain compatible with CrossMix content drops.

## Caveat

The file-presence comparison is exact (both trees enumerated via the GitHub
Trees API). Content diffs of the ~22,300 shared files were not individually
inspected, so this changelog highlights structural and behavioral changes
rather than a byte-level audit.
