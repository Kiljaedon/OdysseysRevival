@echo off
REM Build Windows Client for Odysseys Revival
REM This builds the client ONLY (no server files included)

echo ========================================
echo Building Odysseys Revival Windows Client
echo ========================================
echo.

REM Find Godot executable
set GODOT_PATH="C:\Godot\Godot_v4.5-stable_mono_win64.exe"
if not exist %GODOT_PATH% (
    echo ERROR: Godot not found at %GODOT_PATH%
    echo Please update GODOT_PATH in this script
    pause
    exit /b 1
)

REM Set paths
set PROJECT_PATH=%~dp0
set BUILD_PATH=%PROJECT_PATH%builds\WindowsClient\OdysseysRevival.exe

echo Project: %PROJECT_PATH%
echo Output: %BUILD_PATH%
echo.

REM Create builds directory
if not exist "%PROJECT_PATH%builds\WindowsClient\" mkdir "%PROJECT_PATH%builds\WindowsClient\"

echo Starting export (client only, excluding server files)...
%GODOT_PATH% --headless --export-release "Windows Client (Release)" "%BUILD_PATH%"

if %errorlevel% neq 0 (
    echo.
    echo ERROR: Export failed!
    pause
    exit /b 1
)

echo.
echo ========================================
echo Windows Client Build Complete!
echo ========================================
echo.
echo Client created at: %BUILD_PATH%
echo.
echo Next steps:
echo 1. Test locally first (connect to 127.0.0.1)
echo 2. Upload to itch.io for distribution
echo 3. Players download via itch.io app (auto-updates)
echo.
pause
