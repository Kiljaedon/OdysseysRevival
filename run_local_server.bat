@echo off
:: Launch Godot server instance with console output visible

:: Try mono CONSOLE version first (4.5) - shows output in cmd window
if exist "C:\Godot\Godot_v4.5-stable_mono_win64_console.exe" (
    "C:\Godot\Godot_v4.5-stable_mono_win64_console.exe" --path "C:/Users/dougd/GoldenSunMMO/GoldenSunMMO-Dev/" source/server/server_world.tscn
    pause
    exit
)

:: Try mono version (4.5)
if exist "C:\Godot\Godot_v4.5-stable_mono_win64.exe" (
    start "" "C:\Godot\Godot_v4.5-stable_mono_win64.exe" --path "C:/Users/dougd/GoldenSunMMO/GoldenSunMMO-Dev/" source/server/server_world.tscn
    exit
)

if exist "C:\Program Files\Godot\Godot_v4.5-stable_mono_win64.exe" (
    start "" "C:\Program Files\Godot\Godot_v4.5-stable_mono_win64.exe" --path "C:/Users/dougd/GoldenSunMMO/GoldenSunMMO-Dev/" source/server/server_world.tscn
    exit
)

:: Try non-mono version (4.5.1)
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
