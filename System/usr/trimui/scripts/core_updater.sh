#!/bin/sh
# core_updater.sh - Emulator Core Auto-Updater for JukaMix
# Downloads and updates RetroArch cores from buildbot

CORES_DIR="/mnt/SDCARD/RetroArch/.retroarch/cores"
BACKUP_DIR="/mnt/SDCARD/trimui/core_backups"
LOG_FILE="/tmp/core_updater.log"
BUILDBOT_URL="https://buildbot.libretro.com/nightly/linux/arm/v7a"

# Create directories
mkdir -p "$CORES_DIR" "$BACKUP_DIR" 2>/dev/null

# ── Logging ────────────────────────────────────────────────────────────
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [core_update] $1" >> "$LOG_FILE" 2>/dev/null
}

# ── Get available cores ────────────────────────────────────────────────
get_available_cores() {
    echo "Fetching available cores..."
    
    # List of commonly used cores
    cores="
    2048_libretro.so
    81_libretro.so
    a5200_libretro.so
    ardens_libretro.so
    arduous_libretro.so
    atari800_libretro.so
    bluemsx_libretro.so
    bnes_libretro.so
    cap32_libretro.so
    chailove_libretro.so
    crocods_libretro.so
    daphne_libretro.so
    desmume2015_libretro.so
    dosbox_libretro.so
    dosbox_pure_libretro.so
    duckstation_libretro.so
    easyrpg_libretro.so
    ecwolf_libretro.so
    fbalpha2012_libretro.so
    fbneo_libretro.so
    fceumm_libretro.so
    flycast_libretro.so
    fmsx_libretro.so
    freechaf_libretro.so
    freeintv_libretro.so
    fuse_libretro.so
    gambatte_libretro.so
    gearboy_libretro.so
    gearcoleco_libretro.so
    gearsystem_libretro.so
    genesis_plus_gx_libretro.so
    gme_libretro.so
    gpsp_libretro.so
    gw_libretro.so
    handy_libretro.so
    hatari_libretro.so
    libgametank_libretro.so
    lowresnx_libretro.so
    lutro_libretro.so
    mame2003_plus_libretro.so
    mednafen_lynx_libretro.so
    mednafen_ngp_libretro.so
    mednafen_pce_fast_libretro.so
    mednafen_pcfx_libretro.so
    mednafen_supafaust_libretro.so
    mednafen_supergrafx_libretro.so
    mednafen_vb_libretro.so
    mednafen_wswan_libretro.so
    melonds_libretro.so
    mesen_libretro.so
    meteor_libretro.so
    mgba_libretro.so
    mupen64plus_next_libretro.so
    neocd_libretro.so
    nestopia_libretro.so
    np2kai_libretro.so
    numero_libretro.so
    o2em_libretro.so
    opera_libretro.so
    parallel_n64_libretro.so
    pcsx_rearmed_libretro.so
    picodrive_libretro.so
    pokemini_libretro.so
    potator_libretro.so
    ppsspp_libretro.so
    prboom_libretro.so
    prosystem_libretro.so
    puae2021_libretro.so
    px68k_libretro.so
    quasi88_libretro.so
    quicknes_libretro.so
    race_libretro.so
    reminiscence_libretro.so
    sameboy_libretro.so
    scummvm_libretro.so
    snes9x_libretro.so
    snes9x2002_libretro.so
    snes9x2005_libretro.so
    snes9x2010_libretro.so
    stella_libretro.so
    stella2014_libretro.so
    swanstation_libretro.so
    tgbdual_libretro.so
    theodore_libretro.so
    tic80_libretro.so
    tyrquake_libretro.so
    uae4arm_libretro.so
    uzem_libretro.so
    vba_next_libretro.so
    vbam_libretro.so
    vecx_libretro.so
    vemulator_libretro.so
    vice_x128_libretro.so
    vice_x64_libretro.so
    vice_x64sc_libretro.so
    vice_xvic_libretro.so
    virtualjaguar_libretro.so
    wasm4_libretro.so
    x1_libretro.so
    xrick_libretro.so
    yabasanshiro_libretro.so
    yabause_libretro.so
    "
    
    echo "$cores" | tr -s ' ' '\n' | grep -v '^$'
}

# ── Download core ───────────────────────────────────────────────────────
download_core() {
    core_name="$1"
    
    # Check if core already exists
    core_file="$CORES_DIR/$core_name"
    if [ -f "$core_file" ]; then
        # Check if backup exists
        backup_file="$BACKUP_DIR/${core_name}.backup"
        if [ ! -f "$backup_file" ]; then
            # Create backup before updating
            cp "$core_file" "$backup_file" 2>/dev/null
        fi
    fi
    
    # Download core
    url="$BUILDBOT_URL/$core_name"
    echo "Downloading: $core_name"
    
    if command -v curl >/dev/null 2>&1; then
        curl -sS -L --fail -o "$core_file" "$url" 2>/dev/null
    elif command -v wget >/dev/null 2>&1; then
        wget -q -O "$core_file" "$url" 2>/dev/null
    else
        log "ERROR: No download tool available"
        return 1
    fi
    
    if [ $? -eq 0 ] && [ -f "$core_file" ]; then
        # Make executable
        chmod +x "$core_file" 2>/dev/null
        
        log "Downloaded: $core_name"
        echo "  [OK] $core_name"
        return 0
    else
        log "Failed to download: $core_name"
        echo "  [FAIL] $core_name"
        
        # Restore backup if exists
        backup_file="$BACKUP_DIR/${core_name}.backup"
        if [ -f "$backup_file" ]; then
            cp "$backup_file" "$core_file" 2>/dev/null
            echo "  [RESTORED] $core_name from backup"
        fi
        
        return 1
    fi
}

# ── Update all cores ────────────────────────────────────────────────────
update_all_cores() {
    echo "Updating all cores..."
    echo ""
    
    # Get list of cores to update
    cores=$(get_available_cores)
    
    downloaded=0
    failed=0
    
    for core in $cores; do
        if download_core "$core"; then
            downloaded=$((downloaded + 1))
        else
            failed=$((failed + 1))
        fi
    done
    
    echo ""
    echo "Update complete!"
    echo "Downloaded: $downloaded"
    echo "Failed: $failed"
    
    log "Update complete: $downloaded downloaded, $failed failed"
}

# ── Update specific core ────────────────────────────────────────────────
update_core() {
    core_name="$1"
    
    if [ -z "$core_name" ]; then
        echo "Usage: core_updater.sh update <core_name>"
        return 1
    fi
    
    # Add .so extension if missing
    case "$core_name" in
        *_libretro.so) ;;
        *) core_name="${core_name}_libretro.so" ;;
    esac
    
    download_core "$core_name"
}

# ── Restore core from backup ────────────────────────────────────────────
restore_core() {
    core_name="$1"
    
    if [ -z "$core_name" ]; then
        echo "Usage: core_updater.sh restore <core_name>"
        return 1
    fi
    
    # Add .so extension if missing
    case "$core_name" in
        *_libretro.so) ;;
        *) core_name="${core_name}_libretro.so" ;;
    esac
    
    backup_file="$BACKUP_DIR/${core_name}.backup"
    core_file="$CORES_DIR/$core_name"
    
    if [ -f "$backup_file" ]; then
        cp "$backup_file" "$core_file" 2>/dev/null
        echo "Restored: $core_name"
        log "Restored: $core_name from backup"
        return 0
    else
        echo "No backup found for: $core_name"
        return 1
    fi
}

# ── List installed cores ────────────────────────────────────────────────
list_installed_cores() {
    echo "Installed Cores:"
    echo "================"
    echo ""
    
    count=0
    for core in "$CORES_DIR"/*_libretro.so; do
        [ -f "$core" ] || continue
        
        core_name=$(basename "$core")
        core_size=$(du -h "$core" | cut -f1)
        core_date=$(stat -c %y "$core" 2>/dev/null | cut -d'.' -f1)
        
        # Check if backup exists
        backup_exists="No"
        if [ -f "$BACKUP_DIR/${core_name}.backup" ]; then
            backup_exists="Yes"
        fi
        
        echo "  $core_name"
        echo "    Size: $core_size"
        echo "    Date: $core_date"
        echo "    Backup: $backup_exists"
        echo ""
        
        count=$((count + 1))
    done
    
    echo "Total: $count cores installed"
}

# ── Check for updates ───────────────────────────────────────────────────
check_updates() {
    echo "Checking for core updates..."
    echo ""
    
    # This would compare local vs remote versions
    # For now, just list installed cores
    list_installed_cores
    
    echo ""
    echo "Note: Automatic version checking not yet implemented."
    echo "Use 'update-all' to download latest versions."
}

# ── Main ───────────────────────────────────────────────────────────────
case "${1:-}" in
    update-all)
        update_all_cores
        ;;
    update)
        update_core "${2:-}"
        ;;
    restore)
        restore_core "${2:-}"
        ;;
    list)
        list_installed_cores
        ;;
    check)
        check_updates
        ;;
    *)
        echo "Emulator Core Auto-Updater"
        echo "Usage: core_updater.sh {update-all|update|restore|list|check}"
        echo ""
        echo "Commands:"
        echo "  update-all           - Update all cores"
        echo "  update <core>        - Update specific core"
        echo "  restore <core>       - Restore core from backup"
        echo "  list                 - List installed cores"
        echo "  check                - Check for updates"
        ;;
esac
