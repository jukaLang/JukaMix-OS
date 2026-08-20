# JukaMix OS - Community Game Profiles

This directory contains community-maintained per-game optimization profiles for JukaMix OS.

## What are Game Profiles?

Game profiles are device-specific configuration overrides that optimize individual games for:
- **Performance** (CPU frequency, GPU settings, core selection)
- **Visual quality** (internal resolution, aspect ratio, shaders)
- **Controls** (button mapping, analog deadzone, hotkeys)
- **Save states** (compression, autosave intervals)

## Directory Structure

```
Profiles/
├── DC/                    # Dreamcast games
│   ├── Shenmue.cfg
│   └── SonicAdventure.cfg
├── N64/                   # Nintendo 64 games
│   ├── OcarinaOfTime.cfg
│   └── Mario64.cfg
├── PSP/                   # PlayStation Portable games
│   ├── GodOfWar.cfg
│   └── MonsterHunter.cfg
├── PS1/                   # PlayStation 1 games
│   ├── FinalFantasy7.cfg
│   └── MetalGearSolid.cfg
└── DEVICE-OVERRIDES/      # Device-specific base profiles
    ├── tg5050_base.cfg
    ├── tsp_base.cfg
    └── brick_base.cfg
```

## Profile Format

Each profile is a simple key-value file:

```ini
# Game: Sonic Adventure (Dreamcast)
# Device: tg5050 (TrimUI Smart Pro S)
# Contributor: @username
# Date: 2026-08-17

[performance]
cpu_governor = performance
cpu_min_freq = 1416000
cpu_max_freq = 2200000
active_cores = 4

[gpu]
internal_resolution = 2x
texture_upscaling = enabled
anisotropic_filtering = 4
threaded_rendering = true

[controls]
analog_deadzone = 10%
trigger_deadzone = 5%

[audio]
latency_ms = 32
sync_enabled = false

[notes]
# Optional: performance notes, known issues, tips
"Runs at full speed with 2x upscale. Disable fog for +5 FPS."
```

## How to Use Profiles

### Automatic Application (Recommended)

JukaMix OS automatically detects and applies profiles when you launch a game:

1. Launch any game from the EmulationStation menu
2. The `common_launcher.sh` checks for a matching profile in `Profiles/<SYSTEM>/<GAME>.cfg`
3. If found, it applies the device-specific overrides before launching the emulator
4. Falls back to system defaults if no profile exists

### Manual Application

```sh
# Apply a specific profile
/mnt/SDCARD/System/usr/trimui/scripts/apply_game_profile.sh --game "Sonic Adventure" --system DC

# List available profiles
/mnt/SDCARD/System/usr/trimui/scripts/apply_game_profile.sh --list

# Test profile without applying
/mnt/SDCARD/System/usr/trimui/scripts/apply_game_profile.sh --game "Sonic Adventure" --system DC --dry-run
```

## Contributing Profiles

### Step 1: Test Your Game

Run the game with different settings and note what works best:
- Which core performs best?
- What internal resolution is stable?
- Any audio sync issues?
- Control quirks?

### Step 2: Create the Profile

Copy the template and fill in your findings:

```sh
cp /mnt/SDCARD/Profiles/TEMPLATE.cfg /mnt/SDCARD/Profiles/N64/YourGame.cfg
nano /mnt/SDCARD/Profiles/N64/YourGame.cfg
```

### Step 3: Validate

```sh
/mnt/SDCARD/System/usr/trimui/scripts/validate_profile.sh /mnt/SDCARD/Profiles/N64/YourGame.cfg
```

### Step 4: Submit

1. Fork the JukaMix-OS repository
2. Add your profile to the appropriate `Profiles/<SYSTEM>/` folder
3. Include a comment header with your GitHub/Discord handle and test date
4. Open a Pull Request with description of tested device and firmware version

## Profile Validation

The `validate_profile.sh` script checks:
- ✅ Valid INI syntax
- ✅ Required fields present (`[performance]`, `[gpu]`)
- ✅ Frequency values within device limits
- ✅ No conflicting settings
- ✅ Proper file naming convention

## Device-Specific Base Profiles

Base profiles define default settings for each device type. Game profiles inherit from these and override only what's necessary.

| Device | Base Profile | Notes |
|--------|-------------|-------|
| TrimUI Smart Pro S (TG5050) | `DEVICE-OVERRIDES/tg5050_base.cfg` | A523 SoC, Mali-G57, up to 2.4GHz |
| TrimUI Smart Pro (TSP) | `DEVICE-OVERRIDES/tsp_base.cfg` | A133+, Mali-G31, up to 2.0GHz |
| TrimUI Brick | `DEVICE-OVERRIDES/brick_base.cfg` | A133+, vertical display, single analog |

## Example: Optimizing a New Game

Let's say you want to optimize **God of War: Chains of Olympus** on PSP:

1. **Baseline test**: Run with default settings, note FPS and issues
2. **Core selection**: Try PPSSPP 1.17.1 GL vs Vulkan (if available)
3. **Resolution scaling**: Test 1x, 2x internal resolution
4. **Frame skipping**: Enable/disable, check impact
5. **Audio sync**: Toggle, measure latency
6. **Document findings** in profile

```ini
# Game: God of War - Chains of Olympus (PSP)
# Device: tg5050
# Contributor: @yourhandle
# Date: 2026-08-17
# Tested Firmware: v1.3.0

[performance]
cpu_governor = performance
cpu_min_freq = 1416000
cpu_max_freq = 2200000

[gpu]
internal_resolution = 2x
texture_filtering = Auto
frame_skip = 0
vsync = false

[audio]
latency_ms = 48
sync_enabled = true

[notes]
"Stable 60 FPS at 2x. Audio sync required for cutscenes. Disable post-processing shaders."
```

## Troubleshooting

**Profile not applying?**
- Check file path: `Profiles/<SYSTEM>/<GameName>.cfg`
- Verify system name matches EmulationStation (e.g., `PSP` not `psp`)
- Run `apply_game_profile.sh --list` to see detected profiles

**Game crashes after applying profile?**
- Profile may have aggressive settings; try base profile first
- Check device compatibility (tg5050 profiles may be too aggressive for TSP)
- Report issue with game name and device code

**Want to revert to defaults?**
```sh
/mnt/SDCARD/System/usr/trimui/scripts/apply_game_profile.sh --game "YourGame" --system SYS --reset
```

## Maintenance

Profiles are reviewed quarterly by the JukaMix maintainers. Outdated or broken profiles are flagged and may be removed if unresponsive after 30 days.

---

*Last updated: 2026-08-17*
*For questions, join the [JukaMix Discord](https://discord.gg/R9qgJjh5jG)*
