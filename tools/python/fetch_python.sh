#!/bin/sh
# tools/python/fetch_python.sh
# Download Python binaries for TrimUI devices (aarch64)

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PYTHON_DIR="/mnt/SDCARD/tools/python"
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
mkdir -p "$PYTHON_DIR" "$CACHE_DIR"

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

# Extract archive
extract() {
    local archive="$1"
    local dest="$2"
    
    log_info "Extracting to $dest..."
    
    case "$archive" in
        *.tar.gz|*.tgz)
            tar -xzf "$archive" -C "$dest"
            ;;
        *.tar.xz)
            tar -xJf "$archive" -C "$dest"
            ;;
        *.zip)
            unzip -q "$archive" -d "$dest"
            ;;
        *)
            log_error "Unknown archive format"
            return 1
            ;;
    esac
}

# Install Python from buildroot output (if available)
install_from_buildroot() {
    local buildroot_python="/home/runner/work/JukaMix-OS/buildroot/buildroot-2024.02/output/target/usr/bin/python3"
    
    if [ -f "$buildroot_python" ]; then
        log_info "Installing Python from buildroot..."
        
        # Copy Python binary and libraries
        cp -r /home/runner/work/JukaMix-OS/buildroot/buildroot-2024.02/output/target/usr/bin/python* "$PYTHON_DIR/" 2>/dev/null || true
        cp -r /home/runner/work/JukaMix-OS/buildroot/buildroot-2024.02/output/target/usr/lib/python* "$PYTHON_DIR/" 2>/dev/null || true
        cp -r /home/runner/work/JukaMix-OS/buildroot/buildroot-2024.02/output/target/usr/lib/libpython* "$PYTHON_DIR/" 2>/dev/null || true
        
        return 0
    fi
    
    return 1
}

# Download pre-built Python (fallback)
download_python() {
    local python_version="3.12.4"
    local url="https://github.com/indygreg/python-build-standalone/releases/download/20240415/cpython-${python_version}+20240415-aarch64-unknown-linux-gnu-install_only.tar.gz"
    local archive="$CACHE_DIR/python-${python_version}-aarch64.tar.gz"
    
    log_info "Downloading Python ${python_version} for aarch64..."
    
    download "$url" "$archive"
    
    if [ $? -eq 0 ]; then
        extract "$archive" "$PYTHON_DIR"
        log_info "Python installed to $PYTHON_DIR"
        return 0
    fi
    
    return 1
}

# Create Python wrapper script
create_wrapper() {
    cat > "$PYTHON_DIR/python" << 'EOF'
#!/bin/sh
# Python wrapper for JukaMix OS

PYTHON_HOME="/mnt/SDCARD/tools/python"
PYTHON_BIN="$PYTHON_HOME/bin/python3"

if [ ! -f "$PYTHON_BIN" ]; then
    echo "Python not installed. Run: tools/python/fetch_python.sh"
    exit 1
fi

export PYTHONHOME="$PYTHON_HOME"
export PYTHONPATH="$PYTHON_HOME/lib/python3.12"
export LD_LIBRARY_PATH="$PYTHON_HOME/lib:$LD_LIBRARY_PATH"

exec "$PYTHON_BIN" "$@"
EOF
    
    chmod +x "$PYTHON_DIR/python"
}

# Create pip wrapper
create_pip_wrapper() {
    cat > "$PYTHON_DIR/pip" << 'EOF'
#!/bin/sh
# pip wrapper for JukaMix OS

PYTHON_HOME="/mnt/SDCARD/tools/python"
PYTHON_BIN="$PYTHON_HOME/bin/python3"
PIP_MODULE="$PYTHON_HOME/lib/python3.12/ensurepip"

if [ ! -f "$PYTHON_BIN" ]; then
    echo "Python not installed. Run: tools/python/fetch_python.sh"
    exit 1
fi

export PYTHONHOME="$PYTHON_HOME"
export PYTHONPATH="$PYTHON_HOME/lib/python3.12"
export LD_LIBRARY_PATH="$PYTHON_HOME/lib:$LD_LIBRARY_PATH"

# Run pip
exec "$PYTHON_BIN" -m pip "$@"
EOF
    
    chmod +x "$PYTHON_DIR/pip"
}

# Main
main() {
    log_info "=== Python Setup for JukaMix OS ==="
    echo ""
    
    # Try to install from buildroot first
    if install_from_buildroot; then
        log_info "Python installed from buildroot"
    else
        # Download pre-built Python
        download_python
    fi
    
    # Create wrapper scripts
    create_wrapper
    create_pip_wrapper
    
    # Verify installation
    if [ -f "$PYTHON_DIR/bin/python3" ] || [ -f "$PYTHON_DIR/python" ]; then
        log_info "=== Python Setup Complete ==="
        log_info "Usage: /mnt/SDCARD/tools/python/python script.py"
        log_info "   or: /mnt/SDCARD/tools/python/pip install package"
    else
        log_error "Python installation failed"
        return 1
    fi
}

main "$@"
