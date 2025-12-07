# Specification: Production Client & Updater System

## 1. Objective
Create a streamlined, integrated updater system for "Odysseys Revival" that allows:
1.  **Players:** To auto-update their game client from Cloudflare R2 CDN on startup.
2.  **Developers:** To receive "Dev Client" builds with debug tools via a separate channel.
3.  **Version Enforcement:** Client and server MUST have matching versions to connect.

## 2. Architecture (Integrated Option A)
*   **Single Executable:** The distributed file is `OdysseysRevival.exe`.
*   **Startup Flow:**
    1.  App starts -> Loads `source/client/updater/updater_main.tscn`.
    2.  Updater checks R2 for `version.json`.
    3.  If update needed -> Downloads `game.pck` -> Overwrites local `.pck` -> Self-Restarts.
    4.  If up to date -> Loads `source/client/gateway/gateway.tscn` (Main Menu).

## 3. Hosting Structure (Cloudflare R2)

**Base URL:** `https://pub-bfb251fbb7f04473b6eb939aba7ccdfc.r2.dev/`

### 3.1. Directory Layout
```text
/channels/
    production/
        version.json       # {"version": "0.1.2", "force_update": false}
        game.pck           # The main game data (Player Client)
    dev/
        version.json       # {"version": "0.1.2-dev", "force_update": true}
        game.pck           # Developer client data (with debug tools)

/installers/
    OdysseyRevival.zip     # Full player client installer
    OdysseyDevClient.zip   # Full dev client installer
```

### 3.2. Download URLs
- **Player Client:** `https://pub-bfb251fbb7f04473b6eb939aba7ccdfc.r2.dev/installers/OdysseyRevival.zip`
- **Dev Client:** `https://pub-bfb251fbb7f04473b6eb939aba7ccdfc.r2.dev/installers/OdysseyDevClient.zip`

## 4. Version Enforcement System

### 4.1. Single Source of Truth
The version is tracked in THREE files that MUST stay in sync:

| File | Purpose |
|------|---------|
| `version.txt` | Master version - deploy scripts read this |
| `project.godot` | Godot project version - synced by deploy scripts |
| `source/common/version.gd` | Runtime version check - hardwired in code |

### 4.2. Hardwired Version Check (`source/common/version.gd`)
```gdscript
class_name GameVersion
extends RefCounted

## CURRENT GAME VERSION - MUST MATCH version.txt
const GAME_VERSION: String = "0.1.2"

## Minimum compatible version
const MIN_COMPATIBLE_VERSION: String = "0.1.2"

static func is_current_version(version: String) -> bool:
    return version == GAME_VERSION

static func get_mismatch_message(client_version: String, server_version: String) -> String:
    return "Version mismatch! Client: %s, Server: %s. Please update your game." % [client_version, server_version]
```

### 4.3. Client-Server Version Validation
When a client attempts to login:

1. **Client sends version** with login request via `login_screen.gd`:
   ```gdscript
   server_conn.request_login.rpc_id(1, username, password, GameVersion.GAME_VERSION)
   ```

2. **Server validates version** in `auth_network_service.gd`:
   - If no version sent: REJECT (legacy client)
   - If version doesn't match server's `GameVersion.GAME_VERSION`: REJECT
   - If version matches: Proceed with authentication

3. **Rejection message** shown to user:
   > "Version mismatch! Client: 0.1.1, Server: 0.1.2. Please update your game."

## 5. Deploy Scripts

### 5.1. Player Client (`deploy_client_production.bat`)
Deploys the release client for players (no debug tools).

**Flow:**
1. Pre-flight checks (Godot, rclone, version.txt)
2. Version sync check (warns if files out of sync)
3. Y/N prompt to increment version
4. Confirmation showing ALL files to be updated
5. Syncs version to:
   - `project.godot`
   - `source/common/version.gd`
6. Builds Windows Client (Release)
7. Stages PCK and creates version.json
8. Creates installer ZIP
9. Uploads to R2 (production channel)

### 5.2. Dev Client (`deploy_client_dev.bat`)
Deploys the debug client with developer tools.

**Same flow as production**, but:
- Uses `dev` channel instead of `production`
- Builds with debug export (includes dev tools)
- Version tagged as `X.X.X-dev`

### 5.3. Gateway Buttons
The developer gateway has two deploy buttons:
- **"Push Player Client"** -> Runs `deploy_client_production.bat`
- **"Push Dev Client"** -> Runs `deploy_client_dev.bat`

Both open a command window so you can see progress and close when done.

## 6. Version Update Workflow

### 6.1. Automatic (Via Deploy Scripts)
1. Run deploy script (production or dev)
2. Script shows current version, asks Y/N to increment
3. If Y: Patch version incremented (0.1.2 -> 0.1.3)
4. Script syncs ALL version files automatically
5. Build and upload proceed

### 6.2. Manual (If Needed)
1. Edit `version.txt` with new version
2. Run deploy script - it will sync other files
3. OR manually update:
   - `project.godot`: `config/version="X.X.X"`
   - `source/common/version.gd`: `GAME_VERSION` and `MIN_COMPATIBLE_VERSION`

## 7. Client Implementation Details

### 7.1. `game_updater.gd`
- Reads current version from `ProjectSettings.get_setting("application/config/version")`
- Checks R2 `version.json` for latest version
- Downloads `game.pck` if update needed
- Shows real-time progress with download speed
- 30-second stall timeout for failed downloads
- Uses Kenney RPG UI theme (matches login screen)

### 7.2. Production Config
- Production export preset hardcodes server IP `178.156.202.89`
- ConfigManager defaults to this IP for players

## 8. Files Modified for Version Enforcement

| File | Changes |
|------|---------|
| `source/common/version.gd` | NEW - Hardwired version constants |
| `source/common/network/server_connection.gd` | Added `client_version` param to login RPC |
| `source/common/network/services/auth_network_service.gd` | Version validation before auth |
| `source/client/ui/login_screen.gd` | Sends version with login request |
| `deploy_client_production.bat` | Syncs version.gd |
| `deploy_client_dev.bat` | Syncs version.gd |

## 9. Testing Version Enforcement

1. Set client `version.gd` to different version than server
2. Attempt login
3. Should see: "Version mismatch! Client: X.X.X, Server: Y.Y.Y. Please update your game."
4. Login should be rejected BEFORE any authentication attempt

## 10. Security Notes

- Version check happens BEFORE password validation
- Prevents outdated clients from attempting to interact with server
- Reduces attack surface from deprecated protocol versions
- Forces users to stay updated for security patches
