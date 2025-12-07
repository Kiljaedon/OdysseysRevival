@echo off
echo ==========================================
echo ODYSSEYS REVIVAL - PRODUCTION BUILD SYSTEM
echo ==========================================

:: Configuration
set GODOT_PATH="C:\Godot\Godot_v4.5-stable_mono_win64.exe"
set EXPORT_PATH_WIN="builds/WindowsClient/OdysseysRevival.exe"
set EXPORT_PATH_LINUX="builds/LinuxServer/odysseys_revival_server.x86_64"

:: Directories
if not exist "builds\WindowsClient" mkdir "builds\WindowsClient"
if not exist "builds\LinuxServer" mkdir "builds\LinuxServer"

echo.
echo [1/2] Building Windows Production Client...
%GODOT_PATH% --headless --export-release "Windows Client (Release)" %EXPORT_PATH_WIN%
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Windows Client build failed!
    pause
    exit /b %ERRORLEVEL%
)
echo SUCCESS.

echo.
echo [2/2] Building Linux Headless Server...
%GODOT_PATH% --headless --export-release "Linux Server (Headless)" %EXPORT_PATH_LINUX%
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Linux Server build failed!
    pause
    exit /b %ERRORLEVEL%
)
echo SUCCESS.

echo.
echo ==========================================
echo BUILD COMPLETE
echo Client: %EXPORT_PATH_WIN%
echo Server: %EXPORT_PATH_LINUX%
echo ==========================================
pause
