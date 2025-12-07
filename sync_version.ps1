# sync_version.ps1
# Updates all version files to match version.txt (Single Source of Truth)

$ErrorActionPreference = "Stop"

$versionFile = "version.txt"
$versionGdFile = "source/common/version.gd"
$projectGodotFile = "project.godot"

# Read version from version.txt
if (-not (Test-Path $versionFile)) {
    Write-Error "version.txt not found!"
    exit 1
}
$version = (Get-Content $versionFile -Raw).Trim()
Write-Host "[INFO] Source of truth (version.txt): $version"

# Update version.gd
if (Test-Path $versionGdFile) {
    $content = Get-Content $versionGdFile -Raw
    $content = $content -replace 'const GAME_VERSION: String = ".*"', "const GAME_VERSION: String = `"$version`""
    $content = $content -replace 'const MIN_COMPATIBLE_VERSION: String = ".*"', "const MIN_COMPATIBLE_VERSION: String = `"$version`""
    Set-Content $versionGdFile $content -NoNewline
    Write-Host "[OK] Updated: $versionGdFile"
}
else {
    Write-Warning "version.gd not found at $versionGdFile"
}

# Update project.godot
if (Test-Path $projectGodotFile) {
    $content = Get-Content $projectGodotFile -Raw
    $content = $content -replace 'config/version=".*"', "config/version=`"$version`""
    Set-Content $projectGodotFile $content -NoNewline
    Write-Host "[OK] Updated: $projectGodotFile"
}
else {
    Write-Warning "project.godot not found"
}

Write-Host ""
Write-Host "[DONE] All version files synced to: $version"
