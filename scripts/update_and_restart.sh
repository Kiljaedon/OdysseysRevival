#!/bin/bash
# This script is executed on the Linux game server to update code from Git and restart.

GAME_DIR="/home/gameserver/odysseys_server_dev"
RESTART_SCRIPT="$GAME_DIR/restart_self.sh"

echo "[SERVER_UPDATE] Starting code update and restart sequence."

# Navigate to the game directory
cd "$GAME_DIR" || { echo "[SERVER_UPDATE] ERROR: Failed to change to game directory."; exit 1; }

echo "[SERVER_UPDATE] Current directory: $(pwd)"

# Ensure the git repository is clean or stash changes if needed
# For now, we assume a clean state for simplicity.
# If there are local changes, 'git pull' might fail.
# A 'git reset --hard origin/main' can be added if local changes are undesired.

echo "[SERVER_UPDATE] Pulling latest code from Git..."
git pull origin main || { echo "[SERVER_UPDATE] ERROR: Git pull failed."; exit 1; }

echo "[SERVER_UPDATE] Code updated. Initiating server restart via $RESTART_SCRIPT."

# Execute the existing restart script
# This script should ideally handle graceful shutdown and restart of the Godot server
"$RESTART_SCRIPT" || { echo "[SERVER_UPDATE] ERROR: Restart script execution failed."; exit 1; }

echo "[SERVER_UPDATE] Update and restart sequence initiated successfully."
