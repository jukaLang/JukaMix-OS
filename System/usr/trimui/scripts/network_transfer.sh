#!/bin/sh
# network_transfer.sh - Network File Transfer System for JukaMix
# Transfer ROMs, saves, and files over Wi-Fi

LOG_FILE="/tmp/network_transfer.log"
TRANSFER_DIR="/mnt/SDCARD/trimui/transfer"
WEB_DIR="/mnt/SDCARD/trimui/web_interface"
PORT=8080
FTP_PORT=2121

# Create directories
mkdir -p "$TRANSFER_DIR" "$WEB_DIR" 2>/dev/null

# ── Logging ────────────────────────────────────────────────────────────
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [transfer] $1" >> "$LOG_FILE" 2>/dev/null
}

# ── Get device IP ──────────────────────────────────────────────────────
get_ip() {
    ip addr show wlan0 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d'/' -f1
}

# ── Start HTTP server ──────────────────────────────────────────────────
start_http_server() {
    echo "Starting HTTP file server..."
    
    ip=$(get_ip)
    if [ -z "$ip" ]; then
        echo "Wi-Fi not connected"
        return 1
    fi
    
    # Create web interface
    create_web_interface
    
    # Start server
    if command -v python3 >/dev/null 2>&1; then
        cd "$WEB_DIR"
        python3 -m http.server "$PORT" --bind 0.0.0.0 > /dev/null 2>&1 &
        SERVER_PID=$!
        echo "$SERVER_PID" > "$TRANSFER_DIR/server.pid"
        
        log "HTTP server started on port $PORT (PID: $SERVER_PID)"
        echo "HTTP Server started!"
        echo ""
        echo "Access from browser:"
        echo "  http://$ip:$PORT"
        echo ""
        echo "Or use file manager:"
        echo "  http://$ip:$PORT/upload"
        
        return 0
    elif command -v python >/dev/null 2>&1; then
        cd "$WEB_DIR"
        python -m SimpleHTTPServer "$PORT" > /dev/null 2>&1 &
        SERVER_PID=$!
        echo "$SERVER_PID" > "$TRANSFER_DIR/server.pid"
        
        log "HTTP server started on port $PORT (PID: $SERVER_PID)"
        echo "HTTP Server started!"
        echo ""
        echo "Access from browser: http://$ip:$PORT"
        
        return 0
    else
        echo "Python not available"
        return 1
    fi
}

# ── Stop HTTP server ───────────────────────────────────────────────────
stop_http_server() {
    if [ -f "$TRANSFER_DIR/server.pid" ]; then
        server_pid=$(cat "$TRANSFER_DIR/server.pid" 2>/dev/null)
        
        if [ -n "$server_pid" ]; then
            kill "$server_pid" 2>/dev/null
            rm -f "$TRANSFER_DIR/server.pid"
            
            log "HTTP server stopped"
            echo "HTTP server stopped"
            return 0
        fi
    fi
    
    echo "No server running"
    return 1
}

# ── Create web interface ───────────────────────────────────────────────
create_web_interface() {
    # Create upload page
    cat > "$WEB_DIR/index.html" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>JukaMix File Transfer</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background: #1a1a2e; color: #eee; }
        .container { max-width: 800px; margin: 0 auto; }
        h1 { color: #00d4ff; text-align: center; }
        .upload-box { background: #16213e; padding: 30px; border-radius: 10px; margin: 20px 0; }
        .btn { background: #00d4ff; color: #000; padding: 10px 20px; border: none; border-radius: 5px; cursor: pointer; font-size: 16px; }
        .btn:hover { background: #00a8cc; }
        .file-list { margin-top: 20px; }
        .file-item { background: #0f3460; padding: 10px; margin: 5px 0; border-radius: 5px; }
        input[type="file"] { margin: 10px 0; }
        .status { margin-top: 20px; padding: 10px; border-radius: 5px; }
        .success { background: #2ecc71; color: #000; }
        .error { background: #e74c3c; color: #fff; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🎮 JukaMix File Transfer</h1>
        
        <div class="upload-box">
            <h2>Upload Files</h2>
            <p>Select files to upload to your device:</p>
            <input type="file" id="fileInput" multiple>
            <br><br>
            <select id="destination">
                <option value="Roms">ROMs</option>
                <option value="BIOS">BIOS</option>
                <option value="saves">Saves</option>
                <option value="screenshots">Screenshots</option>
                <option value="themes">Themes</option>
            </select>
            <button class="btn" onclick="uploadFiles()">Upload</button>
            
            <div id="status" class="status" style="display: none;"></div>
        </div>
        
        <div class="upload-box">
            <h2>Download Files</h2>
            <p>Browse and download files from your device:</p>
            <div class="file-list" id="fileList"></div>
        </div>
    </div>
    
    <script>
        function uploadFiles() {
            const files = document.getElementById('fileInput').files;
            const destination = document.getElementById('destination').value;
            const status = document.getElementById('status');
            
            if (files.length === 0) {
                status.className = 'status error';
                status.textContent = 'Please select files to upload';
                status.style.display = 'block';
                return;
            }
            
            const formData = new FormData();
            for (let i = 0; i < files.length; i++) {
                formData.append('files', files[i]);
            }
            formData.append('destination', destination);
            
            status.className = 'status';
            status.textContent = 'Uploading...';
            status.style.display = 'block';
            
            fetch('/upload', {
                method: 'POST',
                body: formData
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    status.className = 'status success';
                    status.textContent = 'Upload successful! ' + data.message;
                } else {
                    status.className = 'status error';
                    status.textContent = 'Upload failed: ' + data.message;
                }
            })
            .catch(error => {
                status.className = 'status error';
                status.textContent = 'Error: ' + error.message;
            });
        }
        
        // Load file list
        fetch('/files')
            .then(response => response.json())
            .then(files => {
                const fileList = document.getElementById('fileList');
                files.forEach(file => {
                    const div = document.createElement('div');
                    div.className = 'file-item';
                    div.innerHTML = `<a href="/download/${file.name}" style="color: #00d4ff; text-decoration: none;">${file.name}</a> (${file.size})`;
                    fileList.appendChild(div);
                });
            });
    </script>
</body>
</html>
EOF
    
    # Create upload handler
    cat > "$WEB_DIR/upload.py" << 'EOF'
#!/usr/bin/env python3
import os
import cgi
import json
from http.server import HTTPServer, BaseHTTPRequestHandler

UPLOAD_DIR = "/mnt/SDCARD"

class UploadHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/':
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            with open('index.html', 'rb') as f:
                self.wfile.write(f.read())
        
        elif self.path == '/files':
            files = []
            for root, dirs, filenames in os.walk(UPLOAD_DIR):
                for filename in filenames[:100]:  # Limit to 100 files
                    filepath = os.path.join(root, filename)
                    relpath = os.path.relpath(filepath, UPLOAD_DIR)
                    size = os.path.getsize(filepath)
                    files.append({'name': relpath, 'size': f'{size/1024:.1f}KB'})
            
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps(files).encode())
        
        elif self.path.startswith('/download/'):
            filename = self.path[10:]
            filepath = os.path.join(UPLOAD_DIR, filename)
            
            if os.path.exists(filepath):
                self.send_response(200)
                self.send_header('Content-type', 'application/octet-stream')
                self.send_header('Content-Disposition', f'attachment; filename="{filename}"')
                self.end_headers()
                with open(filepath, 'rb') as f:
                    self.wfile.write(f.read())
            else:
                self.send_response(404)
                self.end_headers()
    
    def do_POST(self):
        if self.path == '/upload':
            content_type = self.headers['Content-type']
            form = cgi.FieldStorage(
                fp=self.rfile,
                headers=self.headers,
                environ={'REQUEST_METHOD': 'POST',
                         'CONTENT_TYPE': content_type,
                         'CONTENT_LENGTH': self.headers['Content-Length']}
            )
            
            destination = form.getvalue('destination', 'Roms')
            upload_dir = os.path.join(UPLOAD_DIR, destination)
            
            os.makedirs(upload_dir, exist_ok=True)
            
            uploaded = []
            for item in form.list:
                if item.filename:
                    filepath = os.path.join(upload_dir, item.filename)
                    with open(filepath, 'wb') as f:
                        f.write(item.file.read())
                    uploaded.append(item.filename)
            
            response = {'success': True, 'message': f'Uploaded {len(uploaded)} files'}
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps(response).encode())

if __name__ == '__main__':
    server = HTTPServer(('0.0.0.0', 8080), UploadHandler)
    print('Server running on port 8080')
    server.serve_forever()
EOF
    
    log "Web interface created"
}

# ── Start FTP server ───────────────────────────────────────────────────
start_ftp_server() {
    echo "Starting FTP server..."
    
    ip=$(get_ip)
    if [ -z "$ip" ]; then
        echo "Wi-Fi not connected"
        return 1
    fi
    
    if command -v ftpd >/dev/null 2>&1; then
        ftpd -l -p "$FTP_PORT" -u anonymous > /dev/null 2>&1 &
        FTP_PID=$!
        echo "$FTP_PID" > "$TRANSFER_DIR/ftp.pid"
        
        log "FTP server started on port $FTP_PORT (PID: $FTP_PID)"
        echo "FTP Server started!"
        echo ""
        echo "Connect from file manager:"
        echo "  ftp://$ip:$FTP_PORT"
        echo ""
        echo "Or use command line:"
        echo "  ftp $ip $FTP_PORT"
        
        return 0
    else
        echo "FTP server not available"
        return 1
    fi
}

# ── Stop FTP server ────────────────────────────────────────────────────
stop_ftp_server() {
    if [ -f "$TRANSFER_DIR/ftp.pid" ]; then
        ftp_pid=$(cat "$TRANSFER_DIR/ftp.pid" 2>/dev/null)
        
        if [ -n "$ftp_pid" ]; then
            kill "$ftp_pid" 2>/dev/null
            rm -f "$TRANSFER_DIR/ftp.pid"
            
            log "FTP server stopped"
            echo "FTP server stopped"
            return 0
        fi
    fi
    
    echo "No FTP server running"
    return 1
}

# ── Check server status ────────────────────────────────────────────────
check_status() {
    echo "Network Transfer Status:"
    echo "========================"
    echo ""
    
    ip=$(get_ip)
    echo "IP Address: ${ip:-Not connected}"
    echo ""
    
    # Check HTTP server
    if [ -f "$TRANSFER_DIR/server.pid" ]; then
        server_pid=$(cat "$TRANSFER_DIR/server.pid" 2>/dev/null)
        if [ -n "$server_pid" ] && kill -0 "$server_pid" 2>/dev/null; then
            echo "HTTP Server: Running (PID: $server_pid)"
            echo "  URL: http://$ip:$PORT"
        else
            echo "HTTP Server: Not running"
        fi
    else
        echo "HTTP Server: Not running"
    fi
    
    # Check FTP server
    if [ -f "$TRANSFER_DIR/ftp.pid" ]; then
        ftp_pid=$(cat "$TRANSFER_DIR/ftp.pid" 2>/dev/null)
        if [ -n "$ftp_pid" ] && kill -0 "$ftp_pid" 2>/dev/null; then
            echo "FTP Server: Running (PID: $ftp_pid)"
            echo "  URL: ftp://$ip:$FTP_PORT"
        else
            echo "FTP Server: Not running"
        fi
    else
        echo "FTP Server: Not running"
    fi
}

# ── Send file via SCP ──────────────────────────────────────────────────
send_file() {
    file="$1"
    target="$2"
    
    if [ ! -f "$file" ]; then
        echo "File not found: $file"
        return 1
    fi
    
    if command -v scp >/dev/null 2>&1; then
        scp "$file" "$target" 2>/dev/null
        
        if [ $? -eq 0 ]; then
            echo "File sent: $file"
            log "Sent file: $file to $target"
            return 0
        else
            echo "Failed to send file"
            return 1
        fi
    else
        echo "SCP not available"
        return 1
    fi
}

# ── Receive file via SCP ───────────────────────────────────────────────
receive_file() {
    source="$1"
    destination="$2"
    
    if command -v scp >/dev/null 2>&1; then
        scp "$source" "$destination" 2>/dev/null
        
        if [ $? -eq 0 ]; then
            echo "File received: $destination"
            log "Received file: $source to $destination"
            return 0
        else
            echo "Failed to receive file"
            return 1
        fi
    else
        echo "SCP not available"
        return 1
    fi
}

# ── Main ───────────────────────────────────────────────────────────────
case "${1:-}" in
    http-start)
        start_http_server
        ;;
    http-stop)
        stop_http_server
        ;;
    ftp-start)
        start_ftp_server
        ;;
    ftp-stop)
        stop_ftp_server
        ;;
    status)
        check_status
        ;;
    send)
        send_file "${2:-}" "${3:-}"
        ;;
    receive)
        receive_file "${2:-}" "${3:-}"
        ;;
    *)
        echo "Network File Transfer System"
        echo "Usage: network_transfer.sh {http-start|http-stop|ftp-start|ftp-stop|status|send|receive}"
        echo ""
        echo "Commands:"
        echo "  http-start     - Start HTTP file server"
        echo "  http-stop      - Stop HTTP server"
        echo "  ftp-start      - Start FTP server"
        echo "  ftp-stop       - Stop FTP server"
        echo "  status         - Check server status"
        echo "  send <file> <target> - Send file via SCP"
        echo "  receive <source> <dest> - Receive file via SCP"
        ;;
esac
