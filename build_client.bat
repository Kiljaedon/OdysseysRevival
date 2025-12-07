@echo off
setlocal EnableDelayedExpansion
title Odysseys Revival - Build Test Client

:: ========================================
::   BUILD TEST CLIENT
::   Quick local build for testing
:: ========================================

:: Godot paths to try
set "GODOT_PATH_1=C:\Godot\Godot_v4.5-stable_mono_win64.exe"
set "GODOT_PATH_2=C:\Program Files\Godot\Godot_v4.5-stable_mono_win64.exe"
set "GODOT_PATH_3=C:\Godot\Godot_v4.5-stable_win64.exe"

echo ========================================
echo   Building Odysseys Revival Test Client
echo ========================================
echo.

:: Find Godot
set "GODOT_PATH="
if exist "%GODOT_PATH_1%" set "GODOT_PATH=%GODOT_PATH_1%"
if exist "%GODOT_PATH_2%" set "GODOT_PATH=%GODOT_PATH_2%"
if exist "%GODOT_PATH_3%" set "GODOT_PATH=%GODOT_PATH_3%"

if "%GODOT_PATH%"=="" (
    echo [ERROR] Godot not found! Checked:
    echo         - %GODOT_PATH_1%
    echo         - %GODOT_PATH_2%
    echo         - %GODOT_PATH_3%
    pause
    exit /b 1
)
echo [OK] Godot: %GODOT_PATH%

:: Check export presets
if not exist "export_presets.cfg" (
    echo.
    echo [ERROR] export_presets.cfg not found!
    echo.
    echo You need to set up export presets first:
    echo 1. Open project in Godot
    echo 2. Go to Project ^> Export
    echo 3. Add "Windows Desktop" preset
    echo 4. Save and close
    echo 5. Run this script again
    pause
    exit /b 1
)

:: Create build directory
set "BUILD_PATH=builds\TestClient"
if not exist "%BUILD_PATH%" mkdir "%BUILD_PATH%"

echo.
echo [BUILD] Starting export...
"%GODOT_PATH%" --headless --export-release "Windows Desktop" "%BUILD_PATH%\OdysseysRevival.exe"

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERROR] Export failed!
    echo.
    echo Check that you have a "Windows Desktop" export preset configured.
    pause
    exit /b 1
)

echo.
echo ========================================
echo   BUILD COMPLETE
echo ========================================
echo.
echo Test client created at:
echo   %CD%\%BUILD_PATH%\OdysseysRevival.exe
echo.
echo To test:
echo   1. Run server (Gateway ^> Dev Tools ^> Start Local Server)
echo   2. Run %BUILD_PATH%\OdysseysRevival.exe
echo.
pause
exit /b 0
