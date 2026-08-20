#!/bin/sh
# JukaMix Buildroot Control Center
#
# Features:
# - First-time setup wizard (auto-download rootfs)
# - Download/Install rootfs
# - Start/Stop chroot
# - Open terminal
# - Run Python/Node.js scripts
# - GPU passthrough management
# - Audio configuration
# - Input device status
# - Overlay management (persistent changes)
# - Profile management
# - Resource monitoring
# - Backup/Restore
# - Diagnostics

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CHROOT_MANAGER="/mnt/SDCARD/buildroot/scripts/chroot-manager.sh"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Detect device
detect_device() {
    _device="unknown"
    if [ -f /etc/trimui_device.txt ]; then
        _device=$(cat /etc/trimui_device.txt 2>/dev/null | tr -d '[:space:]')
    fi
    if [ "$_device" = "unknown" ] && [ -r /proc/device-tree/model ]; then
        _model=$(tr -d '\0' </proc/device-tree/model 2>/dev/null | tr 'A-Z' 'a-z')
        case "$_model" in
            *a523*|*tg5050*|*5050*) _device="tg5050" ;;
            *brick*|*tg3040*) _device="brick" ;;
            *a133*) _device="tsp" ;;
        esac
    fi
    echo "$_device"
}

# Get device name
get_device_name() {
    case "$1" in
        tg5050) echo "TrimUI Smart Pro S" ;;
        tsp) echo "TrimUI Smart Pro" ;;
        brick) echo "TrimUI Brick" ;;
        *) echo "Unknown" ;;
    esac
}

# Check if chroot manager exists
check_manager() {
    if [ ! -f "$CHROOT_MANAGER" ]; then
        echo -e "${RED}Error: chroot-manager.sh not found at $CHROOT_MANAGER${NC}"
        echo "Please install JukaMix Buildroot first."
        return 1
    fi
    return 0
}

# Check if rootfs exists
check_rootfs() {
    _device=$(detect_device)
    case "$_device" in
        tg5050) _rootfs="/mnt/SDCARD/buildroot/rootfs-tg5050.ext2" ;;
        tsp|brick) _rootfs="/mnt/SDCARD/buildroot/rootfs-tsp-brick.ext2" ;;
        *) return 1 ;;
    esac
    
    if [ -f "$_rootfs" ]; then
        return 0
    fi
    return 1
}

# First-time setup wizard
first_time_setup() {
    clear
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}   JukaMix Buildroot - First Time Setup${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    echo -e "Welcome! This wizard will set up the chroot environment"
    echo -e "for your $(get_device_name $(detect_device))."
    echo ""
    echo -e "${YELLOW}The chroot provides:${NC}"
    echo "  - Modern glibc 2.44+"
    echo "  - Python 3.12"
    echo "  - Node.js 20"
    echo "  - GPU passthrough (Mali)"
    echo "  - Audio support"
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo ""
    echo -n "Press Enter to continue or Ctrl+C to cancel..."
    read -r
    
    # Step 1: Download rootfs
    clear
    echo -e "${CYAN}Step 1: Download Rootfs${NC}"
    echo ""
    echo "This will download the rootfs for your device."
    echo "File size: ~512MB (TSP/Brick) or ~1GB (Smart Pro S)"
    echo ""
    echo -n "Download now? [Y/n]: "
    read -r _answer
    
    if [ "$_answer" != "n" ] && [ "$_answer" != "N" ]; then
        echo ""
        echo -e "${CYAN}Downloading...${NC}"
        "$CHROOT_MANAGER" download
        if [ $? -ne 0 ]; then
            echo -e "${RED}Download failed. Please check your internet connection.${NC}"
            echo "Press Enter to continue..."
            read -r
            return 1
        fi
    fi
    
    # Step 2: Install rootfs
    clear
    echo -e "${CYAN}Step 2: Install Rootfs${NC}"
    echo ""
    echo "This will extract the rootfs to the chroot directory."
    echo ""
    echo -n "Install now? [Y/n]: "
    read -r _answer
    
    if [ "$_answer" != "n" ] && [ "$_answer" != "N" ]; then
        echo ""
        echo -e "${CYAN}Installing...${NC}"
        "$CHROOT_MANAGER" install
        if [ $? -ne 0 ]; then
            echo -e "${RED}Installation failed.${NC}"
            echo "Press Enter to continue..."
            read -r
            return 1
        fi
    fi
    
    # Step 3: Start chroot
    clear
    echo -e "${CYAN}Step 3: Start Buildroot${NC}"
    echo ""
    echo "This will start the chroot environment."
    echo ""
    echo -n "Start now? [Y/n]: "
    read -r _answer
    
    if [ "$_answer" != "n" ] && [ "$_answer" != "N" ]; then
        echo ""
        echo -e "${CYAN}Starting...${NC}"
        "$CHROOT_MANAGER" start
    fi
    
    # Done
    clear
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}   Setup Complete!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo -e "Your chroot environment is ready."
    echo ""
    echo -e "${CYAN}Quick start:${NC}"
    echo "  - Open Terminal to access the chroot"
    echo "  - Run Python/Node.js scripts"
    echo "  - Enable Overlay for persistent changes"
    echo ""
    echo "Press Enter to continue to Control Center..."
    read -r
}

# Show main menu
show_menu() {
    clear
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}   JukaMix Buildroot Control Center${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    echo -e "Device: ${GREEN}$(get_device_name $(detect_device))${NC}"
    echo ""

    # Check status
    _device=$(detect_device)
    _status="STOPPED"
    if [ -f "/mnt/SDCARD/buildroot/$_device/.running" ]; then
        _status="${GREEN}RUNNING${NC}"
    else
        _status="${YELLOW}STOPPED${NC}"
    fi
    echo -e "Status: $_status"
    echo ""

    # Check GPU
    _gpu_count=0
    for _dev in /dev/mali0 /dev/mali /dev/dri/*; do
        [ -e "$_dev" ] && _gpu_count=$(( _gpu_count + 1 ))
    done
    if [ "$_gpu_count" -gt 0 ]; then
        echo -e "GPU:    ${GREEN}ACTIVE${NC} ($_gpu_count device(s))"
    else
        echo -e "GPU:    ${YELLOW}INACTIVE${NC}"
    fi

    # Check Audio
    if [ -d /dev/snd ]; then
        echo -e "Audio:  ${GREEN}ACTIVE${NC}"
    else
        echo -e "Audio:  ${YELLOW}INACTIVE${NC}"
    fi

    # Check Input
    _input_count=$(ls /dev/input/event* 2>/dev/null | wc -l)
    if [ "$_input_count" -gt 0 ]; then
        echo -e "Input:  ${GREEN}ACTIVE${NC} ($_input_count device(s))"
    else
        echo -e "Input:  ${YELLOW}INACTIVE${NC}"
    fi

    # Check Overlay
    if [ -f "/mnt/SDCARD/buildroot/$_device/.overlay-active" ]; then
        echo -e "Overlay:${GREEN} ACTIVE${NC}"
    else
        echo -e "Overlay:${YELLOW} INACTIVE${NC}"
    fi

    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo ""
    echo "=== Rootfs ==="
    echo "1.  Download Rootfs"
    echo "2.  Install Rootfs"
    echo ""
    echo "=== Chroot ==="
    echo "3.  Start Buildroot"
    echo "4.  Stop Buildroot"
    echo "5.  Open Terminal"
    echo ""
    echo "=== Applications ==="
    echo "6.  Run Python Script"
    echo "7.  Run Node.js Script"
    echo "8.  Run Custom Command"
    echo ""
    echo "=== Features ==="
    echo "9.  GPU Status"
    echo "10. Audio Status"
    echo "11. Input Devices"
    echo ""
    echo "=== System ==="
    echo "12. Enable Overlay (Persistent Changes)"
    echo "13. Disable Overlay (Clean State)"
    echo "14. Backup User Data"
    echo "15. Restore User Data"
    echo "16. View Status"
    echo "17. Run Diagnostics"
    echo "18. Update Rootfs"
    echo "19. Cleanup Storage"
    echo ""
    echo "=== Profiles ==="
    echo "20. List Profiles"
    echo "21. Save Profile"
    echo "22. Load Profile"
    echo ""
    echo "=== Help ==="
    echo "23. First Time Setup Wizard"
    echo ""
    echo "0.  Exit"
    echo ""
    echo -e "${CYAN}========================================${NC}"
}

# Download rootfs
do_download() {
    echo ""
    echo -e "${CYAN}Downloading rootfs...${NC}"
    "$CHROOT_MANAGER" download
    echo ""
    echo "Press Enter to continue..."
    read -r
}

# Install rootfs
do_install() {
    echo ""
    echo -e "${CYAN}Installing rootfs...${NC}"
    "$CHROOT_MANAGER" install
    echo ""
    echo "Press Enter to continue..."
    read -r
}

# Start chroot
do_start() {
    echo ""
    echo -e "${CYAN}Starting chroot...${NC}"
    "$CHROOT_MANAGER" start
    echo ""
    echo "Press Enter to continue..."
    read -r
}

# Stop chroot
do_stop() {
    echo ""
    echo -e "${CYAN}Stopping chroot...${NC}"
    "$CHROOT_MANAGER" stop
    echo ""
    echo "Press Enter to continue..."
    read -r
}

# Open terminal
do_terminal() {
    echo ""
    echo -e "${CYAN}Opening terminal...${NC}"
    echo "Type 'exit' to return to Control Center"
    echo ""
    "$CHROOT_MANAGER" shell
    echo ""
    echo "Press Enter to continue..."
    read -r
}

# Run Python script
do_python() {
    echo ""
    echo -e "${CYAN}Enter Python script path:${NC}"
    echo "Example: /mnt/SDCARD/Roms/my_script.py"
    echo ""
    read -r _script

    if [ -z "$_script" ]; then
        echo "No script specified."
        echo "Press Enter to continue..."
        read -r
        return
    fi

    echo ""
    echo -e "${CYAN}Running Python script: $_script${NC}"
    "$CHROOT_MANAGER" run "python3 $_script"
    echo ""
    echo "Press Enter to continue..."
    read -r
}

# Run Node.js script
do_nodejs() {
    echo ""
    echo -e "${CYAN}Enter Node.js script path:${NC}"
    echo "Example: /mnt/SDCARD/Roms/my_script.js"
    echo ""
    read -r _script

    if [ -z "$_script" ]; then
        echo "No script specified."
        echo "Press Enter to continue..."
        read -r
        return
    fi

    echo ""
    echo -e "${CYAN}Running Node.js script: $_script${NC}"
    "$CHROOT_MANAGER" run "node $_script"
    echo ""
    echo "Press Enter to continue..."
    read -r
}

# Run custom command
do_custom() {
    echo ""
    echo -e "${CYAN}Enter command to run:${NC}"
    echo ""
    read -r _cmd

    if [ -z "$_cmd" ]; then
        echo "No command specified."
        echo "Press Enter to continue..."
        read -r
        return
    fi

    echo ""
    echo -e "${CYAN}Running: $_cmd${NC}"
    "$CHROOT_MANAGER" run "$_cmd"
    echo ""
    echo "Press Enter to continue..."
    read -r
}

# GPU status
do_gpu() {
    echo ""
    echo -e "${CYAN}=== GPU Status ===${NC}"
    echo ""

    _gpu_count=0
    for _dev in /dev/mali0 /dev/mali /dev/mali_*; do
        if [ -e "$_dev" ]; then
            echo -e "${GREEN}+${NC} $_dev"
            _gpu_count=$(( _gpu_count + 1 ))
        fi
    done

    for _dev in /dev/dri/*; do
        if [ -e "$_dev" ]; then
            echo -e "${GREEN}+${NC} $_dev"
            _gpu_count=$(( _gpu_count + 1 ))
        fi
    done

    if [ -e /dev/dma_heap/system ]; then
        echo -e "${GREEN}+${NC} /dev/dma_heap/system"
        _gpu_count=$(( _gpu_count + 1 ))
    fi

    if [ "$_gpu_count" -eq 0 ]; then
        echo -e "${YELLOW}No GPU device nodes found${NC}"
    else
        echo ""
        echo -e "${GREEN}$_gpu_count GPU device(s) available${NC}"
    fi

    echo ""
    echo "Press Enter to continue..."
    read -r
}

# Audio status
do_audio() {
    echo ""
    echo -e "${CYAN}=== Audio Status ===${NC}"
    echo ""

    if [ -d /dev/snd ]; then
        echo -e "${GREEN}+${NC} ALSA devices available:"
        ls -la /dev/snd/ 2>/dev/null | tail -n +2
    else
        echo -e "${YELLOW}No ALSA devices found${NC}"
    fi

    echo ""
    echo "Press Enter to continue..."
    read -r
}

# Input devices
do_input() {
    echo ""
    echo -e "${CYAN}=== Input Devices ===${NC}"
    echo ""

    _count=0
    for _dev in /dev/input/event*; do
        if [ -e "$_dev" ]; then
            echo -e "${GREEN}+${NC} $_dev"
            _count=$(( _count + 1 ))
        fi
    done

    if [ -e /dev/uinput ]; then
        echo -e "${GREEN}+${NC} /dev/uinput (virtual input)"
        _count=$(( _count + 1 ))
    fi

    if [ "$_count" -eq 0 ]; then
        echo -e "${YELLOW}No input devices found${NC}"
    else
        echo ""
        echo -e "${GREEN}$_count input device(s) available${NC}"
    fi

    echo ""
    echo "Press Enter to continue..."
    read -r
}

# Enable overlay
do_overlay_enable() {
    echo ""
    echo -e "${CYAN}Enabling overlay (persistent changes)...${NC}"
    "$CHROOT_MANAGER" overlay enable
    echo ""
    echo "Press Enter to continue..."
    read -r
}

# Disable overlay
do_overlay_disable() {
    echo ""
    echo -e "${YELLOW}Disabling overlay (clean state)...${NC}"
    "$CHROOT_MANAGER" overlay disable
    echo ""
    echo "Press Enter to continue..."
    read -r
}

# Backup user data
do_backup() {
    echo ""
    echo -e "${CYAN}Backing up user data...${NC}"
    "$CHROOT_MANAGER" backup
    echo ""
    echo "Press Enter to continue..."
    read -r
}

# Restore user data
do_restore() {
    echo ""
    echo -e "${CYAN}Available backups:${NC}"
    "$CHROOT_MANAGER" backups
    echo ""
    echo "Enter backup path to restore (or press Enter to cancel):"
    read -r _path

    if [ -n "$_path" ]; then
        "$CHROOT_MANAGER" restore "$_path"
    fi

    echo ""
    echo "Press Enter to continue..."
    read -r
}

# View status
do_status() {
    echo ""
    "$CHROOT_MANAGER" status
    echo ""
    echo "Press Enter to continue..."
    read -r
}

# Run diagnostics
do_diagnostics() {
    echo ""
    "$CHROOT_MANAGER" diagnose
    echo ""
    echo "Press Enter to continue..."
    read -r
}

# Update rootfs
do_update() {
    echo ""
    echo -e "${CYAN}Updating rootfs...${NC}"
    "$CHROOT_MANAGER" update
    echo ""
    echo "Press Enter to continue..."
    read -r
}

# Cleanup storage
do_cleanup() {
    echo ""
    echo -e "${CYAN}Cleaning up storage...${NC}"
    "$CHROOT_MANAGER" cleanup
    echo ""
    echo "Press Enter to continue..."
    read -r
}

# List profiles
do_profiles_list() {
    echo ""
    "$CHROOT_MANAGER" profiles
    echo ""
    echo "Press Enter to continue..."
    read -r
}

# Save profile
do_profile_save() {
    echo ""
    echo -e "${CYAN}Enter profile name:${NC}"
    read -r _name

    if [ -n "$_name" ]; then
        "$CHROOT_MANAGER" profile save "$_name"
    fi

    echo ""
    echo "Press Enter to continue..."
    read -r
}

# Load profile
do_profile_load() {
    echo ""
    echo -e "${CYAN}Available profiles:${NC}"
    "$CHROOT_MANAGER" profiles
    echo ""
    echo "Enter profile name to load (or press Enter to cancel):"
    read -r _name

    if [ -n "$_name" ]; then
        "$CHROOT_MANAGER" profile load "$_name"
    fi

    echo ""
    echo "Press Enter to continue..."
    read -r
}

# ============================================================================
# MAIN LOOP
# ============================================================================

# Check if chroot manager exists
if ! check_manager; then
    echo "Press Enter to exit..."
    read -r
    exit 1
fi

# Check if this is first time (no rootfs installed)
if ! check_rootfs; then
    echo -e "${YELLOW}Rootfs not found. Running first-time setup...${NC}"
    first_time_setup
fi

# Main loop
while true; do
    show_menu
    echo ""
    echo -n "Select option: "
    read -r _choice

    case "$_choice" in
        1)  do_download ;;
        2)  do_install ;;
        3)  do_start ;;
        4)  do_stop ;;
        5)  do_terminal ;;
        6)  do_python ;;
        7)  do_nodejs ;;
        8)  do_custom ;;
        9)  do_gpu ;;
        10) do_audio ;;
        11) do_input ;;
        12) do_overlay_enable ;;
        13) do_overlay_disable ;;
        14) do_backup ;;
        15) do_restore ;;
        16) do_status ;;
        17) do_diagnostics ;;
        18) do_update ;;
        19) do_cleanup ;;
        20) do_profiles_list ;;
        21) do_profile_save ;;
        22) do_profile_load ;;
        23) first_time_setup ;;
        0)  echo ""; echo "Goodbye!"; exit 0 ;;
        *)  echo "Invalid option"; sleep 1 ;;
    esac
done
