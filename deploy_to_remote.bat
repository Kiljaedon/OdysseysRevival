@echo off
title Golden Sun MMO - Deploying to Remote Server
echo ========================================
echo   Deploying to Odyssey Server
echo ========================================
echo.

echo [1/6] Syncing source files...
rsync -avz --delete --exclude=".godot" "C:/Users/dougd/GoldenSunMMO/GoldenSunMMO-Dev/source" odyssey:/home/gameserver/odysseys_server_dev/source/
if %ERRORLEVEL% NEQ 0 (
    echo rsync failed, trying scp...
    scp -r "C:/Users/dougd/GoldenSunMMO/GoldenSunMMO-Dev/source" odyssey:/home/gameserver/odysseys_server_dev/
)

echo.
echo [2/6] Syncing data files...
rsync -avz "C:/Users/dougd/GoldenSunMMO/GoldenSunMMO-Dev/data/" odyssey:/home/gameserver/odysseys_server_dev/data/

echo.
echo [3/6] Syncing addons (map editor, sprite editor tools)...
rsync -avz --delete "C:/Users/dougd/GoldenSunMMO/GoldenSunMMO-Dev/addons" odyssey:/home/gameserver/odysseys_server_dev/addons/

echo.
echo [4/6] Syncing sprite maker tool files...
scp "C:/Users/dougd/GoldenSunMMO/GoldenSunMMO-Dev/odyssey_sprite_maker.gd" odyssey:/home/gameserver/odysseys_server_dev/
scp "C:/Users/dougd/GoldenSunMMO/GoldenSunMMO-Dev/odyssey_sprite_maker.tscn" odyssey:/home/gameserver/odysseys_server_dev/

echo.
echo [5/6] Syncing assets...
rsync -avz "C:/Users/dougd/GoldenSunMMO/GoldenSunMMO-Dev/assets-odyssey/" odyssey:/home/gameserver/odysseys_server_dev/assets-odyssey/

echo.
echo [6/6] Restarting remote server...
ssh odyssey "killall -9 Godot_v4.5.1-stable_linux.x86_64 2>/dev/null; sleep 2; cd /home/gameserver/odysseys_server_dev/ && nohup /opt/Godot_v4.5.1-stable_linux.x86_64 --headless source/server/server_world.tscn > server_output.log 2>&1 & sleep 3 && pgrep -c Godot && echo 'Server restarted successfully!' || echo 'Server failed to start'"

echo.
echo ========================================
echo   Deployment Complete!
echo   Synced: source, data, addons,
echo          sprite maker, assets
echo ========================================
pause
