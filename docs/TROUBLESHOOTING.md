# Troubleshooting Guide

This guide covers common issues and solutions for JukaMix OS.

---

## Quick Fixes (Try These First)

1. **Power cycle:** Hold power button for 5 seconds, wait 10 seconds, power on
2. **Reboot:** Go to Settings → Reboot
3. **Check SD card:** Remove and reinsert the card
4. **Re-extract:** Download the latest release again and re-extract to the card

---

## Installation Issues

### Card Won't Format as FAT32

**Windows (cards over 32 GB):**
Windows only offers exFAT/NTFS for cards over 32 GB. Use one of these:
- [Rufus](https://rufus.ie) — Select "Non bootable" → "Small FAT32"
- [guiformat](https://www.ridgecrop.demon.co.uk/guiformat.htm) — Simple FAT32 formatter
- [Raspberry Pi Imager](https://www.raspberrypi.com/software/) — Has FAT32 option

**macOS:**
If Disk Utility won't show FAT32:
1. Click **View → Show All Devices**
2. Select the **physical disk** (not the volume)
3. Click **Erase**
4. Choose **MS-DOS (FAT32)**

**Linux:**
```bash
# Identify the card
lsblk

# Format (REPLACES ALL DATA!)
sudo mkfs.vfat -F 32 /dev/sdX1
```

---

### Archive Won't Extract Properly

**Cause:** Corrupted download or wrong extraction method.

**Fix:**
1. Re-download the archive from [Releases](https://github.com/jukaLang/JukaMix-OS/releases/latest)
2. Verify the file size matches what's shown on GitHub
3. Use [7-Zip](https://www.7-zip.org/) on Windows (preserves permissions)
4. Extract directly to the SD card root — **NOT into a subfolder**

---

### Card Shows "No Boot" or Device Won't Power On

**Cause:** Card not formatted correctly or archive extracted to wrong location.

**Fix:**
1. Remove the card
2. Format as FAT32 (see above)
3. Re-extract the archive **to the card root**
4. Verify you see `Apps/`, `Emus/`, `System/` at the card root (not in a subfolder)
5. Reinsert and try again

---

## Boot Issues

### Stock Launcher Appears Instead of JukaMix

**Cause:** SD card not set as boot source.

**Fix by device:**
- **Smart Pro:** Settings → Boot Source → SD Card
- **Smart Pro S:** Settings → Boot Source → SD Card
- **Brick/Brick Pro:** Boots from SD automatically (no setting needed)

If the option doesn't appear:
1. Remove SD card
2. Reformat and re-extract JukaMix
3. Try again

---

### Screen Flickering or Black Screen

**Cause:** Corrupted installation or conflicting settings.

**Fix:**
1. Power off (hold power for 5 seconds)
2. Remove SD card
3. On a computer, delete these files from the card:
   - `System/usr/trimui/jukamix-version.txt`
   - `System/etc/jukamix/jukamix.json` (if it exists)
4. Reinsert card and power on

If this persists:
1. Re-extract the entire JukaMix archive to the card
2. Check for download corruption (re-download if needed)

---

### Firmware Update Stuck or Failed

**Cause:** Interrupted firmware update.

**Fix:**
1. **Do NOT** remove the card or turn off the device during update
2. If the device is stuck:
   - Hold power for 10 seconds to force shutdown
   - Wait 30 seconds
   - Power on again — the firmware update should resume
3. If it fails repeatedly:
   - Remove the SD card
   - Reformat and re-extract JukaMix
   - Try again

---

### Menu Loads But Is Unresponsive

**Cause:** System initialization incomplete or corrupted config.

**Fix:**
1. Power off and on
2. Wait 2-3 minutes for full initialization
3. If still unresponsive:
   - Remove SD card
   - Delete `System/etc/jukamix/` folder on the card
   - Reinsert and power on

---

### Smart Pro S: Buttons Dead, Then White Screen Crash

**Symptom:** On the **Smart Pro S (TSPS / TG5050)**, the menu loads but the
D-pad and face buttons do nothing — only **Home, Power, Volume, and Fn**
respond. After roughly 30 seconds the screen shows a white screen with
horizontal lines and the device powers off.

**Cause:** Some releases shipped the **Smart Pro (A133)** input daemon for the
Smart Pro S as well. The two devices use different SoCs (A133 vs A523), so the
daemon does not translate gamepad events — only the kernel-handled keys still
work — and the mismatched daemon can crash the display.

**Fix:**
1. **Update JukaMix** to a release that uses the device's own firmware input
   daemon on the Smart Pro S (fixed in current releases).
2. **Force shutdown:** hold Power for 10 seconds.
3. **Confirm the hardware is fine:** remove the SD card and power on without it.
   The stock firmware should respond to the D-pad and face buttons normally.
4. **Manual workaround (if you can't update):**
   - Delete `trimui/app/trimui_inputd` from the SD card so the device falls back
     to its built-in input daemon.
   - Reinsert the card and power on.
5. **If it still fails:** report your model and firmware version as described
   below.

---

## Game Issues

### Games Not Showing Up

**Cause:** ROMs in wrong folder or wrong file extension.

**Fix:**
1. Verify ROMs are in the correct `Roms/<SYSTEM>/` folder
2. Check file extensions:
   | System | Extensions |
   |--------|------------|
   | GBA | `.gba` |
   | NES | `.nes` |
   | SNES | `.sfc`, `.smc` |
   | N64 | `.n64`, `.z64`, `.v64` |
   | PS1 | `.bin`, `.cue`, `.iso` |
   | PSP | `.iso`, `.cso` |
   | NDS | `.nds` |
   | DC | `.cdi`, `.gdi`, `.chd` |
3. Restart the emulator launcher
4. Check `Emus/<platform>/config.json` for supported extensions

---

### Game Crashes or Won't Launch

**Cause:** Missing BIOS, bad ROM, or wrong emulator settings.

**Fix:**
1. **Check BIOS:**
   - PS1 needs `scph1001.bin` (or similar) in `BIOS/`
   - Dreamcast needs `dc_boot.bin` and `dc_flash.bin` in `BIOS/`
2. **Test the ROM:**
   - Try a different ROM of the same game
   - Check if the ROM works on another emulator
3. **Check emulator settings:**
   - Go to **Emus → <System> → config.json**
   - Verify the emulator path is correct
4. **Try a different emulator:**
   - Some games work better with specific cores
   - Check community recommendations on Discord

---

### Game Runs Slow or Laggy

**Cause:** Device can't handle the game at full speed.

**Fix:**
1. **Check device capabilities:**
   - TSP/TSPS: Most PS1, N64, PSP games run well
   - Brick: Some demanding games may lag
2. **Use performance profiles:**
   - Check `Profiles/<system>/<game>.cfg` for optimized settings
   - Create custom profiles in **System Tools → Performance Profiles**
3. **Adjust emulator settings:**
   - Reduce internal resolution
   - Enable frameskip
   - Disable optional features
4. **Check CPU governor:**
   - Go to **System Tools → CPU Governor**
   - Set to "performance" for demanding games

---

### Sound Stuttering or No Audio

**Cause:** Audio settings or driver issues.

**Fix:**
1. Check volume isn't muted (volume buttons)
2. Go to **Settings → Sound** and verify levels
3. Restart the emulator
4. Try a different audio driver in emulator settings
5. Check if headphones are connected (some devices mute speakers with headphones)

---

### Controls Not Working

**Cause:** Controller mapping issues.

**Fix:**
1. **Check physical controls:**
   - Test all buttons in **System Tools → Controller Test**
   - Ensure no buttons are stuck
2. **Remap controls:**
   - Use the **Key Remapper** app
   - Reset to default if needed
3. **Check emulator input settings:**
   - Some emulators have custom input configs
   - Look for `*.cfg` files in `Emus/<system>/`
4. **Try a different controller:**
   - Bluetooth controllers may need pairing
   - USB controllers may need drivers

---

### Save Games Not Working

**Cause:** Save path issues or permissions.

**Fix:**
1. **Check save directory:**
   - Saves go to `Saves/<SYSTEM>/`
   - Ensure the folder exists
2. **Check permissions:**
   - Saves should be writable
   - Try creating a test file manually
3. **Check emulator settings:**
   - Some emulators have custom save paths
   - Verify in `Emus/<system>/config.json`
4. **Use Save Vault:**
   - Go to **System Tools → Save Vault**
   - Backup and restore saves from there

---

## Network Issues

### Wi-Fi Won't Connect

**Fix:**
1. Go to **Settings → Wi-Fi**
2. Select your network and enter password
3. If it fails:
   - Toggle Wi-Fi off and on
   - Reboot the device
   - Check if your router uses 2.4GHz (5GHz may not be supported)
4. If still failing:
   - Forget the network and re-add it
   - Check if MAC filtering is enabled on your router
   - Try a different network

---

### Can't Download Updates

**Fix:**
1. Ensure Wi-Fi is connected
2. Check internet access (open a browser if available)
3. Try a different network
4. Download manually on a computer and copy to SD card

---

### Bluetooth Controller Won't Pair

**Fix:**
1. Put controller in pairing mode
2. Go to **Settings → Bluetooth**
3. Scan for devices
4. Select your controller
5. If it fails:
   - Ensure controller is in correct mode (some need specific button combos)
   - Move controller closer to the device
   - Restart Bluetooth on both devices

---

## Performance Issues

### Device Feels Slow Overall

**Fix:**
1. **Close background apps:**
   - Go to **System Tools → Running Apps**
   - Close unnecessary apps
2. **Clear cache:**
   - Go to **System Tools → Storage Cleaner**
   - Clean temporary files
3. **Check storage:**
   - Ensure at least 10% free space
   - Move some ROMs to a different card
4. **Restart the device:**
   - Sometimes a fresh start helps

---

### Battery Drains Quickly

**Fix:**
1. **Check battery health:**
   - Go to **System Tools → System Health**
   - Check battery percentage and health
2. **Reduce brightness:**
   - Lower screen brightness in Settings
3. **Disable Wi-Fi/Bluetooth:**
   - Turn off when not in use
4. **Use eco mode:**
   - Go to **System Tools → Performance Profiles**
   - Select "Eco" mode
5. **Check for background apps:**
   - Some apps may run continuously

---

### Device Overheats

**Fix:**
1. **Stop playing immediately** if the device feels hot
2. **Let it cool down** for 10-15 minutes
3. **Check for demanding games:**
   - Some games require more processing power
   - Use performance profiles to limit CPU speed
4. **Improve ventilation:**
   - Don't play in direct sunlight
   - Keep the device in a cool environment
5. **Check for background apps:**
   - Close any unnecessary apps

---

## System Issues

### "JukaMix Version" Not Showing

**Fix:**
1. Check if `System/usr/trimui/jukamix-version.txt` exists on the card
2. If missing, re-extract the JukaMix archive
3. If corrupted, delete and re-extract

---

### Settings Not Saving

**Fix:**
1. Check SD card write protection (physical switch on some cards)
2. Ensure card has free space
3. Try a different SD card
4. Check if settings file is corrupted

---

### Can't Access System Tools

**Fix:**
1. Check if `Apps/SystemTools/` exists on the card
2. If missing, re-extract the JukaMix archive
3. Try launching from **Apps** menu directly

---

### USB Connection Not Working

**Fix:**
1. Try a different USB cable
2. Check if the device is in USB mode
3. Restart the device
4. Try a different USB port on your computer

---

## Getting More Help

If your issue isn't covered here:

1. **Check the Discord:** [Join the community](https://discord.gg/R9qgJjh5jG)
2. **Search GitHub Issues:** [Known bugs and fixes](https://github.com/jukaLang/JukaMix-OS/issues)
3. **Read the Wiki:** [Community documentation](https://github.com/jukaLang/JukaMix-OS/wiki)
4. **Export diagnostics:** Run `scripts/diagnostics.sh` on your device and share the output

When reporting issues, please include:
- JukaMix version (from **System Info**)
- Device model (Smart Pro, Smart Pro S, Brick, or Brick Pro)
- Firmware version
- Exact steps to reproduce
- Expected vs. actual behavior
- Any error messages

---

## Emergency Recovery

If your device is completely unresponsive:

1. **Force shutdown:** Hold power button for 10 seconds
2. **Remove SD card**
3. **Power on without card** — device should boot to stock firmware
4. **On a computer:**
   - Reformat the SD card as FAT32
   - Re-extract JukaMix archive
5. **Reinsert card and power on**

If stock firmware won't boot:
1. Contact TrimUI support
2. Check if firmware update is needed
3. Visit [Discord](https://discord.gg/R9qgJjh5jG) for help
