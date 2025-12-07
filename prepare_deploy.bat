@echo off
setlocal EnableDelayedExpansion
title Odysseys Revival - Quick Deploy (No Rebuild)

:: ========================================
::   QUICK DEPLOY - Uses existing builds
::   Use this when you've already built
::   and just want to upload
:: ========================================

set "DEPLOY_DIR=deploy"
set "INSTALLER_DIR=deploy\installers"
set "BACKUP_DIR=deploy\backups"
set "RCLONE=tools\rclone\rclone.exe"
set "RCLONE_CONFIG=tools\rclone\rclone.conf"
set "R2_CHANNELS=odyssey_updates:odysseys-updates/channels"
set "R2_INSTALLERS=odyssey_updates:odysseys-updates/installers"

echo ==========================================
echo   ODYSSEYS REVIVAL - QUICK DEPLOY
echo ==========================================
echo   (Uses existing builds - no rebuild)
echo.

:: Check version
if not exist "version.txt" (
    echo [ERROR] version.txt not found!
    pause
    exit /b 1
)
set /p VERSION=<version.txt
echo [OK] Version: %VERSION%

:: Check builds exist
if not exist "builds\WindowsClient\OdysseysRevival.pck" (
    echo [ERROR] No Production build found!
    echo         Run deploy_client_pipeline.bat to build first
    pause
    exit /b 1
)
echo [OK] Builds found

:: Check rclone
if not exist "%RCLONE%" (
    echo [ERROR] rclone not found!
    pause
    exit /b 1
)
if not exist "%RCLONE_CONFIG%" (
    echo [ERROR] rclone.conf not found!
    pause
    exit /b 1
)
echo [OK] rclone configured
echo.

:: Create directories
if not exist "%DEPLOY_DIR%\channels\production" mkdir "%DEPLOY_DIR%\channels\production"
if not exist "%DEPLOY_DIR%\channels\dev" mkdir "%DEPLOY_DIR%\channels\dev"
if not exist "%INSTALLER_DIR%" mkdir "%INSTALLER_DIR%"
if not exist "%BACKUP_DIR%" mkdir "%BACKUP_DIR%"

:: Backup existing
echo [BACKUP] Backing up current versions...
set "BACKUP_NAME=%date:~-4,4%%date:~-10,2%%date:~-7,2%_%time:~0,2%%time:~3,2%"
set "BACKUP_NAME=%BACKUP_NAME: =0%"

if exist "%DEPLOY_DIR%\channels\production\game.pck" (
    copy /Y "%DEPLOY_DIR%\channels\production\game.pck" "%BACKUP_DIR%\game_prod_%BACKUP_NAME%.pck" >nul
)

:: Stage PCK files
echo [STAGE] Staging PCK files...
copy /Y "builds\WindowsClient\OdysseysRevival.pck" "%DEPLOY_DIR%\channels\production\game.pck" >nul

if exist "builds\WindowsDev\OdysseysRevivalDev.pck" (
    copy /Y "builds\WindowsDev\OdysseysRevivalDev.pck" "%DEPLOY_DIR%\channels\dev\game.pck" >nul
) else (
    copy /Y "builds\WindowsClient\OdysseysRevival.pck" "%DEPLOY_DIR%\channels\dev\game.pck" >nul
)

if exist "builds\LinuxServer\odysseys_revival_server.pck" (
    copy /Y "builds\LinuxServer\odysseys_revival_server.pck" "%DEPLOY_DIR%\channels\production\server.pck" >nul
)

:: Generate version files
echo [STAGE] Generating version files...
(
echo {
echo   "version": "%VERSION%",
echo   "force_update": false,
echo   "build_date": "%date% %time%",
echo   "changelog": ["Quick deploy %date%"]
echo }
) > "%DEPLOY_DIR%\channels\production\version.json"

(
echo {
echo   "version": "%VERSION%-dev",
echo   "force_update": true,
echo   "build_date": "%date% %time%",
echo   "changelog": ["Quick deploy %date%"]
echo }
) > "%DEPLOY_DIR%\channels\dev\version.json"

:: Upload
echo.
echo [UPLOAD] Uploading to Cloudflare R2...
"%RCLONE%" sync "%DEPLOY_DIR%\channels" %R2_CHANNELS% --config "%RCLONE_CONFIG%" --progress
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Upload failed!
    pause
    exit /b 1
)

:: Upload installers if they exist
if exist "%INSTALLER_DIR%\OdysseyRevival.zip" (
    echo.
    echo [UPLOAD] Uploading installers...
    "%RCLONE%" sync "%INSTALLER_DIR%" %R2_INSTALLERS% --config "%RCLONE_CONFIG%" --progress
)

echo.
echo ==========================================
echo   QUICK DEPLOY COMPLETE
echo ==========================================
echo   Version: %VERSION%
echo   Time: %date% %time%
echo.
timeout /t 5
exit /b 0
