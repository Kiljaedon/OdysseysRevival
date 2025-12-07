# Version System Specification

## Overview
The version system ensures client and server are always running the same version. Mismatched versions are rejected at login before authentication.

## Version Files (Must Stay In Sync)

| File | Purpose | When Updated |
|------|---------|--------------|
| `version.txt` | Master version file | Manually or by deploy script |
| `project.godot` | Godot project version | By deploy scripts |
| `source/common/version.gd` | Runtime version check | By deploy scripts |

## Current Version: 0.1.2

## How It Works

### 1. Client Login Flow
```
login_screen.gd
    ↓
Sends: username, password, GameVersion.GAME_VERSION
    ↓
server_connection.gd (request_login RPC)
    ↓
auth_network_service.gd
    ↓
Version check BEFORE authentication
    ↓
If mismatch → Reject with error message
If match → Proceed to authenticate
```

### 2. Server Validation (auth_network_service.gd)
```gdscript
func handle_login(username, password, client_version):
    # Check version FIRST
    if client_version != GameVersion.GAME_VERSION:
        send_login_response(peer_id, false, "Version mismatch!", {})
        return

    # Only authenticate if versions match
    server_world.request_login(username, password)
```

### 3. Version Constant (source/common/version.gd)
```gdscript
class_name GameVersion
extends RefCounted

const GAME_VERSION: String = "0.1.2"
const MIN_COMPATIBLE_VERSION: String = "0.1.2"

static func get_mismatch_message(client_version, server_version):
    return "Version mismatch! Client: %s, Server: %s. Please update your game."
```

## Version Sync Process

### When Deploying (Automatic)
1. Run `deploy_client_production.bat` or `deploy_client_dev.bat`
2. Script reads `version.txt`
3. Prompts Y/N to increment version
4. Syncs version to:
   - `project.godot`
   - `source/common/version.gd`
5. Builds and uploads

### Manual Version Change
1. Edit `version.txt` with new version
2. Run deploy script - it will sync other files automatically

## Limitations

### During Development
- Version files are NOT automatically synced when editing in Godot
- Sync only happens when running deploy scripts
- Local testing is safe (client/server use same version.gd)

### What Could Desync
- Editing `version.txt` without deploying
- Manually editing `version.gd` without updating `version.txt`
- Deploying client but not updating server (or vice versa)

### Protection
- Deploy scripts check for sync before building
- Warn if files are mismatched
- Auto-sync before build proceeds

## File Locations

```
GoldenSunMMO-Dev/
├── version.txt                              # Master version
├── project.godot                            # config/version setting
├── source/
│   └── common/
│       ├── version.gd                       # Runtime constants
│       └── network/
│           ├── server_connection.gd         # RPC with version param
│           └── services/
│               └── auth_network_service.gd  # Version validation
├── deploy_client_production.bat             # Player client deploy
└── deploy_client_dev.bat                    # Dev client deploy
```

## Error Messages

### Legacy Client (No Version Sent)
> "Version mismatch! Your client is outdated. Please download the latest version."

### Version Mismatch
> "Version mismatch! Client: 0.1.1, Server: 0.1.2. Please update your game."

## Deployment Workflow

### Player Client Update
1. Click "Push Player Client" in gateway OR run `deploy_client_production.bat`
2. Answer Y/N to increment version
3. Confirm deployment
4. Script syncs all version files
5. Builds release client
6. Uploads to R2 production channel

### Dev Client Update
1. Click "Push Dev Client" in gateway OR run `deploy_client_dev.bat`
2. Same flow as production
3. Uploads to R2 dev channel
4. Version tagged as `X.X.X-dev`

## Server Update Requirement
When you deploy a new client version:
1. Server's `version.gd` must also be updated
2. Restart server with new code
3. Otherwise clients will get version mismatch errors

## Testing Version Enforcement
1. Temporarily change client's `version.gd` to different version
2. Try to login
3. Should see mismatch error
4. Login rejected before password check
