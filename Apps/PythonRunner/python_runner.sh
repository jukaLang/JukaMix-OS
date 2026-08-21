#!/bin/sh
# Apps/PythonRunner/python_runner.sh
# Python Runner - Execute Python scripts on TrimUI

PYTHON_DIR="/mnt/SDCARD/tools/python"
PYTHON_BIN="$PYTHON_DIR/bin/python3"
SCRIPTS_DIR="/mnt/SDCARD"
LOG_FILE="/tmp/python_runner.log"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

# Logging
log() {
    echo "$(date '+%H:%M:%S') [python] $1" >> "$LOG_FILE"
}

# Check if Python is installed
check_python() {
    if [ -f "$PYTHON_BIN" ]; then
        return 0
    fi
    return 1
}

# Install Python if not present
install_python() {
    echo -e "${YELLOW}Python not installed. Installing...${NC}"
    
    local fetch_script="/mnt/SDCARD/tools/python/fetch_python.sh"
    
    if [ -f "$fetch_script" ]; then
        sh "$fetch_script"
    else
        echo -e "${RED}fetch_python.sh not found${NC}"
        return 1
    fi
}

# Run Python script
run_script() {
    local script="$1"
    shift
    local args="$@"
    
    if [ ! -f "$script" ]; then
        echo -e "${RED}Script not found: $script${NC}"
        return 1
    fi
    
    # Set up Python environment
    export PYTHONHOME="$PYTHON_DIR"
    export PYTHONPATH="$PYTHON_DIR/lib/python3.12"
    export LD_LIBRARY_PATH="$PYTHON_DIR/lib:$LD_LIBRARY_PATH"
    
    echo -e "${CYAN}Running: $(basename "$script")${NC}"
    echo ""
    
    # Run the script
    "$PYTHON_BIN" "$script" $args
    
    local exit_code=$?
    
    echo ""
    if [ $exit_code -eq 0 ]; then
        echo -e "${GREEN}Script completed successfully${NC}"
    else
        echo -e "${RED}Script exited with code: $exit_code${NC}"
    fi
    
    log "Ran: $script (exit: $exit_code)"
    return $exit_code
}

# Run Python one-liner
run_oneliner() {
    local code="$1"
    
    export PYTHONHOME="$PYTHON_DIR"
    export PYTHONPATH="$PYTHON_DIR/lib/python3.12"
    export LD_LIBRARY_PATH="$PYTHON_DIR/lib:$LD_LIBRARY_PATH"
    
    echo -e "${CYAN}Running Python code...${NC}"
    echo ""
    
    "$PYTHON_BIN" -c "$code"
    
    local exit_code=$?
    
    echo ""
    if [ $exit_code -eq 0 ]; then
        echo -e "${GREEN}Code executed successfully${NC}"
    else
        echo -e "${RED}Code exited with code: $exit_code${NC}"
    fi
    
    log "Ran one-liner (exit: $exit_code)"
    return $exit_code
}

# Start interactive Python shell
start_shell() {
    export PYTHONHOME="$PYTHON_DIR"
    export PYTHONPATH="$PYTHON_DIR/lib/python3.12"
    export LD_LIBRARY_PATH="$PYTHON_DIR/lib:$LD_LIBRARY_PATH"
    
    echo -e "${CYAN}Starting Python shell...${NC}"
    echo -e "${YELLOW}Type 'exit()' to quit${NC}"
    echo ""
    
    "$PYTHON_BIN"
}

# List Python scripts
list_scripts() {
    echo -e "${CYAN}Python scripts in SD card:${NC}"
    echo ""
    
    find "$SCRIPTS_DIR" -name "*.py" -type f 2>/dev/null | head -20 | while read -r script; do
        local name=$(basename "$script")
        local dir=$(dirname "$script" | sed "s|$SCRIPTS_DIR||")
        echo "  $dir/$name"
    done
    
    echo ""
    echo "Total: $(find "$SCRIPTS_DIR" -name "*.py" -type f 2>/dev/null | wc -l) scripts"
}

# Install pip packages
install_package() {
    local package="$1"
    
    if [ -z "$package" ]; then
        echo "Usage: install <package>"
        return 1
    fi
    
    export PYTHONHOME="$PYTHON_DIR"
    export PYTHONPATH="$PYTHON_DIR/lib/python3.12"
    export LD_LIBRARY_PATH="$PYTHON_DIR/lib:$LD_LIBRARY_PATH"
    
    echo -e "${CYAN}Installing package: $package${NC}"
    
    "$PYTHON_BIN" -m pip install "$package" --user
    
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        echo -e "${GREEN}Package installed: $package${NC}"
    else
        echo -e "${RED}Failed to install: $package${NC}"
    fi
    
    return $exit_code
}

# Show Python info
show_info() {
    echo -e "${CYAN}=== Python Information ===${NC}"
    echo ""
    
    if check_python; then
        echo "Python: $PYTHON_BIN"
        echo "Version: $("$PYTHON_BIN" --version 2>&1)"
        echo ""
        echo "Environment:"
        echo "  PYTHONHOME: $PYTHONHOME"
        echo "  PYTHONPATH: $PYTHONPATH"
    else
        echo -e "${YELLOW}Python not installed${NC}"
        echo ""
        echo "To install, run:"
        echo "  /mnt/SDCARD/tools/python/fetch_python.sh"
    fi
    
    echo ""
    echo "Location: $PYTHON_DIR"
    
    if [ -d "$PYTHON_DIR/lib" ]; then
        echo "Size: $(du -sh "$PYTHON_DIR" 2>/dev/null | awk '{print $1}')"
    fi
}

# Show help
show_help() {
    echo -e "${CYAN}Python Runner${NC}"
    echo "=============="
    echo ""
    echo "Usage: python_runner.sh <command> [args]"
    echo ""
    echo "Commands:"
    echo "  run <script> [args]  - Run a Python script"
    echo "  code <python code>   - Run Python one-liner"
    echo "  shell                - Start interactive Python shell"
    echo "  list                 - List Python scripts"
    echo "  install <package>    - Install pip package"
    echo "  info                 - Show Python information"
    echo "  setup                - Install Python if not present"
    echo ""
    echo "Examples:"
    echo "  python_runner.sh run /mnt/SDCARD/Roms/my_script.py"
    echo "  python_runner.sh code \"print('Hello World')\""
    echo "  python_runner.sh install numpy"
}

# Main
case "${1:-}" in
    run)
        if ! check_python; then
            install_python
        fi
        run_script "$2" "${@:3}"
        ;;
    code|eval)
        if ! check_python; then
            install_python
        fi
        run_oneliner "$2"
        ;;
    shell|interactive)
        if ! check_python; then
            install_python
        fi
        start_shell
        ;;
    list|ls)
        list_scripts
        ;;
    install|pip)
        if ! check_python; then
            install_python
        fi
        install_package "$2"
        ;;
    info)
        show_info
        ;;
    setup|install-python)
        install_python
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        show_help
        ;;
esac
