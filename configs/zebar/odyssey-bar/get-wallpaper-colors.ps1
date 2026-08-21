# get-wallpaper-colors.ps1
# Extracts dominant colors from the current wallpaper and outputs JSON.
# Invoked by the Zebar widget via glazewm shell-exec.

$ErrorActionPreference = 'Stop'

function Get-WallpaperPath {
    $reg = Get-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name Wallpaper -ErrorAction SilentlyContinue
    if ($reg.Wallpaper -and $reg.Wallpaper -ne '' -and (Test-Path -LiteralPath $reg.Wallpaper)) {
        return $reg.Wallpaper
    }

    $transcoded = Get-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name TranscodedImageCache -ErrorAction SilentlyContinue
    if ($transcoded.TranscodedImageCache) {
        $bytes = $transcoded.TranscodedImageCache
        $sb = New-Object System.Text.StringBuilder
        for ($i = 16; $i -lt $bytes.Length - 2; $i += 2) {
            $char = [char]$bytes[$i]
            if ($char -eq [char]0) { break }
            [void]$sb.Append($char)
        }
        $path = $sb.ToString()
        if ($path -and (Test-Path -LiteralPath $path)) {
            return $path
        }
    }

    $defaultWp = Join-Path $env:USERPROFILE 'Pictures\Wallpapers'
    if (Test-Path -LiteralPath $defaultWp) {
        $found = Get-ChildItem -LiteralPath $defaultWp -Include *.jpg,*.png,*.bmp -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found) { return $found.FullName }
    }

    return $null
}

function Get-WallpaperColors {
    param([string]$WallpaperPath)

    Add-Type -AssemblyName System.Drawing
    $img = [System.Drawing.Image]::FromFile($WallpaperPath)
    try {
        $thumb = New-Object System.Drawing.Bitmap($img, 80, 80)
        try {
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

            if ($pixels.Count -eq 0) { return $null }

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
            $textColor = if ($lum -gt 140) { '#000000' } else { '#ffffff' }

            return [pscustomobject]@{
                primary = "rgb($avgR, $avgG, $avgB)"
                light   = "rgb($lightR, $lightG, $lightB)"
                dark    = "rgb($darkR, $darkG, $darkB)"
                text    = $textColor
            }
        } finally {
            $thumb.Dispose()
        }
    } finally {
        $img.Dispose()
    }
}

$path = Get-WallpaperPath
if (-not $path) {
    Write-Output '{"path":"","primary":"rgb(40, 40, 60)","light":"rgb(70, 70, 100)","dark":"rgb(20, 20, 30)","text":"#ffffff"}'
    exit 0
}

$colors = Get-WallpaperColors -WallpaperPath $path
if (-not $colors) {
    Write-Output '{"path":"","primary":"rgb(40, 40, 60)","light":"rgb(70, 70, 100)","dark":"rgb(20, 20, 30)","text":"#ffffff"}'
    exit 0
}

$escapedPath = ($path -replace '\\', '\\').Replace('"', '\"')
$json = @"
{"path":"$escapedPath","primary":"$($colors.primary)","light":"$($colors.light)","dark":"$($colors.dark)","text":"$($colors.text)"}
"@
Write-Output $json
