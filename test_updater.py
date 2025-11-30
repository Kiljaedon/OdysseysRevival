"""
Test the updater system locally

This creates a fake initial version and then a fake update
to verify the updater downloads and installs patches correctly.
"""

import json
import os
import shutil
from pathlib import Path

def setup_test():
    """Create test update files"""
    
    # Create updates directory
    updates_dir = Path("updates")
    updates_dir.mkdir(exist_ok=True)
    
    # Create version 0.0.9 (older than client's 0.1.0)
    print("Creating test version 0.0.9...")
    version_data = {
        "version": "0.0.9",
        "patch_url": "http://127.0.0.1:8080/updates/patch_0.0.9.pck",
        "changelog": [
            "This is an old version - client should skip",
        ],
        "required": False
    }
    
    with open(updates_dir / "version.json", 'w') as f:
        json.dump(version_data, f, indent=2)
    
    print("✅ Created version.json (v0.0.9 - should be skipped)")
    print()
    print("To test updater:")
    print("1. Run: python update_server.py")
    print("2. Export and run OdysseyRevival.exe")
    print("3. Should show: 'Game is up to date!' (0.1.0 > 0.0.9)")
    print()
    print("To test actual update:")
    print("1. Change version.json to '0.2.0'")
    print("2. Create a dummy patch_0.2.0.pck file")
    print("3. Restart client - should download update")

def create_fake_update():
    """Create a fake newer version for testing download"""
    updates_dir = Path("updates")
    updates_dir.mkdir(exist_ok=True)
    
    # Create version 0.2.0 (newer than client's 0.1.0)
    print("Creating test version 0.2.0...")
    version_data = {
        "version": "0.2.0",
        "patch_url": "http://127.0.0.1:8080/updates/patch_0.2.0.pck",
        "changelog": [
            "TEST UPDATE",
            "This is a fake update to test the updater",
            "You should see download progress"
        ],
        "required": False
    }
    
    with open(updates_dir / "version.json", 'w') as f:
        json.dump(version_data, f, indent=2)
    
    # Create a fake .pck file (just some dummy data)
    fake_pck = updates_dir / "patch_0.2.0.pck"
    with open(fake_pck, 'wb') as f:
        f.write(b"FAKE_PCK_FILE" * 1000)  # ~13KB fake file
    
    print("✅ Created version.json (v0.2.0 - client should update)")
    print(f"✅ Created fake patch file: {fake_pck}")
    print()
    print("Now:")
    print("1. Make sure update_server.py is running")
    print("2. Launch OdysseyRevival.exe")
    print("3. Watch updater detect v0.2.0 > v0.1.0")
    print("4. Should download and install fake patch")
    print("5. Click PLAY to continue to game")

if __name__ == '__main__':
    print("=" * 60)
    print("UPDATER TEST SETUP")
    print("=" * 60)
    print()
    print("Choose test:")
    print("1. Test 'up to date' (v0.0.9 - older)")
    print("2. Test update download (v0.2.0 - newer)")
    print()
    
    choice = input("Enter 1 or 2: ").strip()
    
    if choice == "1":
        setup_test()
    elif choice == "2":
        create_fake_update()
    else:
        print("Invalid choice")
