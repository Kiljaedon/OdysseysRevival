@echo off
echo ==========================================
echo SETUP GAME SERVER ACCESS (SFTP)
echo ==========================================
echo.
echo We will configure Rclone to sync files to your Linux Game Server.
echo.
echo Server IP: 178.156.202.89
echo User: gameserver
echo.
echo Please enter the SSH Password for 'gameserver':
set /p SFTP_PASS="Password: "

:: Rclone obfuscates passwords, so we use the config create command
tools\rclone\rclone.exe config create odyssey_server sftp host 178.156.202.89 user gameserver port 22 pass %SFTP_PASS% --config "tools\rclone\rclone.conf"

if errorlevel 0 (
    echo.
    echo Configuration saved to tools\rclone\rclone.conf!
    echo.
    echo Testing connection...
    tools\rclone\rclone.exe lsd odyssey_server: --config "tools\rclone\rclone.conf"
    if errorlevel 0 (
        echo Connection SUCCESSFUL!
    ) else (
        echo Connection FAILED. Password might be wrong.
    )
) else (
    echo Failed to save configuration.
)
pause
