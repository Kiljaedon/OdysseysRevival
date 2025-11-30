@echo off
title Golden Sun MMO - Local Server
echo ========================================
echo   Golden Sun MMO - Local Development Server
echo   Port: 9043
echo ========================================
echo.
echo Starting server...
echo Press Ctrl+C to stop the server
echo.

:: Try common Godot installation paths
if exist "C:\Program Files\Godot\Godot_v4.5.1-stable_win64.exe" (
    "C:\Program Files\Godot\Godot_v4.5.1-stable_win64.exe" --headless source/server/server_world.tscn
    goto :end
)

if exist "C:\Godot\Godot_v4.5.1-stable_win64.exe" (
    "C:\Godot\Godot_v4.5.1-stable_win64.exe" --headless source/server/server_world.tscn
    goto :end
)

:: Try to find Godot in PATH
where godot >nul 2>nul
if %ERRORLEVEL% EQU 0 (
    godot --headless source/server/server_world.tscn
    goto :end
)

:: Godot not found - prompt user
echo.
echo ERROR: Godot executable not found!
echo.
echo Please edit this script and set the correct path to Godot, or
echo drag your Godot.exe onto this window and press Enter:
echo.
set /p GODOT_PATH="Godot path: "
"%GODOT_PATH%" --headless source/server/server_world.tscn

:end
pause
