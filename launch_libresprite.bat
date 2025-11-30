@echo off
echo Launching LibreSprite Sprite Editor...

cd /d "%~dp0"

if exist "tools\libresprite\libresprite.exe" (
    echo Starting LibreSprite...
    start "" "tools\libresprite\libresprite.exe"
    echo LibreSprite launched!
) else (
    echo LibreSprite not found!
    echo Please download LibreSprite portable and extract to tools\libresprite\
    echo Download from: https://github.com/LibreSprite/LibreSprite/releases
    pause
)