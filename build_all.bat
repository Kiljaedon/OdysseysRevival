@echo off
REM Build both Windows Client and Linux Server
echo ========================================
echo Building ALL - Client + Server
echo ========================================
echo.

echo [1/2] Building Windows Client...
call build_windows_client.bat

if %errorlevel% neq 0 (
    echo ERROR: Windows client build failed!
    pause
    exit /b 1
)

echo.
echo [2/2] Building Linux Server...
call build_linux_server.bat

if %errorlevel% neq 0 (
    echo ERROR: Linux server build failed!
    pause
    exit /b 1
)

echo.
echo ========================================
echo ALL BUILDS COMPLETE!
echo ========================================
echo.
echo Windows Client: builds\WindowsClient\OdysseysRevival.exe
echo Linux Server: builds\LinuxServer\odysseys_revival_server.x86_64
echo.
echo Ready for deployment!
echo.
pause
