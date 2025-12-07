@echo off
echo ==========================================
echo SETUP AUTOMATED CLOUDFLARE UPLOAD
echo ==========================================
echo.
echo We need your Cloudflare R2 credentials to automate the upload.
echo These will be saved securely to tools\rclone\rclone.conf
echo.

set /p R2_ACCESS_KEY="Enter R2 Access Key ID: "
set /p R2_SECRET_KEY="Enter R2 Secret Access Key: "
set /p R2_ENDPOINT="Enter R2 Endpoint URL (e.g., https://<accountid>.r2.cloudflarestorage.com): "

(
    echo [odyssey_updates]
    echo type = s3
    echo provider = Cloudflare
    echo access_key_id = %R2_ACCESS_KEY%
    echo secret_access_key = %R2_SECRET_KEY%
    echo endpoint = %R2_ENDPOINT%
    echo acl = private
) > tools\rclone\rclone.conf

echo.
echo Configuration saved!
echo Testing connection...
tools\rclone\rclone.exe lsd odyssey_updates: --config "tools\rclone\rclone.conf"
if errorlevel 1 (
    echo Connection FAILED. Please check your keys and try again.
) else (
    echo Connection SUCCESSFUL!
    echo.
    echo Future deployments will now automatically upload to R2.
)
pause
