#!/bin/bash
# Watchdog Script for Odyssey Revival Server
# Usage: ./watchdog.sh &

WATCH_DIR="/home/gameserver/odysseys_server_dev"
SIGNAL_FILE="$WATCH_DIR/RESTART_REQUIRED.signal"
STOP_SCRIPT="/home/gameserver/scripts/stop_dev.sh"
START_SCRIPT="/home/gameserver/scripts/start_dev.sh"

echo "Watchdog started. Monitoring $SIGNAL_FILE"

while true; do
    if [ -f "$SIGNAL_FILE" ]; then
        echo "Restart signal detected!"
        
        # 1. Remove signal immediately to prevent loops
        rm "$SIGNAL_FILE"
        
        # 2. Stop Server
        echo "Stopping server..."
        $STOP_SCRIPT
        
        # 3. Wait for full stop
        sleep 5
        
        # 4. Start Server
        echo "Starting server..."
        $START_SCRIPT
        
        echo "Restart complete."
    fi
    
    # Check every 5 seconds
    sleep 5
done
