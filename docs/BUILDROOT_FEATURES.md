# JukaMix Buildroot Features

## Overview

JukaMix Buildroot provides a complete chroot environment for TrimUI devices with modern libraries, GPU passthrough, audio support, input device forwarding, and persistent package installation.

## Supported Devices

| Device | SoC | RAM | GPU | Tier | Features |
|--------|-----|-----|-----|------|----------|
| **TG5050 (Smart Pro S)** | A523 | 2GB | Mali-G57 | Full | GPU, Audio, Input, QT6, Wayland |
| **TSP (Smart Pro)** | A133 | 1GB | Mali-G31 | Minimal | GPU, Audio, Input, Modern libs |
| **Brick** | A133 | 1GB | Mali-G31 | Minimal | GPU, Audio, Input, Modern libs |

## Features

### 1. GPU Passthrough

Automatically detects and passes through Mali GPU devices for hardware-accelerated graphics.

**Supported devices:**
- `/dev/mali0`, `/dev/mali`, `/dev/mali_*`
- `/dev/dri/*` (DRI devices)
- `/dev/dma_heap/system` (DMA-BUF)

**Environment variables set:**
```bash
MALI_PLATFORM="wayland"
EGL_PLATFORM="wayland"
GBM_BACKEND="mali"
MESA_GL_VERSION_OVERRIDE=3.2
MESA_GLSL_VERSION_OVERRIDE=150
vblank_mode=0
__GL_SYNC_TO_VBLANK=0
```

**Usage:**
```bash
# Check GPU status
chroot-manager.sh diagnose

# GPU is automatically mounted when chroot starts
chroot-manager.sh start
```

### 2. Audio Passthrough

Automatically mounts ALSA/PulseAudio/PipeWire devices for sound in chroot.

**Supported devices:**
- `/dev/snd/*` (ALSA devices)
- `/run/user/0/pulse/native` (PulseAudio)
- `/run/user/0/pipewire-0` (PipeWire)

**Environment variables set:**
```bash
AUDIODEV="/dev/snd/"
SDL_AUDIODRIVER="alsa"
ALSA_CARD="default"
```

**Usage:**
```bash
# Check audio status
chroot-manager.sh diagnose

# Audio is automatically mounted when chroot starts
chroot-manager.sh start
```

### 3. Input Device Forwarding

Forwards all input devices (gamepad, touchscreen, buttons) to chroot.

**Supported devices:**
- `/dev/input/event*` (evdev devices)
- `/dev/input/mouse*` (mouse devices)
- `/dev/uinput` (virtual input)

**Gamepad mapping:**
- TrimUI Smart Pro / Brick / Smart Pro S gamepad automatically mapped
- SDL GameController DB included

**Usage:**
```bash
# Check input devices
chroot-manager.sh diagnose

# Input devices are automatically mounted when chroot starts
chroot-manager.sh start
```

### 4. OverlayFS (Persistent Changes)

Enable overlayfs to persist package installations and configuration changes across chroot restarts.

**How it works:**
- Lower layer: Original rootfs (read-only)
- Upper layer: Changes stored in `/tmp/jukamix-overlay/upper`
- Work layer: Overlay metadata in `/tmp/jukamix-overlay/work`

**Usage:**
```bash
# Enable overlay (persist changes)
chroot-manager.sh overlay enable

# Install packages (will persist)
chroot-manager.sh run "apt-get install -y vim"

# Disable overlay (clean state)
chroot-manager.sh overlay disable
```

**Note:** Changes are lost when overlay is disabled or system reboots. Use profiles to save important settings.

### 5. Memory Management

**Swap (TSP/Brick only):**
- Auto-creates 256MB swap file when RAM <= 1GB
- Disabled for TG5050 (has 2GB RAM)

**OOM Killer:**
- TG5050: Conservative (overcommit_memory=0, ratio=10)
- TSP/Brick: Aggressive (overcommit_memory=1, ratio=50)

**Cgroups:**
- TG5050: 1536MB memory limit
- TSP/Brick: 512MB memory limit

**Usage:**
```bash
# Check memory status
chroot-manager.sh status

# Monitor real-time memory usage
chroot-manager.sh monitor
```

### 6. Signal Handling

Graceful shutdown on SIGTERM, SIGINT, SIGHUP:
- Unmounts all filesystems
- Kills chroot processes
- Disables swap
- Cleans up state files

### 7. Zombie Process Reaping

Runs as PID 1 in chroot to reap zombie processes:
- Prevents zombie accumulation
- Automatic cleanup
- Minimal overhead

### 8. Environment Variable Forwarding

Forwards important environment variables from host to chroot:
- HOME, PATH, TERM, DISPLAY, USER, LANG, LC_ALL

### 9. Watchdog Service

Monitors chroot health and performs auto-recovery:
- Checks chroot process health
- Monitors memory usage
- Checks disk space
- Auto-cleans stale PID files

**Usage:**
```bash
# Start watchdog
chroot-manager.sh watchdog start

# Stop watchdog
chroot-manager.sh watchdog stop
```

### 10. Backup/Restore

Automatic backup of user data before major operations.

**Usage:**
```bash
# Backup user data
chroot-manager.sh backup

# List backups
chroot-manager.sh backups

# Restore from backup
chroot-manager.sh restore /mnt/SDCARD/System/backups/chroot/tg5050_20260820_173800
```

### 11. Profile System

Save and load game/app profiles with custom settings.

**Usage:**
```bash
# Save current profile
chroot-manager.sh profile save mygame

# Load profile
chroot-manager.sh profile load mygame

# List profiles
chroot-manager.sh profiles
```

## Command Reference

| Command | Description |
|---------|-------------|
| `start` | Start chroot environment |
| `stop` | Stop chroot environment |
| `status` | Show detailed status |
| `run <cmd>` | Run command in chroot |
| `shell` | Enter interactive shell |
| `optimize` | Apply device-specific optimizations |
| `diagnose` | Run health diagnostics |
| `install` | Extract rootfs to chroot |
| `download` | Download rootfs from release |
| `backup` | Backup user data |
| `restore <path>` | Restore user data |
| `profile load <n>` | Load game profile |
| `profile save <n>` | Save game profile |
| `profiles` | List available profiles |
| `monitor` | Monitor resource usage |
| `recover` | Attempt automatic recovery |
| `watchdog start` | Start watchdog service |
| `watchdog stop` | Stop watchdog service |
| `network setup` | Setup network access |
| `update` | Update rootfs |
| `cleanup` | Clean up storage |
| `overlay enable` | Enable overlayfs |
| `overlay disable` | Disable overlayfs |
| `backups` | List available backups |

## Examples

### Install and Use Python

```bash
# Start chroot
chroot-manager.sh start

# Install Python
chroot-manager.sh run "apt-get update && apt-get install -y python3"

# Enable overlay to persist installation
chroot-manager.sh overlay enable

# Run Python script
chroot-manager.sh run "python3 /mnt/SDCARD/Roms/script.py"
```

### Use GPU Acceleration

```bash
# Start chroot (GPU automatically mounted)
chroot-manager.sh start

# Run GPU-accelerated app
chroot-manager.sh run "glxgears"
```

### Backup Before Major Changes

```bash
# Backup current state
chroot-manager.sh backup

# Make changes
chroot-manager.sh run "apt-get install -y something"

# Restore if needed
chroot-manager.sh restore /mnt/SDCARD/System/backups/chroot/tg5050_20260820_173800
```

## Troubleshooting

### GPU Not Working

```bash
# Check GPU devices
chroot-manager.sh diagnose

# Verify GPU is mounted
ls -la /mnt/SDCARD/buildroot/<device>/dev/mali*

# Check GPU libraries
ls -la /mnt/SDCARD/buildroot/<device>/usr/lib/*mali*
```

### Audio Not Working

```bash
# Check ALSA devices
chroot-manager.sh diagnose

# Verify audio is mounted
ls -la /mnt/SDCARD/buildroot/<device>/dev/snd/

# Test audio
chroot-manager.sh run "aplay -l"
```

### Input Not Working

```bash
# Check input devices
chroot-manager.sh diagnose

# Verify input is mounted
ls -la /mnt/SDCARD/buildroot/<device>/dev/input/

# Test input
chroot-manager.sh run "evtest /dev/input/event0"
```

### Low Memory

```bash
# Check memory status
chroot-manager.sh status

# Monitor memory
chroot-manager.sh monitor

# Enable swap (TSP/Brick only)
chroot-manager.sh start  # Swap auto-enabled
```

### Corrupted Rootfs

```bash
# Run diagnostics
chroot-manager.sh diagnose

# Re-download rootfs
chroot-manager.sh download

# Re-install
chroot-manager.sh install
```

## Technical Details

### File Locations

**On device:**
```
/mnt/SDCARD/
├── buildroot/
│   ├── rootfs-tg5050.ext2      # TG5050 rootfs
│   ├── rootfs-tsp-brick.ext2   # TSP/Brick rootfs
│   ├── tg5050/                 # TG5050 chroot
│   │   ├── .running            # Running marker
│   │   ├── .overlay-active     # Overlay marker
│   │   ├── bin/                # Binaries
│   │   ├── lib/                # Libraries
│   │   ├── dev/                # Device nodes (GPU, audio, input)
│   │   └── mnt/SDCARD/         # User data
│   ├── tsp/                    # TSP chroot
│   └── brick/                  # Brick chroot
├── tools/
│   └── chroot-manager.sh       # Chroot manager
└── Apps/
    └── JukaMix Buildroot/
        └── launch.sh           # Control Center
```

**State files:**
```
/tmp/
├── jukamix-chroot.log         # Log file
├── jukamix-swap               # Swap file (TSP/Brick)
├── jukamix-cache/             # Cache directory
├── jukamix-overlay/
│   ├── upper/                 # Overlay upper layer
│   └── work/                  # Overlay work layer
├── jukamix-state/
│   └── manager.pid            # Manager PID
├── jukamix-chroot-watchdog.pid
└── jukamix-chroot-reaper.pid
```

### Memory Usage

| Device | RAM | Swap | Chroot Limit | Safe Apps |
|--------|-----|------|--------------|-----------|
| TG5050 | 2GB | None | 1536MB | QT6, Wayland, heavy apps |
| TSP | 1GB | 256MB | 512MB | Python, Node.js, light apps |
| Brick | 1GB | 256MB | 512MB | Python, Node.js, light apps |

### Performance Tips

1. **Use overlay for package installs** - Enables persistence without rebuilding rootfs
2. **Monitor memory** - Use `chroot-manager.sh monitor` to watch resource usage
3. **Backup before major changes** - Use `chroot-manager.sh backup`
4. **Use profiles** - Save/load settings for different games/apps
5. **Keep watchdog running** - Auto-recovery on crashes

## Known Limitations

1. **No kernel modules** - Cannot load kernel modules in chroot
2. **Limited networking** - No root access for advanced networking
3. **No systemd** - Uses simple init scripts
4. **Overlay volatility** - Changes lost on reboot (unless using persistent storage)

## Future Improvements

1. **Persistent overlay** - Store overlay on SD card
2. **GPU driver updates** - Custom Mali drivers
3. **Audio optimization** - Low-latency audio config
4. **Input customization** - Gamepad remapping
5. **Profile sharing** - Export/import profiles
