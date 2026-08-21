# Dual-Partition SD Card Architecture Proposal

**Date:** August 20, 2026  
**Status:** Proposal - Under Review  
**Context:** Suggestion to partition SD card into FAT32 + EXT4 for newer kernels/libraries

---

## Executive Summary

This proposal evaluates partitioning the SD card into FAT32 (boot/stock firmware) + EXT4 (modern OS with newer kernel/libraries) to enable running software that requires newer system libraries than the stock TrimUI firmware provides.

---

## Current Architecture

```
Current Single-Partition Layout:
├── FAT32 (entire SD card)
│   ├── System/          ← JukaMix OS files
│   ├── RetroArch/       ← Emulators + cores
│   ├── Emus/            ← Standalone emulators
│   ├── Apps/            ← Applications
│   ├── Roms/            ← User ROMs
│   ├── BIOS/            ← BIOS files
│   └── trimui/          ← Firmware/config
```

**Constraints:**
- Stock TrimUI bootloader reads only FAT32
- Kernel is minimal (~5.x) with limited libraries
- Memory footprint is small (TSP: 1GB, TG5050: 2GB, Brick: 1GB)
- No X11/Wayland/QT6 support from stock firmware

---

## Proposed Dual-Partition Architecture

```
Proposed Dual-Partition Layout:
├── Partition 1: FAT32 (boot, ~512MB)
│   ├── System/          ← Minimal boot files
│   ├── trimui/          ← Stock firmware config
│   └── boot/            ← Kernel + initrd
│
├── Partition 2: EXT4 (root, remaining space)
│   ├── usr/             ← Modern libraries (glibc 2.44+)
│   ├── lib/             ← Shared libraries
│   ├── opt/             ← Applications (QT6, etc.)
│   ├── etc/             ← System config
│   └── home/            ← User data (optional)
```

---

## Technical Analysis

### Advantages

| Benefit | Description |
|---------|-------------|
| **Modern Software** | Run apps requiring QT6, Wayland, newer glibc |
| **Better Performance** | EXT4 journaling, no FAT32 overhead |
| **Larger Files** | No FAT32 4GB file size limit |
| **Case Sensitivity** | EXT4 supports case-sensitive filenames |
| **Permissions** | Proper Unix permissions (vs FAT32's limited support) |
| **Knulli-like Features** | X11/Wayland support for desktop-class apps |

### Disadvantages

| Challenge | Description |
|-----------|-------------|
| **Complexity** | Dual-boot management, partition switching |
| **Memory Pressure** | Newer libraries need more RAM (TSP/Brick have 1GB) |
| **Stock Firmware Dependency** | Still need FAT32 for bootloader |
| **Storage Overhead** | Two kernels, two library sets |
| **Maintenance** | Must sync FAT32 + EXT4 partitions |
| **User Confusion** | Which partition am I running? |

---

## Implementation Options

### Option A: Overlay Mount (Recommended for v1)

```
Boot: Stock firmware (FAT32)
Root: Overlay EXT4 over FAT32 (union mount)
```

**Pros:** Minimal change, stock firmware still boots  
**Cons:** Limited by stock kernel capabilities

### Option B: Chroot/Proot Environment

```
Boot: Stock firmware (FAT32)
Run: Proot/chroot into EXT4 for modern apps
```

**Pros:** No kernel modification needed  
**Cons:** Performance overhead, compatibility issues

### Option C: Full Dual-Boot

```
Bootloader: Choose FAT32 or EXT4
Kernel: Different kernels per partition
```

**Pros:** Maximum flexibility  
**Cons:** Requires bootloader modification (may not be possible on TrimUI)

### Option D: Separate Boot + Root (Most Promising)

```
FAT32: Boot partition (kernel + initrd)
EXT4: Root filesystem (modern libraries)
```

**Pros:** Clean separation, stock bootloader compatibility  
**Cons:** Requires custom kernel build, initrd modification

---

## Memory Considerations

| Device | RAM | Available after boot | Can run QT6? |
|--------|-----|---------------------|--------------|
| TSP (A133) | 1 GB | ~400-500 MB | Marginal |
| TG5050 (A523) | 2 GB | ~1.2-1.5 GB | Feasible |
| Brick (A133) | 1 GB | ~400-500 MB | Marginal |

**Key Insight:** TG5050 (Smart Pro S) with 2GB RAM is the best candidate for modern software. TSP and Brick may struggle with memory-heavy apps.

---

## Recommended Approach

### Phase 1: EXT4 Data Partition (Immediate)

Add a second EXT4 partition for user data and applications that don't need new libraries:

```
FAT32: System + Emulators (stock)
EXT4: Apps + User Data (optional, mounted on demand)
```

**Implementation:** Simple mount script, no kernel changes needed.

### Phase 2: Chroot Environment (Medium-term)

Create a chroot environment in EXT4 for running modern apps:

```
FAT32: Stock firmware + JukaMix OS
EXT4: Chroot with glibc 2.44+, QT6, etc.
```

**Implementation:** Proot or chroot wrapper scripts.

### Phase 3: Custom Kernel (Long-term)

Build custom kernel with EXT4 boot support:

```
FAT32: Bootloader + kernel
EXT4: Full modern Linux root
```

**Implementation:** Requires kernel source, cross-compilation, bootloader modification.

---

## Example Implementation: Phase 1

### 1. Partition Script

```sh
#!/bin/sh
# partition_sd.sh - Create EXT4 data partition on SD card
# WARNING: This will modify the SD card layout

SD_CARD="${1:-/dev/mmcblk0}"
FAT32_END="${2:-4G}"  # First 4GB for FAT32

echo "Current layout:"
parted "$SD_CARD" print

echo "Creating new partition layout..."
parted "$SD_CARD" resizepart 1 "$FAT32_END"
parted "$SD_CARD" mkpart primary ext4 "$FAT32_END" 100%

echo "Formatting EXT4 partition..."
mkfs.ext4 -L JUKAMIX_DATA "${SD_CARD}p2"

echo "Done. Reboot to apply."
```

### 2. Mount Script

```sh
#!/bin/sh
# mount_data.sh - Mount EXT4 data partition

DATA_PARTITION="/dev/mmcblk0p2"
MOUNT_POINT="/mnt/data"

if ! mountpoint -q "$MOUNT_POINT"; then
    mkdir -p "$MOUNT_POINT"
    mount "$DATA_PARTITION" "$MOUNT_POINT"
    echo "Mounted EXT4 partition at $MOUNT_POINT"
fi

# Symlink user data directories
for dir in Apps Roms BIOS Saves; do
    if [ -d "$MOUNT_POINT/$dir" ] && [ ! -L "/mnt/SDCARD/$dir" ]; then
        mv "/mnt/SDCARD/$dir" "$MOUNT_POINT/$dir.bak" 2>/dev/null
        ln -sf "$MOUNT_POINT/$dir" "/mnt/SDCARD/$dir"
    fi
done
```

---

## Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|------------|
| Partition corruption | High | Regular backups, journaling |
| Boot failure | Critical | Keep FAT32 bootable, recovery partition |
| Memory exhaustion | Medium | OOM killer, swap on EXT4 |
| User confusion | Low | Clear documentation, UI indicators |

---

## Recommendation

**Start with Phase 1 (EXT4 Data Partition)** for immediate benefits:
- Larger storage for ROMs/apps
- Better performance for read-heavy operations
- Foundation for future phases

**Evaluate Phase 2 (Chroot)** after Phase 1 is stable:
- Test with TG5050 (2GB RAM) first
- Measure performance overhead
- Identify which apps benefit most

**Phase 3 (Custom Kernel)** only if Phases 1-2 prove valuable:
- Requires kernel development expertise
- Significant testing on all three devices
- May void warranty or cause boot issues

---

## References

- [Knulli Architecture](https://github.com/knulli-cfw/distribution)
- [TrimUI Firmware Info](https://github.com/trimui)
- [EXT4 on Embedded Linux](https://www.kernel.org/doc/html/latest/filesystems/ext4.html)
- [Proot for Chroot without Root](https://proot-me.github.io/)

---

*This proposal is a starting point for discussion. Implementation details should be refined based on actual device testing.*
