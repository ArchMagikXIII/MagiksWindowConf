# get-wallpaper-colors.ps1
# Extracts dominant colors from the current wallpaper and writes CSS variables.
# Run on startup or when wallpaper changes.

$ErrorActionPreference = 'SilentlyContinue'

# Get wallpaper path from registry
$wallpaperPath = (Get-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name Wallpaper).Wallpaper

if (-not $wallpaperPath -or -not (Test-Path $wallpaperPath)) {
    Write-Host "No wallpaper found, using defaults."
    exit
}

Add-Type -AssemblyName System.Drawing

try {
    $img = [System.Drawing.Image]::FromFile($wallpaperPath)
    $thumb = New-Object System.Drawing.Bitmap($img, 80, 80)
    $img.Dispose()

    # Sample pixels in a grid
    $pixels = @()
    for ($x = 5; $x -lt 80; $x += 8) {
        for ($y = 5; $y -lt 80; $y += 8) {
            $c = $thumb.GetPixel($x, $y)
            # Skip near-white and near-black pixels
            $lum = 0.299 * $c.R + 0.587 * $c.G + 0.114 * $c.B
            if ($lum -gt 20 -and $lum -lt 235) {
                $pixels += $c
            }
        }
    }
    $thumb.Dispose()

    if ($pixels.Count -eq 0) {
        Write-Host "No valid pixels sampled."
        exit
    }

    # Average color
    $avgR = [math]::Round(($pixels | ForEach-Object { $_.R } | Measure-Object -Average).Average)
    $avgG = [math]::Round(($pixels | ForEach-Object { $_.G } | Measure-Object -Average).Average)
    $avgB = [math]::Round(($pixels | ForEach-Object { $_.B } | Measure-Object -Average).Average)

    # Light variant (brighten)
    $lightR = [math]::Min(255, [math]::Round($avgR * 1.3 + 20))
    $lightG = [math]::Min(255, [math]::Round($avgG * 1.3 + 20))
    $lightB = [math]::Min(255, [math]::Round($avgB * 1.3 + 20))

    # Dark variant (darken)
    $darkR = [math]::Max(0, [math]::Round($avgR * 0.5))
    $darkG = [math]::Max(0, [math]::Round($avgG * 0.5))
    $darkB = [math]::Max(0, [math]::Round($avgB * 0.5))

    # Determine text color based on luminance
    $lum = 0.299 * $avgR + 0.587 * $avgG + 0.114 * $avgB
    if ($lum -gt 140) {
        $textColor = "#000000"
    } else {
        $textColor = "#ffffff"
    }

    $css = @"
:root {
    --wallpaper-primary: rgb($avgR, $avgG, $avgB);
    --wallpaper-light: rgb($lightR, $lightG, $lightB);
    --wallpaper-dark: rgb($darkR, $darkG, $darkB);
    --wallpaper-text: $textColor;
}
"@

    $cssPath = Join-Path "$env:USERPROFILE\.glzr\zebar\odyssey-bar" "wallpaper-colors.css"
    [System.IO.File]::WriteAllText($cssPath, $css)
    Write-Host "Wallpaper colors written to $cssPath"

} catch {
    Write-Host "Error processing wallpaper: $_"
}
