@echo off
setlocal EnableDelayedExpansion
title Odysseys Revival - Dev Client Deploy

:: ========================================
::   CONFIGURATION
:: ========================================
set "GODOT_PATH_1=C:\Godot\Godot_v4.5-stable_mono_win64.exe"
set "GODOT_PATH_2=C:\Program Files\Godot\Godot_v4.5-stable_mono_win64.exe"
set "GODOT_PATH_3=C:\Godot\Godot_v4.5-stable_win64.exe"

set "EXPORT_PATH_DEV=builds\WindowsDev\OdysseysRevivalDev.exe"
set "DEPLOY_DIR=deploy"
set "INSTALLER_DIR=deploy\installers"
set "BACKUP_DIR=deploy\backups"
set "RCLONE=tools\rclone\rclone.exe"
set "RCLONE_CONFIG=tools\rclone\rclone.conf"
set "R2_CHANNELS=odyssey_updates:odysseys-updates/channels"
set "R2_INSTALLERS=odyssey_updates:odysseys-updates/installers"

echo ==========================================
echo   DEV CLIENT DEPLOY
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
    echo [ERROR] Godot not found!
    goto :failed
)
echo [OK] Godot found: %GODOT_PATH%

if not exist "version.txt" (
    echo [ERROR] version.txt not found!
    goto :failed
)

set /p VERSION=<version.txt
echo [OK] Version: %VERSION%

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

if not exist "export_presets.cfg" (
    echo [ERROR] export_presets.cfg not found!
    goto :failed
)
echo [OK] Export presets found

:: ========================================
::   VERSION SYNC CHECK
:: ========================================
echo.
echo [SYNC CHECK] Verifying local version files...

:: Get version from project.godot
for /f "tokens=2 delims==" %%a in ('findstr /C:"config/version=" project.godot') do set "VERSION_GODOT=%%a"
set "VERSION_GODOT=!VERSION_GODOT:"=!"

echo   version.txt:    %VERSION%
echo   project.godot:  !VERSION_GODOT!

if not "%VERSION%"=="!VERSION_GODOT!" (
    echo.
    echo [WARN] Version mismatch! Syncing project.godot to version.txt...
    powershell -Command "(Get-Content 'project.godot') -replace 'config/version=\"[^\"]*\"', 'config/version=\"%VERSION%\"' | Set-Content 'project.godot'"
    echo [OK] Synced project.godot to %VERSION%
) else (
    echo [OK] Local files in sync
)
echo.

:: ========================================
::   VERSION MANAGEMENT
:: ========================================
echo [VERSION] Current local version: %VERSION%
echo.
choice /C YN /M "Increment version before deploy?"
if !ERRORLEVEL! EQU 1 (
    for /f "tokens=1,2,3 delims=." %%a in ("%VERSION%") do (
        set "V_MAJOR=%%a"
        set "V_MINOR=%%b"
        set "V_PATCH=%%c"
    )
    set /a V_PATCH+=1
    set "VERSION=!V_MAJOR!.!V_MINOR!.!V_PATCH!"
    echo !VERSION!> version.txt
    echo [VERSION] Incremented to: !VERSION!
) else (
    echo [VERSION] Keeping version: %VERSION%
)
echo.

:: Confirm deploy
echo ==========================================
echo   CONFIRM DEPLOYMENT
echo ==========================================
echo.
echo   Version to deploy: %VERSION%-dev
echo   Target: Development Client (Debug Tools)
echo.
echo   This will update:
echo     - version.txt ............. %VERSION%
echo     - project.godot ........... %VERSION%
echo     - source/common/version.gd  %VERSION%
echo     - R2 version.json ......... %VERSION%-dev
echo     - R2 game.pck ............. (rebuilt)
echo     - R2 OdysseyDevClient.zip . (rebuilt)
echo.
choice /C YN /M "Proceed with deployment?"
if !ERRORLEVEL! EQU 2 (
    echo [CANCELLED] Deployment aborted by user.
    pause
    exit /b 0
)
echo.

:: Sync version to project.godot
echo [SYNC] Updating project.godot...
powershell -Command "(Get-Content 'project.godot') -replace 'config/version=\"[^\"]*\"', 'config/version=\"%VERSION%\"' | Set-Content 'project.godot'"

:: Sync version to version.gd (hardwired version check)
echo [SYNC] Updating source/common/version.gd...
powershell -Command "(Get-Content 'source/common/version.gd') -replace 'const GAME_VERSION: String = \"[^\"]*\"', 'const GAME_VERSION: String = \"%VERSION%\"' | Set-Content 'source/common/version.gd'"
powershell -Command "(Get-Content 'source/common/version.gd') -replace 'const MIN_COMPATIBLE_VERSION: String = \"[^\"]*\"', 'const MIN_COMPATIBLE_VERSION: String = \"%VERSION%\"' | Set-Content 'source/common/version.gd'"

echo [OK] All version files synced to: %VERSION%
echo   - version.txt
echo   - project.godot
echo   - source/common/version.gd
echo.

:: Create directories
if not exist "builds\WindowsDev" mkdir "builds\WindowsDev"
if not exist "%DEPLOY_DIR%\channels\dev" mkdir "%DEPLOY_DIR%\channels\dev"
if not exist "%INSTALLER_DIR%" mkdir "%INSTALLER_DIR%"
if not exist "%BACKUP_DIR%" mkdir "%BACKUP_DIR%"

:: ========================================
::   BUILD
:: ========================================
echo ==========================================
echo   BUILDING DEV CLIENT (Debug Tools Enabled)
echo ==========================================
echo.

"%GODOT_PATH%" --headless --export-debug "Windows Client (Dev)" "%EXPORT_PATH_DEV%"
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Build failed!
    goto :failed
)
echo [OK] Dev Client built
echo.

:: ========================================
::   STAGING
:: ========================================
echo [STAGE] Copying files...

:: Backup existing PCK
set "BACKUP_NAME=%date:~-4,4%%date:~-10,2%%date:~-7,2%_%time:~0,2%%time:~3,2%"
set "BACKUP_NAME=%BACKUP_NAME: =0%"
if exist "%DEPLOY_DIR%\channels\dev\game.pck" (
    copy /Y "%DEPLOY_DIR%\channels\dev\game.pck" "%BACKUP_DIR%\game_dev_%BACKUP_NAME%.pck" >nul
    echo [OK] Previous PCK backed up
)

:: Copy PCK
if exist "builds\WindowsDev\OdysseysRevivalDev.pck" (
    copy /Y "builds\WindowsDev\OdysseysRevivalDev.pck" "%DEPLOY_DIR%\channels\dev\game.pck" >nul
    echo [OK] Dev PCK staged
) else (
    echo [ERROR] Dev PCK not found!
    goto :failed
)

:: Create version.json
(
echo {
echo   "version": "%VERSION%-dev",
echo   "force_update": true,
echo   "build_date": "%date% %time%",
echo   "notes": "Debug tools and Map Editor enabled"
echo }
) > "%DEPLOY_DIR%\channels\dev\version.json"
echo [OK] version.json created

:: Create installer ZIP
echo [STAGE] Creating installer...
if exist "%INSTALLER_DIR%\OdysseyDevClient.zip" del "%INSTALLER_DIR%\OdysseyDevClient.zip"
powershell -Command "Compress-Archive -Path 'builds\WindowsDev\*' -DestinationPath '%INSTALLER_DIR%\OdysseyDevClient.zip' -Force"
echo [OK] Installer created
echo.

:: ========================================
::   UPLOAD
:: ========================================
if "%SKIP_UPLOAD%"=="1" (
    echo [SKIP] Upload skipped - rclone not configured
    goto :done
)

echo ==========================================
echo   UPLOADING TO R2
echo ==========================================
echo.

:: Upload PCK and version.json
echo [UPLOAD] Dev channel...
"%RCLONE%" --config "%RCLONE_CONFIG%" copy "%DEPLOY_DIR%\channels\dev" "%R2_CHANNELS%/dev" --progress
echo [OK] Dev channel uploaded

:: Upload installer
echo [UPLOAD] Installer...
"%RCLONE%" --config "%RCLONE_CONFIG%" copy "%INSTALLER_DIR%\OdysseyDevClient.zip" "%R2_INSTALLERS%" --progress
echo [OK] Installer uploaded
echo.

:done
echo ==========================================
echo   DEV CLIENT DEPLOY COMPLETE
echo ==========================================
echo Version: %VERSION%-dev
echo.
echo Download: https://pub-bfb251fbb7f04473b6eb939aba7ccdfc.r2.dev/installers/OdysseyDevClient.zip
echo.
pause
exit /b 0

:failed
echo.
echo ==========================================
echo   DEPLOY FAILED
echo ==========================================
pause
exit /b 1
