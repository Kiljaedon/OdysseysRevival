@echo off
:: Kill any existing Godot server processes silently
taskkill /F /IM Godot_v4.5.1-stable_win64.exe 2>nul
taskkill /F /IM godot.exe 2>nul
timeout /t 1 /nobreak >nul

:: Launch Godot with START to hide this console window

if exist "C:\Program Files\Godot\Godot_v4.5.1-stable_win64.exe" (
    start "" "C:\Program Files\Godot\Godot_v4.5.1-stable_win64.exe" --path "C:/Users/dougd/GoldenSunMMO/GoldenSunMMO-Dev/" source/server/server_world.tscn
    exit
)

if exist "C:\Godot\Godot_v4.5.1-stable_win64.exe" (
    start "" "C:\Godot\Godot_v4.5.1-stable_win64.exe" --path "C:/Users/dougd/GoldenSunMMO/GoldenSunMMO-Dev/" source/server/server_world.tscn
    exit
)

:: Try the running Godot executable
if exist "C:/Godot/Godot_v4.5-stable_mono_win64.exe" (
    start "" "C:/Godot/Godot_v4.5-stable_mono_win64.exe" --path "C:/Users/dougd/GoldenSunMMO/GoldenSunMMO-Dev/" source/server/server_world.tscn
    exit
)

echo ERROR: Godot executable not found!
pause
