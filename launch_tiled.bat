@echo off
echo Launching Tiled Map Editor for Golden Sun MMO...
"%~dp0tools\tiled\tiled.exe" "%~dp0tiled_projects\golden_sun_mmo.tiled-project"
if errorlevel 1 (
    echo Error: Could not launch Tiled. Make sure it's extracted in the tools/tiled folder.
    pause
)