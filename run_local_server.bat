@echo off
set "PROJECT_PATH=C:/Users/dougd/GoldenSunMMO/GoldenSunMMO-Dev/"
set "SCENE=source/server/server_world.tscn"
set "VBS_NAME=launch_server_hidden.vbs"

:: Find Godot Executable
if exist "C:\Godot\Godot_v4.5-stable_mono_win64.exe" (
    set "GODOT=C:\Godot\Godot_v4.5-stable_mono_win64.exe"
    goto :found
)
if exist "C:\Program Files\Godot\Godot_v4.5-stable_mono_win64.exe" (
    set "GODOT=C:\Program Files\Godot\Godot_v4.5-stable_mono_win64.exe"
    goto :found
)
if exist "C:\Godot\Godot_v4.5.1-stable_win64.exe" (
    set "GODOT=C:\Godot\Godot_v4.5.1-stable_win64.exe"
    goto :found
)
if exist "C:\Program Files\Godot\Godot_v4.5.1-stable_win64.exe" (
    set "GODOT=C:\Program Files\Godot\Godot_v4.5.1-stable_win64.exe"
    goto :found
)

echo ERROR: Godot executable not found!
pause
exit

:found
:: Launch via VBS to hide console
start wscript "%~dp0%VBS_NAME%" "%GODOT%" "%PROJECT_PATH%" "%SCENE%"
exit
