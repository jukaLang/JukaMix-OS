#!/bin/sh
# tools/go/fetch_go.sh
# Download Go compiler for TrimUI devices (aarch64)

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
GO_DIR="/mnt/SDCARD/tools/go"
CACHE_DIR="/tmp/jukamix-cache"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# Create directories
mkdir -p "$GO_DIR" "$CACHE_DIR"

# Download with retry
download() {
    local url="$1"
    local output="$2"
    
    if [ -f "$output" ]; then
        log_warn "Already exists: $output"
        return 0
    fi
    
    log_info "Downloading: $(basename "$output")"
    
    if command -v curl >/dev/null 2>&1; then
        curl -fL --retry 3 -o "$output" "$url"
    elif command -v wget >/dev/null 2>&1; then
        wget -q --tries=3 -O "$output" "$url"
    else
        log_error "No download tool available"
        return 1
    fi
    
    if [ ! -s "$output" ]; then
        log_error "Download failed"
        rm -f "$output"
        return 1
    fi
    
    log_info "Downloaded: $(ls -lh "$output" | awk '{print $5}')"
}

# Extract Go archive
extract_go() {
    local archive="$1"
    local dest="$2"
    
    log_info "Extracting Go to $dest..."
    
    # Go uses tar.gz
    tar -xzf "$archive" -C "$dest"
    
    if [ $? -eq 0 ]; then
        log_info "Go extracted successfully"
        return 0
    fi
    
    return 1
}

# Download Go compiler
download_go() {
    local go_version="1.22.4"
    local url="https://go.dev/dl/go${go_version}.linux-arm64.tar.gz"
    local archive="$CACHE_DIR/go-${go_version}-linux-arm64.tar.gz"
    
    log_info "Downloading Go ${go_version} for linux-arm64..."
    
    download "$url" "$archive"
    
    if [ $? -eq 0 ]; then
        # Extract to temporary location
        local tmp_dir="$CACHE_DIR/go-extract"
        mkdir -p "$tmp_dir"
        extract_go "$archive" "$tmp_dir"
        
        # Move to final location
        rm -rf "$GO_DIR"
        mv "$tmp_dir/go" "$GO_DIR"
        rm -rf "$tmp_dir"
        
        log_info "Go installed to $GO_DIR"
        return 0
    fi
    
    return 1
}

# Create Go wrapper script
create_wrapper() {
    cat > "$GO_DIR/bin/go" << 'EOF'
#!/bin/sh
# Go wrapper for JukaMix OS

GO_HOME="/mnt/SDCARD/tools/go"
GO_BIN="$GO_HOME/bin/go"

if [ ! -f "$GO_BIN" ]; then
    echo "Go not installed. Run: tools/go/fetch_go.sh"
    exit 1
fi

export GOROOT="$GO_HOME"
export GOPATH="/mnt/SDCARD/tools/go-workspace"
export PATH="$GO_HOME/bin:$PATH"

exec "$GO_BIN" "$@"
EOF
    
    chmod +x "$GO_DIR/bin/go"
}

# Create Go workspace directory
create_workspace() {
    local workspace="/mnt/SDCARD/tools/go-workspace"
    mkdir -p "$workspace"/{src,bin,pkg}
    log_info "Go workspace created at $workspace"
}

# Main
main() {
    log_info "=== Go Compiler Setup for JukaMix OS ==="
    echo ""
    
    # Download Go compiler
    download_go
    
    # Create wrapper script
    create_wrapper
    
    # Create workspace
    create_workspace
    
    # Verify installation
    if [ -f "$GO_DIR/bin/go" ]; then
        log_info "=== Go Setup Complete ==="
        log_info "Usage: /mnt/SDCARD/tools/go/bin/go build main.go"
        log_info "   or: go run main.go (after adding to PATH)"
        echo ""
        log_info "To add to PATH:"
        log_info "  export PATH=/mnt/SDCARD/tools/go/bin:\$PATH"
    else
        log_error "Go installation failed"
        return 1
    fi
}

main "$@"
