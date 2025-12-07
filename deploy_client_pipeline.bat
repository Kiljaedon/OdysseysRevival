@echo off
cd /d "%~dp0"
setlocal EnableDelayedExpansion
title Odysseys Revival - Client Deployment Pipeline

:: ========================================
::   CONFIGURATION
:: ========================================
:: Server Connection (For Version Check)
set "REMOTE_HOST=178.156.202.89"
set "REMOTE_USER=root"
set "REMOTE_PATH=/home/gameserver/odysseys_server_dev"
set "SSH_KEY=C:\Users\dougd\.ssh\id_rsa"

:: Godot paths to try (in order of preference)
set "GODOT_PATH_1=C:\Godot\Godot_v4.5-stable_mono_win64.exe"
set "GODOT_PATH_2=C:\Program Files\Godot\Godot_v4.5-stable_mono_win64.exe"
set "GODOT_PATH_3=C:\Godot\Godot_v4.5-stable_win64.exe"

:: Build outputs
set "EXPORT_PATH_WIN=builds\WindowsClient\OdysseysRevival.exe"
set "EXPORT_PATH_DEV=builds\WindowsDev\OdysseysRevivalDev.exe"
set "EXPORT_PATH_LINUX=builds\LinuxServer\odysseys_revival_server.x86_64"

:: Deploy locations
set "DEPLOY_DIR=deploy"
set "INSTALLER_DIR=deploy\installers"
set "BACKUP_DIR=deploy\backups"
set "RCLONE=tools\rclone\rclone.exe"
set "RCLONE_CONFIG=tools\rclone\rclone.conf"

:: R2 bucket paths
set "R2_CHANNELS=odyssey_updates:odysseys-updates/channels"
set "R2_INSTALLERS=odyssey_updates:odysseys-updates/installers"

:: Error tracking
set "ERRORS=0"
set "BUILD_SUCCESS=0"

echo ==========================================
echo   ODYSSEYS REVIVAL - CLIENT PIPELINE
echo ==========================================
echo Started: %date% %time%
echo.

:: ========================================
::   PRE-FLIGHT CHECKS
:: ========================================
echo [PRE-FLIGHT] Running checks...

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
    goto :pipeline_failed
)
echo [OK] Godot found: %GODOT_PATH%

:: Check version file
if not exist "version.txt" (
    echo [ERROR] version.txt not found!
    echo         Create it with a version number like: 0.1.0
    goto :pipeline_failed
)

:: Read version
set /p VERSION=<version.txt
echo [OK] Version: %VERSION%

:: Check rclone
if not exist "%RCLONE%" (
    echo [WARN] rclone not found - upload will be skipped
    set "SKIP_UPLOAD=1"
) else if not exist "%RCLONE_CONFIG%" (
    echo [WARN] rclone.conf not found - upload will be skipped
    set "SKIP_UPLOAD=1"
) else (
    echo [OK] rclone configured
    set "SKIP_UPLOAD=0"
)

:: Check export presets
if not exist "export_presets.cfg" (
    echo [ERROR] export_presets.cfg not found!
    echo         Open Godot ^> Project ^> Export and configure presets
    goto :pipeline_failed
)
echo [OK] Export presets found

echo [PRE-FLIGHT] All checks passed!
echo.

:: ========================================
::   VERSION MANAGEMENT
:: ========================================
echo [VERSION] Current: %VERSION%
echo.
choice /C YN /M "Increment version before build?"
if !ERRORLEVEL! EQU 1 (
    :: Parse version (major.minor.patch)
    for /f "tokens=1,2,3 delims=." %%a in ("%VERSION%") do (
        set "V_MAJOR=%%a"
        set "V_MINOR=%%b"
        set "V_PATCH=%%c"
    )
    set /a V_PATCH+=1
    set "VERSION=!V_MAJOR!.!V_MINOR!.!V_PATCH!"
    
    echo [VERSION] Incrementing to: !VERSION!
    
    :: Check for Python
    python --version >nul 2>&1
    if !ERRORLEVEL! NEQ 0 (
        echo [ERROR] Python is not installed or not in PATH!
        echo         Please install Python to use the auto-updater.
        pause
        goto :pipeline_failed
    )

    python ..\DevTools\update_version.py !VERSION!
    if !ERRORLEVEL! NEQ 0 (
        echo [ERROR] Failed to update version files!
        echo         Script: ..\DevTools\update_version.py
        pause
        goto :pipeline_failed
    )
    echo [VERSION] All files (txt, godot, gd) synchronized.
) else (
    :: Even if not incrementing, ensure sync
    echo [VERSION] verifying sync...
    python ..\DevTools\update_version.py %VERSION%
    if !ERRORLEVEL! NEQ 0 (
         echo [ERROR] Sync verification failed!
         pause
         goto :pipeline_failed
    )
)

:: ========================================
::   SERVER GUARD (Check Remote Version)
:: ========================================
echo.
echo [GUARD] Checking Server Version...
if not exist "%SSH_KEY%" (
    echo [WARN] SSH Key not found. Skipping server check.
    echo        (Risk: Client version might not match Server)
) else (
    set "SERVER_VERSION="
    :: Fetch version.txt from server
    ssh -i "%SSH_KEY%" -o StrictHostKeyChecking=no %REMOTE_USER%@%REMOTE_HOST% "cat %REMOTE_PATH%/version.txt" > server_version_check.tmp 2>nul
    
    if exist server_version_check.tmp (
        set /p SERVER_VERSION=<server_version_check.tmp
        del server_version_check.tmp
    )
    
    :: Trim whitespace from server version (simulated by loop)
    for /f "tokens=* delims= " %%a in ("!SERVER_VERSION!") do set "SERVER_VERSION=%%a"

    echo [GUARD] Local Version:  %VERSION%
    echo [GUARD] Server Version: !SERVER_VERSION!

    if "!SERVER_VERSION!" NEQ "%VERSION%" (
        echo.
        echo ========================================================
        echo   [CRITICAL] SERVER VERSION MISMATCH
        echo ========================================================
        echo   The Remote Server is running version: !SERVER_VERSION!
        echo   You are trying to build version:      %VERSION%
        echo.
        echo   YOU MUST UPDATE THE SERVER FIRST!
        echo.
        echo   1. Close this window.
        echo   2. Run 'deploy_to_remote.bat' to push v%VERSION% to the server.
        echo   3. Run this script again (and choose NO to increment).
        echo ========================================================
        pause
        exit /b 1
    ) else (
        echo [GUARD] Server is up to date. Proceeding...
    )
)

:: Create directories
if not exist "builds\WindowsClient" mkdir "builds\WindowsClient"
if not exist "builds\WindowsDev" mkdir "builds\WindowsDev"
if not exist "builds\LinuxServer" mkdir "builds\LinuxServer"
if not exist "%DEPLOY_DIR%" mkdir "%DEPLOY_DIR%"
if not exist "%DEPLOY_DIR%\channels\production" mkdir "%DEPLOY_DIR%\channels\production"
if not exist "%DEPLOY_DIR%\channels\dev" mkdir "%DEPLOY_DIR%\channels\dev"
if not exist "%INSTALLER_DIR%" mkdir "%INSTALLER_DIR%"
if not exist "%BACKUP_DIR%" mkdir "%BACKUP_DIR%"

:: ========================================
::   BUILD PHASE
:: ========================================
echo ==========================================
echo   BUILD PHASE
echo ==========================================

echo.
echo [BUILD 1/3] Windows Client (Production)...
"%GODOT_PATH%" --headless --export-release "Windows Client (Release)" "%EXPORT_PATH_WIN%"
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Windows Client build failed!
    set /a ERRORS+=1
) else (
    echo [OK] Windows Client built
)

echo.
echo [BUILD 2/3] Windows Client (Dev/Mapper)...
"%GODOT_PATH%" --headless --export-debug "Windows Client (Dev)" "%EXPORT_PATH_DEV%"
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Windows Dev Client build failed!
    set /a ERRORS+=1
) else (
    echo [OK] Windows Dev Client built
)

echo.
echo [BUILD 3/3] Linux Server...
"%GODOT_PATH%" --headless --export-release "Linux Server (Headless)" "%EXPORT_PATH_LINUX%"
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Linux Server build failed!
    set /a ERRORS+=1
) else (
    echo [OK] Linux Server built
)

:: Check for build errors
if %ERRORS% GTR 0 (
    echo.
    echo [ERROR] %ERRORS% build(s) failed!
    choice /C YN /M "Continue with staging anyway?"
    if !ERRORLEVEL! EQU 2 goto :pipeline_failed
)

echo.

:: ========================================
::   STAGING PHASE
:: ========================================
echo ==========================================
echo   STAGING PHASE
echo ==========================================

:: Backup existing PCK files before overwriting
echo.
echo [BACKUP] Backing up current versions...
set "BACKUP_NAME=%date:~-4,4%%date:~-10,2%%date:~-7,2%_%time:~0,2%%time:~3,2%"
set "BACKUP_NAME=%BACKUP_NAME: =0%"

if exist "%DEPLOY_DIR%\channels\production\game.pck" (
    copy /Y "%DEPLOY_DIR%\channels\production\game.pck" "%BACKUP_DIR%\game_prod_%BACKUP_NAME%.pck" >nul
    echo [OK] Production PCK backed up
)
if exist "%DEPLOY_DIR%\channels\dev\game.pck" (
    copy /Y "%DEPLOY_DIR%\channels\dev\game.pck" "%BACKUP_DIR%\game_dev_%BACKUP_NAME%.pck" >nul
    echo [OK] Dev PCK backed up
)

echo.
echo [STAGE] Copying build files...

:: Copy Production PCK
if exist "builds\WindowsClient\OdysseysRevival.pck" (
    copy /Y "builds\WindowsClient\OdysseysRevival.pck" "%DEPLOY_DIR%\channels\production\game.pck" >nul
    echo [OK] Production PCK staged
) else (
    echo [ERROR] Production PCK not found!
    set /a ERRORS+=1
)

:: Copy Dev PCK
if exist "builds\WindowsDev\OdysseysRevivalDev.pck" (
    copy /Y "builds\WindowsDev\OdysseysRevivalDev.pck" "%DEPLOY_DIR%\channels\dev\game.pck" >nul
    echo [OK] Dev PCK staged
) else (
    echo [WARN] Dev PCK not found, using Production PCK
    copy /Y "builds\WindowsClient\OdysseysRevival.pck" "%DEPLOY_DIR%\channels\dev\game.pck" >nul
)

:: Copy Server PCK
if exist "builds\LinuxServer\odysseys_revival_server.pck" (
    copy /Y "builds\LinuxServer\odysseys_revival_server.pck" "%DEPLOY_DIR%\channels\production\server.pck" >nul
    echo [OK] Server PCK staged
)

echo.
echo [STAGE] Generating version files...

:: Production Version JSON
(
echo {
echo   "version": "%VERSION%",
echo   "force_update": false,
echo   "build_date": "%date% %time%",
echo   "changelog": [
echo     "Build %VERSION% - %date%"
echo   ]
echo }
) > "%DEPLOY_DIR%\channels\production\version.json"
echo [OK] Production version.json created

:: Dev Version JSON
(
echo {
echo   "version": "%VERSION%-dev",
echo   "force_update": true,
echo   "build_date": "%date% %time%",
echo   "changelog": [
echo     "Dev Build %VERSION% - %date%",
echo     "Debug tools and Map Editor enabled"
echo   ]
echo }
) > "%DEPLOY_DIR%\channels\dev\version.json"
echo [OK] Dev version.json created

echo.
echo [STAGE] Creating installer packages...

:: Clean old installers
if exist "%INSTALLER_DIR%\OdysseyRevival.zip" del "%INSTALLER_DIR%\OdysseyRevival.zip"
if exist "%INSTALLER_DIR%\OdysseyDevClient.zip" del "%INSTALLER_DIR%\OdysseyDevClient.zip"

:: Zip Production Client
if exist "builds\WindowsClient\OdysseysRevival.exe" (
    powershell -Command "Compress-Archive -Path 'builds\WindowsClient\*' -DestinationPath '%INSTALLER_DIR%\OdysseyRevival.zip' -Force"
    if !ERRORLEVEL! EQU 0 (
        echo [OK] Production installer created
    ) else (
        echo [ERROR] Failed to create Production installer
        set /a ERRORS+=1
    )
)

:: Zip Dev Client
if exist "builds\WindowsDev\OdysseysRevivalDev.exe" (
    powershell -Command "Compress-Archive -Path 'builds\WindowsDev\*' -DestinationPath '%INSTALLER_DIR%\OdysseyDevClient.zip' -Force"
    if !ERRORLEVEL! EQU 0 (
        echo [OK] Dev installer created
    ) else (
        echo [ERROR] Failed to create Dev installer
        set /a ERRORS+=1
    )
)

echo.

:: ========================================
::   UPLOAD PHASE
:: ========================================
echo ==========================================
echo   UPLOAD PHASE
echo ==========================================

if "%SKIP_UPLOAD%"=="1" (
    echo.
    echo [SKIP] Upload skipped - rclone not configured
    echo        Run setup_rclone.bat to configure Cloudflare R2
    goto :pipeline_complete
)

echo.
echo [UPLOAD] Uploading to Cloudflare R2...

:: Upload channels (game updates)
echo [UPLOAD 1/2] Syncing update channels...
"%RCLONE%" sync "%DEPLOY_DIR%\channels" %R2_CHANNELS% --config "%RCLONE_CONFIG%" --progress
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Channel upload failed!
    set /a ERRORS+=1
) else (
    echo [OK] Channels uploaded
)

:: Upload installers
echo.
echo [UPLOAD 2/2] Syncing installers...
"%RCLONE%" sync "%INSTALLER_DIR%" %R2_INSTALLERS% --config "%RCLONE_CONFIG%" --progress
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Installer upload failed!
    set /a ERRORS+=1
) else (
    echo [OK] Installers uploaded
)

set "BUILD_SUCCESS=1"
goto :pipeline_complete

:: ========================================
::   PIPELINE FAILED
:: ========================================
:pipeline_failed
echo.
echo ==========================================
echo   PIPELINE FAILED
echo ==========================================
echo Please fix the errors above and try again.
pause
exit /b 1

:: ========================================
::   PIPELINE COMPLETE
:: ========================================
:pipeline_complete
echo.
echo ==========================================
if %BUILD_SUCCESS% EQU 1 (
    if %ERRORS% EQU 0 (
        echo   PIPELINE SUCCESSFUL!
    ) else (
        echo   PIPELINE COMPLETED WITH %ERRORS% WARNING(S)
    )
) else (
    echo   PIPELINE COMPLETED (Upload skipped)
)
echo ==========================================
echo.
echo   Version:     %VERSION%
echo   Build Date:  %date% %time%
echo.
echo   LOCAL FILES:
echo   - builds\WindowsClient\  (Production EXE)
echo   - builds\WindowsDev\     (Dev EXE)
echo   - builds\LinuxServer\    (Server)
echo   - deploy\channels\       (PCK files for updater)
echo   - deploy\installers\     (ZIP installers)
echo   - deploy\backups\        (Previous versions)
echo.
if "%SKIP_UPLOAD%"=="0" (
    echo   DOWNLOAD LINKS:
    echo   ----------------------------------------
    echo   Player Client:
    echo   https://pub-bfb251fbb7f04473b6eb939aba7ccdfc.r2.dev/installers/OdysseyRevival.zip
    echo.
    echo   Developer Client:
    echo   https://pub-bfb251fbb7f04473b6eb939aba7ccdfc.r2.dev/installers/OdysseyDevClient.zip
    echo   ----------------------------------------
)
echo.

:: Cleanup old backups (keep last 5)
echo [CLEANUP] Keeping last 5 backups...
for /f "skip=10 delims=" %%f in ('dir /b /o-d "%BACKUP_DIR%\*.pck" 2^>nul') do del "%BACKUP_DIR%\%%f"

echo.
timeout /t 10
exit /b 0
