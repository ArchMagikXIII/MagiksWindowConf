# get-wallpaper-colors.ps1
# Extracts dominant colors from the current wallpaper and writes CSS variables.
# Run on startup or when wallpaper changes.

$ErrorActionPreference = 'Stop'
$cssPath = Join-Path "$env:USERPROFILE\.glzr\zebar\odyssey-bar" "wallpaper-colors.css"

# Get wallpaper path from registry (multiple sources)
$wallpaperPath = $null

# Method 1: Standard desktop wallpaper
$reg = Get-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name Wallpaper -ErrorAction SilentlyContinue
if ($reg.Wallpaper -and $reg.Wallpaper -ne '' -and (Test-Path $reg.Wallpaper)) {
    $wallpaperPath = $reg.Wallpaper
}

# Method 2: Transcoded image cache (covers Spotlight, slideshow, Windows themes)
if (-not $wallpaperPath) {
    $transcoded = Get-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name TranscodedImageCache -ErrorAction SilentlyContinue
    if ($transcoded.TranscodedImageCache) {
        $bytes = $transcoded.TranscodedImageCache
        # Image path starts at byte offset 16, null-terminated Unicode string
        $sb = New-Object System.Text.StringBuilder
        for ($i = 16; $i -lt $bytes.Length - 2; $i += 2) {
            $char = [char]$bytes[$i]
            if ($char -eq [char]0) { break }
            [void]$sb.Append($char)
        }
        $path = $sb.ToString()
        if ($path -and (Test-Path $path)) {
            $wallpaperPath = $path
        }
    }
}

# Method 3: Use a default wallpaper from our assets
if (-not $wallpaperPath) {
    $defaultWp = "$env:USERPROFILE\Pictures\Wallpapers\*"
    $found = Get-ChildItem $defaultWp -Include *.jpg,*.png,*.bmp -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) {
        $wallpaperPath = $found.FullName
    }
}

if (-not $wallpaperPath -or -not (Test-Path $wallpaperPath)) {
    Write-Host "No wallpaper found, using defaults."
    # Write fallback CSS
    $fallback = @"
:root {
    --wallpaper-primary: rgb(40, 40, 60);
    --wallpaper-light: rgb(70, 70, 100);
    --wallpaper-dark: rgb(20, 20, 30);
    --wallpaper-text: #ffffff;
}
"@
    [System.IO.File]::WriteAllText($cssPath, $fallback)
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

    $avgR = [math]::Round(($pixels | ForEach-Object { $_.R } | Measure-Object -Average).Average)
    $avgG = [math]::Round(($pixels | ForEach-Object { $_.G } | Measure-Object -Average).Average)
    $avgB = [math]::Round(($pixels | ForEach-Object { $_.B } | Measure-Object -Average).Average)

    $lightR = [math]::Min(255, [math]::Round($avgR * 1.3 + 20))
    $lightG = [math]::Min(255, [math]::Round($avgG * 1.3 + 20))
    $lightB = [math]::Min(255, [math]::Round($avgB * 1.3 + 20))

    $darkR = [math]::Max(0, [math]::Round($avgR * 0.5))
    $darkG = [math]::Max(0, [math]::Round($avgG * 0.5))
    $darkB = [math]::Max(0, [math]::Round($avgB * 0.5))

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

    [System.IO.File]::WriteAllText($cssPath, $css)
    Write-Host "Wallpaper colors written: rgb($avgR, $avgG, $avgB) from $wallpaperPath"

} catch {
    Write-Host "Error processing wallpaper: $_"
}
