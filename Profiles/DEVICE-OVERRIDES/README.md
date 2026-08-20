# JukaMix OS - Device Base Profiles

These base profiles define default settings for each supported device.
Game-specific profiles inherit from these and override only what's necessary.

---

## tg5050_base.cfg (TrimUI Smart Pro S)

```ini
# TrimUI Smart Pro S (TG5050) Base Profile
# Allwinner A523 SoC | Mali-G57 GPU | aarch64

[device_info]
code = tg5050
name = TrimUI Smart Pro S
soc = Allwinner A523
gpu = Mali-G57
architecture = aarch64
display_resolution = 1280x720
display_orientation = horizontal

[performance_limits]
cpu_governor_max = performance
cpu_freq_min = 408000
cpu_freq_max = 2400000
max_active_cores = 4
thermal_threshold_high = 85
thermal_threshold_medium = 75

[gpu_capabilities]
opengl_es_version = 3.2
vulkan_support = untested
max_texture_size = 4096
preferred_renderer = GLES2

[recommended_defaults]
cpu_governor = ondemand
cpu_min_freq = 816000
cpu_max_freq = 2000000
active_cores = 4
internal_resolution = 2x
texture_upscaling = enabled
anisotropic_filtering = 4
threaded_rendering = true
```

---

## tsp_base.cfg (TrimUI Smart Pro)

```ini
# TrimUI Smart Pro (TSP) Base Profile
# Allwinner A133 Plus SoC | Mali-G31 GPU | aarch64

[device_info]
code = tsp
name = TrimUI Smart Pro
soc = Allwinner A133 Plus
gpu = Mali-G31
architecture = aarch64
display_resolution = 1280x720
display_orientation = horizontal

[performance_limits]
cpu_governor_max = performance
cpu_freq_min = 408000
cpu_freq_max = 2000000
max_active_cores = 4
thermal_threshold_high = 85
thermal_threshold_medium = 75

[gpu_capabilities]
opengl_es_version = 3.1
vulkan_support = untested
max_texture_size = 2048
preferred_renderer = GLES2

[recommended_defaults]
cpu_governor = ondemand
cpu_min_freq = 816000
cpu_max_freq = 1800000
active_cores = 4
internal_resolution = 1x
texture_upscaling = disabled
anisotropic_filtering = 2
threaded_rendering = true
```

---

## brick_base.cfg (TrimUI Brick)

```ini
# TrimUI Brick Base Profile
# Allwinner A133 Plus SoC | Mali-G31 GPU | aarch64

[device_info]
code = brick
name = TrimUI Brick
soc = Allwinner A133 Plus
gpu = Mali-G31
architecture = aarch64
display_resolution = 1024x768
display_orientation = vertical

[performance_limits]
cpu_governor_max = performance
cpu_freq_min = 408000
cpu_freq_max = 2000000
max_active_cores = 4
thermal_threshold_high = 85
thermal_threshold_medium = 75

[gpu_capabilities]
opengl_es_version = 3.1
vulkan_support = untested
max_texture_size = 2048
preferred_renderer = GLES2

[recommended_defaults]
cpu_governor = conservative
cpu_min_freq = 600000
cpu_max_freq = 1608000
active_cores = 4
internal_resolution = 1x
texture_upscaling = disabled
anisotropic_filtering = 0
threaded_rendering = false
```

---

## How Base Profiles Work

1. **Device Detection**: At boot, `common_launcher.sh` reads `/etc/trimui_device.txt` to determine the device code (tg5050, tsp, or brick).

2. **Base Profile Loading**: The corresponding base profile is loaded from `Profiles/DEVICE-OVERRIDES/<device>_base.cfg`.

3. **Game Profile Override**: If a game-specific profile exists (`Profiles/<SYSTEM>/<GAME>.cfg`), it merges with the base profile, overriding only specified values.

4. **Fallback**: If no game profile exists, the base profile defaults are used.

## Editing Base Profiles

⚠️ **Warning**: Base profiles affect ALL games on the device. Only edit if you understand the implications.

To customize:
```sh
# Backup first!
cp /mnt/SDCARD/Profiles/DEVICE-OVERRIDES/tg5050_base.cfg /mnt/SDCARD/Profiles/DEVICE-OVERRIDES/tg5050_base.cfg.bak

# Edit
nano /mnt/SDCARD/Profiles/DEVICE-OVERRIDES/tg5050_base.cfg

# Test changes
/mnt/SDCARD/System/usr/trimui/scripts/validate_profile.sh /mnt/SDCARD/Profiles/DEVICE-OVERRIDES/tg5050_base.cfg
```

## Contributing Base Profile Improvements

If you've found better default settings for a device:

1. Test extensively across multiple game genres (platformers, RPGs, racing, fighters)
2. Document your testing methodology and results
3. Submit a PR with before/after performance comparisons
4. Include thermal/battery impact notes

---

*Last updated: 2026-08-17*
