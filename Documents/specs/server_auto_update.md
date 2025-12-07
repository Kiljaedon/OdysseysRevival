# Specification: Automated Server-Side Update System

## 1. Objective
Replace the unreliable client-side "push" deployment (via SSH/Rclone) with a robust **Server-Side "Pull"** mechanism triggered by the game client. This resolves the persistent "socket error" issues on the Windows developer machine.

## 2. Problem Analysis
*   **Current State:** The client uses `rclone` (SFTP) to push file updates to the server and a signal file to restart it.
*   **Failure Point:** The Windows networking stack interacts poorly with the SSH tools, causing `getsockname failed: Not a socket` errors, preventing deployment.
*   **Requirement:** A "One-Click" update button in the Game Client that is independent of local SSH configuration.

## 3. Proposed Architecture: "Trigger & Pull"
Instead of the client *pushing* files, the client will *signal* the server to *pull* updates from the Git repository.

### 3.1. Data Flow
1.  **Developer:** Commits and pushes changes to GitHub (`git push`).
2.  **Client:** Developer clicks "Update Server" in the Game Client.
3.  **Signal:** Client sends an authenticated HTTP POST request to the Game Server (Port 9124 - Admin HTTP).
4.  **Server:**
    *   Receives request.
    *   Validates Admin Token.
    *   Executes local shell script (`update_and_restart.sh`).
5.  **Execution:**
    *   Script performs `git pull origin main`.
    *   Script triggers the existing `restart_self.sh` watchdog.

### 3.2. Components

#### A. Server-Side Admin Listener
*   **File:** `source/server/server_world.gd` (or a new manager `source/server/managers/admin_manager.gd`)
*   **Technology:** `addons/httpserver` (Godot HTTP Server)
*   **Port:** `9124` (Separate from Game Port 9123 and Gateway Port 9088)
*   **Endpoint:** `POST /admin/update`
*   **Security:** Requires `Authorization: Bearer <ADMIN_TOKEN>` header.

#### B. Update Script (`scripts/update_and_restart.sh`)
A Linux shell script residing on the server:
```bash
#!/bin/bash
# 1. Update Code
git fetch origin
git reset --hard origin/main  # Force sync to match repo
# 2. Restart
./restart_self.sh
```

#### C. Client-Side Trigger
*   **File:** `source/client/tools/developer_tools_service.gd`
*   **Action:** Modify `deploy_to_remote` to send the HTTP request instead of launching `deploy_to_remote.bat`.

## 4. Implementation Plan

### Phase 1: Server Preparation
1.  **Create Manager:** `source/server/managers/admin_manager.gd` to handle the HTTP server.
2.  **Integrate:** Add `admin_manager` to `server_world.gd`.
3.  **Scripting:** Create `scripts/update_and_restart.sh` (mocked locally, deployed manually once or via the last working method).

### Phase 2: Client Update
1.  **Update Service:** Rewrite `DeveloperToolsService.deploy_to_remote()` to use `HTTPRequest`.
2.  **Config:** Add `admin_token` to `credentials_utils.gd` or `server_config`.

### Phase 3: Verification
1.  **Test Local:** Run server locally, click button, verify "git pull" is attempted (mocked).
2.  **Deploy:** Push changes.
3.  **Test Remote:** Click button, verify remote server restarts and has new code.

## 5. Security Considerations
*   The `ADMIN_TOKEN` must be kept secret.
*   The HTTP server is lightweight and only exposes specific admin routes.
