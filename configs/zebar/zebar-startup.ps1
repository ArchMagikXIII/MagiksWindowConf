# zebar-startup.ps1
# Runs wallpaper color extraction + GPU detection, then launches Zebar.
# GlazeWM runs this as a single shell-exec so everything completes before Zebar starts.

$ErrorActionPreference = 'SilentlyContinue'

$zebarDir = "$env:USERPROFILE\.glzr\zebar\odyssey-bar"

# 1. Extract wallpaper colors
$wallpaperScript = Join-Path $zebarDir "get-wallpaper-colors.ps1"
if (Test-Path $wallpaperScript) {
    try { & $wallpaperScript } catch {}
}

# 2. Detect GPU
$gpuScript = Join-Path $zebarDir "get-gpu-info.ps1"
if (Test-Path $gpuScript) {
    try { & $gpuScript } catch {}
}

# 3. Launch Zebar
Start-Process "zebar"
