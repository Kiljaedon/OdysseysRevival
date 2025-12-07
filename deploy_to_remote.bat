@echo off
title Golden Sun MMO - Deploying to Remote Server (Signal Based)
cd /d "C:/Users/dougd/GoldenSunMMO/GoldenSunMMO-Dev/"

set RCLONE=tools\rclone\rclone.exe
set CONFIG=tools\rclone\rclone.conf

echo ========================================
echo STARTING DEPLOYMENT TO: odyssey (Dev)
echo ========================================

echo 1. Syncing source code via Rclone (SFTP)...
"%RCLONE%" copy source "odyssey_server:/home/gameserver/odysseys_server_dev/source" --config "%CONFIG%" --exclude ".godot/**" --progress

if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Rclone sync failed.
    pause
    exit /b %errorlevel%
)

echo.
echo 2. Signaling server to restart...
echoRESTART > RESTART_REQUIRED.signal
"%RCLONE%" copy RESTART_REQUIRED.signal "odyssey_server:/home/gameserver/odysseys_server_dev/" --config "%CONFIG%"
del RESTART_REQUIRED.signal

echo.
echo ========================================
echo DEPLOYMENT SUCCESSFUL
echo ========================================
echo The server watchdog will detect the signal and restart within 5 seconds.
pause
