# watch-wallpaper.ps1
# Runs at logon: extracts colors immediately, then re-extracts whenever the
# wallpaper changes. Launched from GlazeWM startup_commands.

$ErrorActionPreference = 'Continue'
$extract = Join-Path $PSScriptRoot 'get-wallpaper-colors.ps1'

# Prevent duplicate watchers within the same logon session
$created = $false
$mutex = New-Object System.Threading.Mutex($true, 'Local\OdysseyWallpaperWatcher', [ref]$created)
if (-not $created) { exit 0 }

function Get-WallpaperSignature {
    $reg = Get-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -ErrorAction SilentlyContinue
    $wp = ''
    if ($reg -and $reg.Wallpaper) { $wp = [string]$reg.Wallpaper }
    $tic = ''
    if ($reg -and $reg.PSObject.Properties['TranscodedImageCache'] -and $reg.TranscodedImageCache) {
        try { $tic = [Convert]::ToBase64String($reg.TranscodedImageCache) } catch {}
    }
    return "$wp|$tic"
}

# Initial extraction
& $extract
$last = Get-WallpaperSignature

while ($true) {
    Start-Sleep -Seconds 3
    try {
        $current = Get-WallpaperSignature
        if ($current -ne $last) {
            Start-Sleep -Seconds 2   # let Windows finish writing files
            & $extract
            $last = Get-WallpaperSignature
        }
    } catch {}
}
