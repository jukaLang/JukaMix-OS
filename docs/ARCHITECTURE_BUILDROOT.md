# Buildroot Integration Proposal

**Date:** August 20, 2026  
**Status:** Proposal - Under Review  
**Goal:** Use Buildroot to compile modern libraries for TrimUI devices

---

## Executive Summary

Buildroot can create minimal, optimized Linux systems with modern toolchains and libraries, solving the "old libraries" problem on TrimUI devices. This proposal evaluates how to integrate Buildroot with JukaMix OS while maintaining compatibility with the stock firmware bootloader.

---

## Current Problem

```
Stock TrimUI Firmware:
├── Kernel: ~5.x (old, limited features)
├── glibc: ~2.17 (old, missing modern APIs)
├── Libraries: Minimal (no X11/Wayland/QT6)
└── Userspace: Limited to stock apps
```

**Result:** Cannot run modern software requiring newer glibc, QT6, Wayland, etc.

---

## Buildroot Solution

Buildroot can compile:

| Component | What it provides |
|-----------|------------------|
| **Toolchain** | Modern GCC 13+, glibc 2.44, binutils |
| **Root Filesystem** | Complete Linux userspace with custom packages |
| **Libraries** | QT6, Wayland, X11, OpenSSL 3.x, etc. |
| **Kernels** | Custom kernels with EXT4, overlayfs, etc. |
| **Optimization** | Stripped binaries, static linking where needed |

---

## Integration Options

### Option A: Full Buildroot Replacement (Nuclear)

```
Replace entire stock firmware with Buildroot-built system
```

**Structure:**
```
SD Card (single partition, EXT4):
├── boot/           ← Kernel + initrd
├── usr/            ← Buildroot-built libraries
├── lib/            ← Shared libraries
├── etc/            ← System config
└── home/           ← User data
```

**Pros:**
- Complete control over entire system
- Modern kernel + libraries everywhere
- No stock firmware dependency

**Cons:**
- Stock bootloader may not support EXT4 boot
- Requires bootloader modification (may not be possible)
- Completely replaces TrimUI's firmware (brick risk)
- Must reimplement all TrimUI-specific features (input, display, power)

**Verdict:** Too risky, likely impossible without TrimUI SDK/bootloader access

---

### Option B: Buildroot Overlay on FAT32 (Recommended)

```
Keep stock firmware (FAT32), mount Buildroot overlay
```

**Structure:**
```
SD Card (FAT32, same as current):
├── System/         ← JukaMix OS (current)
├── RetroArch/      ← Emulators (current)
├── Emus/           ← Standalone emulators (current)
├── buildroot/      ← Buildroot root filesystem
│   ├── usr/        ← Modern libraries
│   ├── lib/        ← Shared libraries
│   └── etc/        ← Config
└── overlay.sh      ← Mount script
```

**Boot Flow:**
1. Stock firmware boots from FAT32
2. JukaMix OS initializes normally
3. `overlay.sh` mounts Buildroot filesystem via overlayfs or chroot
4. Modern apps run from Buildroot environment

**Pros:**
- Keeps stock bootloader (no modification needed)
- Maintains full JukaMix OS compatibility
- Modern libraries available via overlay
- Can be optional (users choose to enable)

**Cons:**
- Memory overhead (two root filesystems)
- Complexity of overlay/chroot management
- Some apps may not work in overlay environment

---

### Option C: Chroot/Proot Environment (Safest)

```
Buildroot-built chroot within stock firmware
```

**Structure:**
```
SD Card (FAT32):
├── System/         ← JukaMix OS (current)
├── RetroArch/      ← Emulators (current)
├── Emus/           ← Standalone emulators (current)
├── chroot/         ← Buildroot chroot environment
│   ├── bin/        ← Modern binaries
│   ├── usr/        ← Modern libraries
│   ├── lib/        ← Shared libraries
│   └── etc/        ← Config
└── launch-chroot.sh ← Wrapper script
```

**Usage:**
```bash
# Run a modern app in chroot
./launch-chroot.sh /path/to/modern-app

# Example: Run QT6 app
./launch-chroot.sh /usr/bin/qt6-app
```

**Pros:**
- Safest approach (no kernel/bootloader changes)
- Easy to enable/disable
- Can run multiple chroot environments
- Proot option (no root required)

**Cons:**
- Performance overhead (5-15% typical)
- Some system calls may not work
- Memory usage (chroot shares kernel, but libraries duplicated)

---

### Option D: Separate EXT4 Partition (Balanced)

```
FAT32 (boot) + EXT4 (Buildroot root)
```

**Structure:**
```
SD Card (two partitions):
├── Partition 1: FAT32 (boot, ~512MB)
│   ├── System/     ← JukaMix OS boot files
│   └── trimui/     ← Stock firmware config
│
└── Partition 2: EXT4 (root, remaining space)
    ├── boot/       ← Kernel + initrd
    ├── usr/        ← Modern libraries
    ├── lib/        ← Shared libraries
    └── etc/        ← System config
```

**Boot Flow:**
1. Stock firmware reads FAT32 partition
2. Custom initrd mounts EXT4 partition as root
3. Modern Linux system runs from EXT4
4. Can mount FAT32 for user data (Roms, BIOS, etc.)

**Pros:**
- Full modern Linux system
- Clean separation (boot vs root)
- Can still access FAT32 for user data

**Cons:**
- Requires custom initrd (kernel modification)
- Stock bootloader may not support multi-partition
- Complex setup and maintenance

---

## Buildroot Configuration

### Recommended Target: TrimUI Smart Pro S (TG5050)

The TG5050 (2GB RAM, A523 SoC) is the best candidate for Buildroot:

```bash
# Buildroot config for TrimUI TG5050
BR2_aarch64=y
BR2_cortex_a53=y
BR2_KERNEL_LINUX_CUSTOM=y
BR2_PACKAGE_GLIBC_2_44=y
BR2_PACKAGE_QT6=y
BR2_PACKAGE_WAYLAND=y
BR2_PACKAGE_MESA3D=y
BR2_TARGET_ROOTFS_EXT2=y
BR2_TARGET_ROOTFS_EXT2_SIZE="1G"
```

### Essential Packages

| Package | Why needed |
|---------|-----------|
| `glibc` (2.44) | Modern C library |
| `gcc` (13+) | Compiler for native apps |
| `qt6-base` | QT6 framework |
| `wayland` | Wayland display server |
| `mesa3d` | OpenGL ES 3.2 |
| `openssl` (3.x) | Modern TLS |
| `curl` | HTTP client |
| `python3` (3.12) | Modern Python |
| `nodejs` (20 LTS) | JavaScript runtime |

---

## Implementation Plan

### Phase 1: Multi-Device Buildroot (Immediate)

Build root filesystems for all three devices:

```bash
# 1. Clone Buildroot
git clone https://github.com/buildroot/buildroot.git
cd buildroot

# 2. Create configs for each device
mkdir -p configs/trimui

# TG5050 config (Full tier)
cp configs/qemu_aarch64_defconfig configs/trimui/tg5050_defconfig
# Edit: enable QT6, Wayland, Mesa3D

# TSP/Brick config (Minimal tier)
cp configs/qemu_aarch64_defconfig configs/trimui/tsp_brick_defconfig
# Edit: disable QT6/Wayland, smaller rootfs

# 3. Build for each device
make trimui_tg5050_defconfig -j$(nproc)
make -j$(nproc)
cp output/images/rootfs.ext2 ../rootfs-tg5050.ext2

make trimui_tsp_brick_defconfig -j$(nproc)
make -j$(nproc)
cp output/images/rootfs.ext2 ../rootfs-tsp-brick.ext2

# 4. Test on devices
# Copy appropriate rootfs to each device's SD card
```

### Phase 2: Device-Aware Chroot Integration (Medium-term)

Create device-aware chroot wrapper:

```bash
#!/bin/sh
# launch-chroot.sh - Device-aware Buildroot chroot

# Detect device
DEVICE=$(cat /etc/trimui_device.txt 2>/dev/null | tr -d '[:space:]')

# Select appropriate rootfs
case "$DEVICE" in
    tg5050)
        CHROOT_DIR="/mnt/SDCARD/chroot-tg5050"  # Full tier
        MAX_MEMORY="1500"  # MB
        ;;
    tsp|brick)
        CHROOT_DIR="/mnt/SDCARD/chroot-minimal"  # Minimal tier
        MAX_MEMORY="500"   # MB
        ;;
    *)
        echo "Unknown device: $DEVICE" >&2
        exit 1
        ;;
esac

APP="$@"

# Check available memory
FREE_MEM=$(free -m | awk '/Mem:/ {print $7}')
if [ "$FREE_MEM" -lt "$MAX_MEMORY" ]; then
    echo "Warning: Low memory ($FREE_MEM MB free, need $MAX_MEMORY MB)" >&2
    echo "Some apps may not work correctly." >&2
fi

# Mount necessary filesystems
mount --bind /dev "$CHROOT_DIR/dev"
mount --bind /proc "$CHROOT_DIR/proc"
mount --bind /sys "$CHROOT_DIR/sys"
mount --bind /tmp "$CHROOT_DIR/tmp"

# Mount user data
mount --bind /mnt/SDCARD/Roms "$CHROOT_DIR/mnt/Roms"
mount --bind /mnt/SDCARD/BIOS "$CHROOT_DIR/mnt/BIOS"

# Enter chroot
chroot "$CHROOT_DIR" /bin/bash -c "$APP"

# Cleanup
umount "$CHROOT_DIR/dev"
umount "$CHROOT_DIR/proc"
umount "$CHROOT_DIR/sys"
umount "$CHROOT_DIR/tmp"
umount "$CHROOT_DIR/mnt/Roms"
umount "$CHROOT_DIR/mnt/BIOS"
```

### Phase 3: Overlay Integration (Long-term)

Full overlayfs integration:

```bash
#!/bin/sh
# overlay-buildroot.sh - Mount Buildroot as overlay

BUILDROOT="/mnt/SDCARD/buildroot"
OVERLAY="/tmp/buildroot-overlay"

# Create overlay mount point
mkdir -p "$OVERLAY"

# Mount Buildroot root as lower layer
mount -t ext4 "$BUILDROOT/rootfs.ext2" /mnt/buildroot-root

# Create overlay (stock firmware as lower, Buildroot as upper)
mount -t overlay overlay \
    -o lowerdir=/,upperdir=/mnt/buildroot-root \
    "$OVERLAY"

# Switch root (optional, risky)
# exec switch_root "$OVERLAY" /sbin/init
```

---

## Device Support Matrix

| Device | SoC | RAM | GPU | Buildroot Tier | What Runs |
|--------|-----|-----|-----|----------------|-----------|
| **TG5050 (Smart Pro S)** | A523 (Octa-core) | 2 GB | Mali-G57 | **Full** | QT6, Wayland, X11, modern apps |
| **TSP (Smart Pro)** | A133 (Single-core) | 1 GB | Mali-G31 | **Minimal** | Basic libs, no QT6/Wayland |
| **Brick** | A133 (Single-core) | 1 GB | Mali-G31 | **Minimal** | Basic libs, no QT6/Wayland |

### Hardware Comparison

| Feature | TSP/Brick (A133) | TG5050 (A523) |
|---------|------------------|---------------|
| CPU Cores | 1x A53 @ 1.8GHz | 8x A53/A73 @ 2.0GHz |
| RAM | 1 GB | 2 GB |
| GPU | Mali-G31 (ES 3.2) | Mali-G57 (ES 3.2, Vulkan) |
| Best For | Retro emulators | Modern apps, QT6, Wayland |

### Buildroot Configurations

**TG5050 (Full Tier):**
```bash
BR2_aarch64=y
BR2_cortex_a73=y  # A523 has A73 cores
BR2_PACKAGE_GLIBC_2_44=y
BR2_PACKAGE_QT6=y
BR2_PACKAGE_WAYLAND=y
BR2_PACKAGE_MESA3D=y
BR2_TARGET_ROOTFS_EXT2_SIZE="1G"
```

**TSP/Brick (Minimal Tier):**
```bash
BR2_aarch64=y
BR2_cortex_a53=y
BR2_PACKAGE_GLIBC_2_44=y
BR2_PACKAGE_QT6=n      # Too heavy for 1GB
BR2_PACKAGE_WAYLAND=n   # Too heavy for 1GB
BR2_PACKAGE_MESA3D=y    # Basic OpenGL ES
BR2_TARGET_ROOTFS_EXT2_SIZE="512M"  # Smaller footprint
```

### Memory Strategy

| Device | Available RAM | Chroot Overhead | Can Run Modern Apps? |
|--------|---------------|-----------------|----------------------|
| TG5050 | ~1.5 GB | 200-300 MB | ✅ Yes (QT6, Wayland) |
| TSP | ~600 MB | 150-200 MB | ⚠️ Limited (basic libs only) |
| Brick | ~600 MB | 150-200 MB | ⚠️ Limited (basic libs only) |

**Key Insight:** TG5050 gets full modern stack. TSP/Brick get modern glibc/libraries but NOT QT6/Wayland (too memory-heavy).

---

## App Compatibility by Device Tier

| App Type | TG5050 (Full) | TSP/Brick (Minimal) |
|----------|---------------|---------------------|
| Modern glibc apps | ✅ Yes | ✅ Yes |
| QT6 apps | ✅ Yes | ❌ No (too heavy) |
| Wayland apps | ✅ Yes | ❌ No (too heavy) |
| X11 apps | ✅ Yes | ⚠️ Limited |
| Python 3.12 | ✅ Yes | ✅ Yes |
| Node.js 20 | ✅ Yes | ✅ Yes |
| Docker (rootless) | ⚠️ Experimental | ❌ No |
| OpenGL ES 3.2 | ✅ Yes | ✅ Yes |
| Vulkan | ✅ Yes (Mali-G57) | ❌ No (Mali-G31) |

## Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|------------|
| Memory exhaustion | High | OOM killer, swap, limit chroot apps |
| Boot failure | Critical | Keep stock firmware untouched |
| Compatibility issues | Medium | Test thoroughly, fallback to stock |
| Storage overhead | Low | TG5050: ~500MB, TSP/Brick: ~250MB |
| GPU limitations | Medium | Disable GPU-heavy features on TSP/Brick |

---

## Recommended Approach

**Multi-Device Chroot Strategy:**

| Device | Strategy | What Users Get |
|--------|----------|----------------|
| **TG5050** | Full Buildroot chroot | QT6, Wayland, modern GUI apps |
| **TSP** | Minimal Buildroot chroot | Modern glibc, Python, Node.js |
| **Brick** | Minimal Buildroot chroot | Modern glibc, Python, Node.js |

**Implementation Order:**

1. **Phase 1:** Build root filesystems for all three devices
2. **Phase 2:** Create device-aware chroot wrapper
3. **Phase 3:** Test with real apps (QT6 on TG5050, Python/Node on all)
4. **Phase 4:** Optimize memory usage per device

**Why chroot for all devices:**
- Safest (no kernel/bootloader changes)
- Device-appropriate (full tier for TG5050, minimal for TSP/Brick)
- Can be optional (users choose to enable)
- Modern glibc benefits all devices (better compatibility)

**Device-Specific Benefits:**

| Device | Before Buildroot | After Buildroot |
|--------|------------------|------------------|
| TG5050 | Old glibc, no QT6 | Modern glibc + QT6 + Wayland |
| TSP | Old glibc, limited apps | Modern glibc + Python 3.12 + Node.js 20 |
| Brick | Old glibc, limited apps | Modern glibc + Python 3.12 + Node.js 20 |

---

## Example Build Commands

### Build for All Three Devices

```bash
# Download Buildroot
wget https://buildroot.org/downloads/buildroot-2024.02.tar.xz
tar xf buildroot-2024.02.tar.xz
cd buildroot-2024.02

# --- TG5050 (Full Tier) ---
make qemu_aarch64_defconfig
make menuconfig
# Target: ARM aarch64, Cortex-A73
# Packages: enable glibc 2.44, QT6, Wayland, Mesa3D
# Rootfs: ext2, 1GB
make -j$(nproc)
cp output/images/rootfs.ext2 ../rootfs-tg5050.ext2

# --- TSP/Brick (Minimal Tier) ---
make qemu_aarch64_defconfig
make menuconfig
# Target: ARM aarch64, Cortex-A53
# Packages: enable glibc 2.44, disable QT6/Wayland
# Rootfs: ext2, 512MB
make -j$(nproc)
cp output/images/rootfs.ext2 ../rootfs-tsp-brick.ext2
```

### Test on Devices

```bash
# TG5050
cp rootfs-tg5050.ext2 /mnt/SDCARD/chroot-tg5050/
sudo chroot /mnt/SDCARD/chroot-tg5050 /bin/bash
# Should show: Modern Linux with QT6 support

# TSP/Brick
cp rootfs-tsp-brick.ext2 /mnt/SDCARD/chroot-minimal/
sudo chroot /mnt/SDCARD/chroot-minimal /bin/bash
# Should show: Modern Linux without QT6
```

---

## References

- [Buildroot Manual](https://buildroot.org/downloads/manual/manual.html)
- [Buildroot for ARM](https://buildroot.org/downloads/manual/manual.html#_toolchain)
- [TrimUI Device Info](https://github.com/trimui)
- [Chroot on Embedded Linux](https://www.kernel.org/doc/html/latest/filesystems/chroot.html)

---

*This proposal is a starting point. Implementation should begin with Phase 1 (Buildroot base system) and expand based on testing results.*
