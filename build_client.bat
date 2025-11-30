@echo off
REM Build Test Client for Odysseys Revival
echo ========================================
echo Building Odysseys Revival Test Client
echo ========================================
echo.

REM Find Godot executable
set GODOT_PATH="C:\Program Files\Godot\Godot_v4.5-stable_mono_win64.exe"
if not exist %GODOT_PATH% (
    echo ERROR: Godot not found at %GODOT_PATH%
    echo Please update GODOT_PATH in this script to point to your Godot installation
    pause
    exit /b 1
)

REM Set project path
set PROJECT_PATH=%~dp0
set BUILD_PATH=%PROJECT_PATH%builds\TestClient\OdysseysRevival.exe

echo Project: %PROJECT_PATH%
echo Output: %BUILD_PATH%
echo.

REM Create builds directory if needed
if not exist "%PROJECT_PATH%builds\TestClient\" mkdir "%PROJECT_PATH%builds\TestClient\"

echo Starting export...
%GODOT_PATH% --headless --export-release "Windows Desktop" "%BUILD_PATH%"

if %errorlevel% neq 0 (
    echo.
    echo ERROR: Export failed!
    echo.
    echo You need to set up the export preset first:
    echo 1. Open project in Godot
    echo 2. Go to Project ^> Export
    echo 3. Add "Windows Desktop" preset
    echo 4. Save the preset
    echo 5. Then run this script again
    pause
    exit /b 1
)

echo.
echo ========================================
echo Build Complete!
echo ========================================
echo.
echo Test client created at:
echo %BUILD_PATH%
echo.
echo To test:
echo 1. Run server in Godot (Gateway ^> Development Tools ^> Server)
echo 2. Run OdysseysRevival.exe
echo.
pause
