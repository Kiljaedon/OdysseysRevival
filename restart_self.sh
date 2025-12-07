#!/bin/bash
# Self-Restart Script
# Called by the Godot Server process before it quits.

# Wait for the old process to fully die
sleep 3

# Trigger the standard stop/start scripts explicitly with sh
# This ensures they run even if +x permission is lost
sh /home/gameserver/scripts/stop_dev.sh
sleep 2
sh /home/gameserver/scripts/start_dev.sh
