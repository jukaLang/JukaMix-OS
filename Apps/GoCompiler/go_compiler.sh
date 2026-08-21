#!/bin/sh
# Apps/GoCompiler/go_compiler.sh
# Go Compiler - Build and run Go programs on TrimUI

GO_DIR="/mnt/SDCARD/tools/go"
GO_BIN="$GO_DIR/bin/go"
WORKSPACE="/mnt/SDCARD/tools/go-workspace"
LOG_FILE="/tmp/go_compiler.log"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

# Logging
log() {
    echo "$(date '+%H:%M:%S') [go] $1" >> "$LOG_FILE"
}

# Check if Go is installed
check_go() {
    if [ -f "$GO_BIN" ]; then
        return 0
    fi
    return 1
}

# Install Go if not present
install_go() {
    echo -e "${YELLOW}Go not installed. Installing...${NC}"
    
    local fetch_script="/mnt/SDCARD/tools/go/fetch_go.sh"
    
    if [ -f "$fetch_script" ]; then
        sh "$fetch_script"
    else
        echo -e "${RED}fetch_go.sh not found${NC}"
        return 1
    fi
}

# Set up Go environment
setup_env() {
    export GOROOT="$GO_DIR"
    export GOPATH="$WORKSPACE"
    export PATH="$GO_DIR/bin:$PATH"
    
    # Create workspace if needed
    mkdir -p "$WORKSPACE"/{src,bin,pkg}
}

# Build Go program
build_program() {
    local source="$1"
    local output="${2:-}"
    
    if [ ! -f "$source" ]; then
        echo -e "${RED}Source file not found: $source${NC}"
        return 1
    fi
    
    setup_env
    
    # Determine output name
    if [ -z "$output" ]; then
        output=$(basename "$source" .go)
    fi
    
    echo -e "${CYAN}Building: $(basename "$source")${NC}"
    echo ""
    
    # Build the program
    "$GO_BIN" build -o "$output" "$source"
    
    local exit_code=$?
    
    echo ""
    if [ $exit_code -eq 0 ]; then
        echo -e "${GREEN}Build successful: $output${NC}"
        log "Built: $source -> $output"
    else
        echo -e "${RED}Build failed with code: $exit_code${NC}"
        log "Build failed: $source"
    fi
    
    return $exit_code
}

# Run Go program
run_program() {
    local source="$1"
    shift
    local args="$@"
    
    if [ ! -f "$source" ]; then
        echo -e "${RED}Source file not found: $source${NC}"
        return 1
    fi
    
    setup_env
    
    echo -e "${CYAN}Running: $(basename "$source")${NC}"
    echo ""
    
    # Run the program
    "$GO_BIN" run "$source" $args
    
    local exit_code=$?
    
    echo ""
    if [ $exit_code -eq 0 ]; then
        echo -e "${GREEN}Program completed successfully${NC}"
    else
        echo -e "${RED}Program exited with code: $exit_code${NC}"
    fi
    
    log "Ran: $source (exit: $exit_code)"
    return $exit_code
}

# Initialize new Go module
init_module() {
    local name="$1"
    
    if [ -z "$name" ]; then
        echo "Usage: init <module-name>"
        return 1
    fi
    
    setup_env
    
    local module_dir="$WORKSPACE/src/$name"
    mkdir -p "$module_dir"
    
    echo -e "${CYAN}Initializing Go module: $name${NC}"
    
    cd "$module_dir"
    "$GO_BIN" mod init "$name"
    
    # Create main.go template
    cat > main.go << EOF
package main

import "fmt"

func main() {
    fmt.Println("Hello from $name!")
}
EOF
    
    echo -e "${GREEN}Module created at: $module_dir${NC}"
    echo ""
    echo "Files:"
    echo "  go.mod"
    echo "  main.go"
    echo ""
    echo "To build: go build main.go"
    echo "To run:   go run main.go"
}

# Format Go code
format_code() {
    local file="$1"
    
    if [ -z "$file" ]; then
        echo "Usage: fmt <file.go>"
        return 1
    fi
    
    setup_env
    
    echo -e "${CYAN}Formatting: $(basename "$file")${NC}"
    
    "$GO_BIN" fmt "$file"
    
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        echo -e "${GREEN}Formatted successfully${NC}"
    else
        echo -e "${RED}Format failed${NC}"
    fi
    
    return $exit_code
}

# Get Go packages
get_package() {
    local package="$1"
    
    if [ -z "$package" ]; then
        echo "Usage: get <package>"
        return 1
    fi
    
    setup_env
    
    echo -e "${CYAN}Installing package: $package${NC}"
    
    "$GO_BIN" get "$package"
    
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        echo -e "${GREEN}Package installed: $package${NC}"
    else
        echo -e "${RED}Failed to install: $package${NC}"
    fi
    
    return $exit_code
}

# List Go programs
list_programs() {
    echo -e "${CYAN}Go programs in SD card:${NC}"
    echo ""
    
    find /mnt/SDCARD -name "*.go" -type f 2>/dev/null | head -20 | while read -r file; do
        local name=$(basename "$file")
        local dir=$(dirname "$file" | sed "s|/mnt/SDCARD||")
        echo "  $dir/$name"
    done
    
    echo ""
    echo "Total: $(find /mnt/SDCARD -name "*.go" -type f 2>/dev/null | wc -l) files"
}

# Show Go info
show_info() {
    echo -e "${CYAN}=== Go Information ===${NC}"
    echo ""
    
    if check_go; then
        setup_env
        echo "Go: $GO_BIN"
        echo "Version: $("$GO_BIN" version 2>&1)"
        echo ""
        echo "Environment:"
        echo "  GOROOT: $GOROOT"
        echo "  GOPATH: $GOPATH"
    else
        echo -e "${YELLOW}Go not installed${NC}"
        echo ""
        echo "To install, run:"
        echo "  /mnt/SDCARD/tools/go/fetch_go.sh"
    fi
    
    echo ""
    echo "Location: $GO_DIR"
    
    if [ -d "$GO_DIR" ]; then
        echo "Size: $(du -sh "$GO_DIR" 2>/dev/null | awk '{print $1}')"
    fi
    
    echo "Workspace: $WORKSPACE"
}

# Show help
show_help() {
    echo -e "${CYAN}Go Compiler${NC}"
    echo "============"
    echo ""
    echo "Usage: go_compiler.sh <command> [args]"
    echo ""
    echo "Commands:"
    echo "  build <source> [output]  - Build Go program"
    echo "  run <source> [args]      - Run Go program"
    echo "  init <name>              - Initialize new module"
    echo "  fmt <file>               - Format Go code"
    echo "  get <package>            - Install Go package"
    echo "  list                     - List Go programs"
    echo "  info                     - Show Go information"
    echo "  setup                    - Install Go if not present"
    echo ""
    echo "Examples:"
    echo "  go_compiler.sh run main.go"
    echo "  go_compiler.sh build main.go myapp"
    echo "  go_compiler.sh init myproject"
    echo "  go_compiler.sh get github.com/gin-gonic/gin"
}

# Main
case "${1:-}" in
    build|compile)
        if ! check_go; then
            install_go
        fi
        build_program "$2" "$3"
        ;;
    run|execute)
        if ! check_go; then
            install_go
        fi
        run_program "$2" "${@:3}"
        ;;
    init|new)
        if ! check_go; then
            install_go
        fi
        init_module "$2"
        ;;
    fmt|format)
        if ! check_go; then
            install_go
        fi
        format_code "$2"
        ;;
    get|install)
        if ! check_go; then
            install_go
        fi
        get_package "$2"
        ;;
    list|ls)
        list_programs
        ;;
    info)
        show_info
        ;;
    setup|install-go)
        install_go
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        show_help
        ;;
esac
