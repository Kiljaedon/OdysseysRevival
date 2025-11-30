"""
Automatic Update Publisher for Odyssey Revival
Watches the Godot project, auto-exports PCK, and publishes updates

Usage:
    python auto_publisher.py

This will:
1. Watch for file changes in your project
2. Auto-export PCK when changes detected
3. Auto-increment version
4. Update version.json
5. Serve files via HTTP
"""

import os
import json
import subprocess
import time
import threading
from http.server import HTTPServer, SimpleHTTPRequestHandler
from pathlib import Path
import hashlib

class UpdatePublisher:
    def __init__(self):
        self.project_dir = Path.cwd()
        self.updates_dir = self.project_dir / "updates"
        self.updates_dir.mkdir(exist_ok=True)
        
        self.version_file = self.updates_dir / "version.json"
        self.current_version = [0, 1, 0]  # [major, minor, patch]
        self.last_hash = None
        self.godot_exe = self.find_godot()
        
        self.load_current_version()
    
    def find_godot(self):
        """Find Godot executable"""
        # Common Godot locations
        possible_paths = [
            r"C:\Program Files\Godot\Godot_v4.5-stable_mono_win64.exe",
            r"C:\Godot\Godot_v4.5-stable_mono_win64.exe",
            r"C:\Program Files\Godot_v4.5-stable_mono_win64.exe",
        ]
        
        for path in possible_paths:
            if os.path.exists(path):
                return path
        
        # Try to find in PATH
        try:
            result = subprocess.run(['where', 'godot'], capture_output=True, text=True)
            if result.returncode == 0:
                return result.stdout.strip().split('\n')[0]
        except:
            pass
        
        return None
    
    def load_current_version(self):
        """Load current version from version.json"""
        if self.version_file.exists():
            with open(self.version_file, 'r') as f:
                data = json.load(f)
                version_str = data.get('version', '0.1.0')
                parts = version_str.split('.')
                self.current_version = [int(p) for p in parts]
    
    def increment_version(self):
        """Increment patch version"""
        self.current_version[2] += 1
        return '.'.join(map(str, self.current_version))
    
    def get_version_string(self):
        """Get current version as string"""
        return '.'.join(map(str, self.current_version))
    
    def calculate_project_hash(self):
        """Calculate hash of project files to detect changes"""
        hash_md5 = hashlib.md5()
        
        # Watch these directories for changes
        watch_dirs = ['source', 'assets']
        
        for watch_dir in watch_dirs:
            dir_path = self.project_dir / watch_dir
            if not dir_path.exists():
                continue
            
            for root, dirs, files in os.walk(dir_path):
                # Skip hidden and build directories
                dirs[:] = [d for d in dirs if not d.startswith('.') and d != '__pycache__']
                
                for file in sorted(files):
                    # Only watch .gd, .tscn, .tres files
                    if file.endswith(('.gd', '.tscn', '.tres', '.png', '.jpg')):
                        filepath = Path(root) / file
                        try:
                            with open(filepath, 'rb') as f:
                                hash_md5.update(f.read())
                        except:
                            pass
        
        return hash_md5.hexdigest()
    
    def export_pck(self, version):
        """Export PCK using Godot"""
        if not self.godot_exe:
            print("❌ Godot executable not found! Please set GODOT_PATH")
            return False
        
        pck_path = self.updates_dir / f"patch_{version}.pck"
        
        print(f"📦 Exporting PCK to {pck_path}...")
        
        try:
            # Export PCK only
            result = subprocess.run([
                self.godot_exe,
                '--headless',
                '--export-pack',
                'Windows Desktop',
                str(pck_path)
            ], capture_output=True, text=True, cwd=str(self.project_dir))
            
            if result.returncode == 0 and pck_path.exists():
                print(f"✅ PCK exported successfully: {pck_path}")
                return True
            else:
                print(f"❌ Export failed: {result.stderr}")
                return False
        except Exception as e:
            print(f"❌ Export error: {e}")
            return False
    
    def update_version_json(self, version, changelog):
        """Update version.json with new version"""
        version_data = {
            "version": version,
            "patch_url": f"http://127.0.0.1:8080/updates/patch_{version}.pck",
            "changelog": changelog,
            "required": False,
            "published": time.strftime("%Y-%m-%d %H:%M:%S")
        }
        
        with open(self.version_file, 'w') as f:
            json.dump(version_data, f, indent=2)
        
        print(f"✅ Updated version.json to v{version}")
    
    def publish_update(self):
        """Export and publish a new update"""
        print("\n" + "="*50)
        print("🚀 PUBLISHING UPDATE")
        print("="*50)
        
        # Increment version
        new_version = self.increment_version()
        
        # Export PCK
        if not self.export_pck(new_version):
            # Revert version on failure
            self.current_version[2] -= 1
            return False
        
        # Auto-generate changelog from git (if available)
        changelog = ["Auto-update: Changes detected"]
        try:
            result = subprocess.run(
                ['git', 'log', '-1', '--pretty=%B'],
                capture_output=True, text=True, cwd=str(self.project_dir)
            )
            if result.returncode == 0 and result.stdout.strip():
                changelog = [result.stdout.strip()]
        except:
            pass
        
        # Update version file
        self.update_version_json(new_version, changelog)
        
        print(f"✅ Update v{new_version} published!")
        print("="*50 + "\n")
        
        return True
    
    def watch_for_changes(self):
        """Watch project for changes"""
        print("👀 Watching for changes...")
        self.last_hash = self.calculate_project_hash()
        
        while True:
            time.sleep(5)  # Check every 5 seconds
            
            current_hash = self.calculate_project_hash()
            
            if current_hash != self.last_hash:
                print("\n📝 Changes detected!")
                time.sleep(2)  # Wait a bit for file operations to complete
                
                self.publish_update()
                self.last_hash = current_hash

class UpdateHandler(SimpleHTTPRequestHandler):
    def do_GET(self):
        """Handle GET requests for updates"""
        if self.path.startswith('/updates/'):
            file_path = self.path[9:]
            full_path = os.path.join('updates', file_path)
            
            if os.path.exists(full_path):
                self.send_response(200)
                
                if file_path.endswith('.json'):
                    self.send_header('Content-type', 'application/json')
                elif file_path.endswith('.pck'):
                    self.send_header('Content-type', 'application/octet-stream')
                
                self.end_headers()
                
                with open(full_path, 'rb') as f:
                    self.wfile.write(f.read())
            else:
                self.send_response(404)
                self.end_headers()
        else:
            self.send_response(404)
            self.end_headers()
    
    def log_message(self, format, *args):
        """Suppress HTTP logs"""
        pass

def start_http_server():
    """Start HTTP server in background"""
    server_address = ('', 8080)
    httpd = HTTPServer(server_address, UpdateHandler)
    print("🌐 Update server running on http://localhost:8080")
    httpd.serve_forever()

def main():
    print("=" * 60)
    print("ODYSSEY REVIVAL - AUTOMATIC UPDATE PUBLISHER")
    print("=" * 60)
    
    publisher = UpdatePublisher()
    
    if not publisher.godot_exe:
        print("\n⚠️  WARNING: Godot executable not found!")
        print("Please set the Godot path in the script or add it to PATH")
        godot_path = input("Enter Godot executable path (or press Enter to exit): ").strip()
        if godot_path and os.path.exists(godot_path):
            publisher.godot_exe = godot_path
        else:
            return
    
    print(f"✅ Godot found: {publisher.godot_exe}")
    print(f"📁 Updates directory: {publisher.updates_dir}")
    print(f"📌 Current version: v{publisher.get_version_string()}")
    print()
    
    # Start HTTP server in background thread
    server_thread = threading.Thread(target=start_http_server, daemon=True)
    server_thread.start()
    
    print("🔄 Auto-publish enabled!")
    print("💡 Make changes in Godot editor and save - updates publish automatically")
    print("⏱️  Checking for changes every 5 seconds...")
    print("\nPress Ctrl+C to stop\n")
    
    try:
        publisher.watch_for_changes()
    except KeyboardInterrupt:
        print("\n\n👋 Shutting down...")

if __name__ == '__main__':
    main()
