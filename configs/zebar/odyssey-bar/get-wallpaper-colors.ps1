# get-wallpaper-colors.ps1
# Extracts a dominant accent color from the current wallpaper and writes CSS variables.
# Called at logon by watch-wallpaper.ps1, and re-run whenever the wallpaper changes.

$ErrorActionPreference = 'Stop'
$cssPath = Join-Path $PSScriptRoot 'wallpaper-colors.css'

function ConvertTo-Hsv([byte]$r, [byte]$g, [byte]$b) {
    $rf = $r / 255.0; $gf = $g / 255.0; $bf = $b / 255.0
    $max = [math]::Max($rf, [math]::Max($gf, $bf))
    $min = [math]::Min($rf, [math]::Min($gf, $bf))
    $delta = $max - $min
    $h = 0.0
    if ($delta -gt 0) {
        if ($max -eq $rf) { $h = 60 * ((($gf - $bf) / $delta) % 6) }
        elseif ($max -eq $gf) { $h = 60 * ((($bf - $rf) / $delta) + 2) }
        else { $h = 60 * ((($rf - $gf) / $delta) + 4) }
    }
    if ($h -lt 0) { $h += 360 }
    $s = 0.0
    if ($max -gt 0) { $s = $delta / $max }
    return @{ H = $h; S = $s; V = $max }
}

function ConvertFrom-Hsv([double]$h, [double]$s, [double]$v) {
    $c = $v * $s
    $hp = (($h % 360) + 360) % 360 / 60
    $x = $c * (1 - [math]::Abs(($hp % 2) - 1))
    switch ([math]::Floor($hp)) {
        0 { $r1 = $c; $g1 = $x; $b1 = 0.0 }
        1 { $r1 = $x; $g1 = $c; $b1 = 0.0 }
        2 { $r1 = 0.0; $g1 = $c; $b1 = $x }
        3 { $r1 = 0.0; $g1 = $x; $b1 = $c }
        4 { $r1 = $x; $g1 = 0.0; $b1 = $c }
        default { $r1 = $c; $g1 = 0.0; $b1 = $x }
    }
    $m = $v - $c
    return @(
        [int][math]::Round(($r1 + $m) * 255),
        [int][math]::Round(($g1 + $m) * 255),
        [int][math]::Round(($b1 + $m) * 255)
    )
}

function Clamp([double]$v, [double]$lo, [double]$hi) {
    return [math]::Max($lo, [math]::Min($hi, $v))
}

# --- Resolve wallpaper path -------------------------------------------------

$wallpaperPath = $null

# Method 1: Standard desktop wallpaper registry value
$reg = Get-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -ErrorAction SilentlyContinue
if ($reg.Wallpaper -and $reg.Wallpaper -ne '' -and (Test-Path $reg.Wallpaper)) {
    $wallpaperPath = $reg.Wallpaper
}

# Method 2: Transcoded image cache (covers Spotlight, slideshow, browser "set as wallpaper")
if (-not $wallpaperPath -and $reg.TranscodedImageCache) {
    $bytes = $reg.TranscodedImageCache
    $sb = New-Object System.Text.StringBuilder
    for ($i = 16; $i -lt $bytes.Length - 2; $i += 2) {
        $char = [char]$bytes[$i]
        if ($char -eq [char]0) { break }
        [void]$sb.Append($char)
    }
    $path = $sb.ToString()
    if ($path -and ($path -like '*:*') -and (Test-Path $path)) {
        $wallpaperPath = $path
    }
}

# Method 3: Fall back to any image in the wallpapers folder
if (-not $wallpaperPath) {
    $found = Get-ChildItem "$env:USERPROFILE\Pictures\Wallpaper" -Include *.jpg,*.jpeg,*.png,*.bmp -Recurse -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($found) { $wallpaperPath = $found.FullName }
}

function Write-FallbackCss([string]$reason) {
    Write-Host "Using fallback colors: $reason"
    $fallback = @"
:root {
    --wallpaper-primary: rgb(91, 63, 158);
    --wallpaper-light: rgb(123, 95, 190);
    --wallpaper-dark: rgb(59, 31, 126);
    --wallpaper-text: #ffffff;
}
"@
    [System.IO.File]::WriteAllText($cssPath, $fallback)
}

if (-not $wallpaperPath -or -not (Test-Path $wallpaperPath)) {
    Write-FallbackCss 'no wallpaper found'
    exit 0
}

# --- Sample the image --------------------------------------------------------

Add-Type -AssemblyName System.Drawing

try {
    $img = [System.Drawing.Image]::FromFile($wallpaperPath)
    $thumb = New-Object System.Drawing.Bitmap($img, 100, 100)
    $img.Dispose()

    # Hue bins: 24 x 15-degree buckets accumulating weighted color sums
    $binCount = New-Object 'System.Collections.Generic.List[double]'
    $binR = New-Object 'System.Collections.Generic.List[double]'
    $binG = New-Object 'System.Collections.Generic.List[double]'
    $binB = New-Object 'System.Collections.Generic.List[double]'
    for ($i = 0; $i -lt 24; $i++) {
        $binCount.Add(0.0); $binR.Add(0.0); $binG.Add(0.0); $binB.Add(0.0)
    }

    $totalSamples = 0
    $sumR = 0.0; $sumG = 0.0; $sumB = 0.0
    $colorfulSamples = 0

    for ($x = 2; $x -lt 100; $x += 4) {
        for ($y = 2; $y -lt 100; $y += 4) {
            $c = $thumb.GetPixel($x, $y)
            if ($c.A -lt 200) { continue }

            $lum = 0.299 * $c.R + 0.587 * $c.G + 0.114 * $c.B
            if ($lum -le 15 -or $lum -ge 245) { continue }

            $totalSamples++
            $sumR += $c.R; $sumG += $c.G; $sumB += $c.B

            $hsv = ConvertTo-Hsv $c.R $c.G $c.B
            if ($hsv.S -ge 0.25 -and $hsv.V -ge 0.15 -and $hsv.V -le 0.95) {
                $colorfulSamples++
                $bin = [int][math]::Floor($hsv.H / 15) % 24
                $weight = $hsv.S * (1 - [math]::Abs($hsv.V - 0.5))
                $binCount[$bin] += $weight
                $binR[$bin] += $c.R * $weight
                $binG[$bin] += $c.G * $weight
                $binB[$bin] += $c.B * $weight
            }
        }
    }
    $thumb.Dispose()

    if ($totalSamples -eq 0) {
        Write-FallbackCss 'no usable pixels'
        exit 0
    }

    # --- Pick dominant accent -----------------------------------------------

    $minBinWeight = $totalSamples * 0.04   # dominant hue must be reasonably present
    $bestBin = -1
    $bestWeight = 0.0
    for ($i = 0; $i -lt 24; $i++) {
        if ($binCount[$i] -gt $bestWeight) {
            $bestWeight = $binCount[$i]
            $bestBin = $i
        }
    }

    if ($bestBin -ge 0 -and $colorfulSamples -ge 8 -and $bestWeight -ge $minBinWeight) {
        # Dominant saturated hue -> vivid, readable accent
        $dR = $binR[$bestBin] / $binCount[$bestBin]
        $dG = $binG[$bestBin] / $binCount[$bestBin]
        $dB = $binB[$bestBin] / $binCount[$bestBin]
        $hsv = ConvertTo-Hsv ([byte]$dR) ([byte]$dG) ([byte]$dB)

        $primaryS = Clamp ([math]::Max($hsv.S, 0.55)) 0.0 1.0
        $primaryV = Clamp $hsv.V 0.45 0.72

        $primary = ConvertFrom-Hsv $hsv.H $primaryS $primaryV
        $light   = ConvertFrom-Hsv $hsv.H (Clamp ($primaryS * 0.85) 0.0 1.0) (Clamp ($primaryV + 0.18) 0.0 0.90)
        $dark    = ConvertFrom-Hsv $hsv.H (Clamp ($primaryS * 0.90) 0.0 1.0) (Clamp ($primaryV * 0.55) 0.10 1.0)
    } else {
        # Low-saturation wallpaper: use overall average without forcing hue
        $avgR = [int][math]::Round($sumR / $totalSamples)
        $avgG = [int][math]::Round($sumG / $totalSamples)
        $avgB = [int][math]::Round($sumB / $totalSamples)

        $primary = @($avgR, $avgG, $avgB)
        $light = @(
            [int](Clamp ($avgR * 1.25 + 20) 0 255),
            [int](Clamp ($avgG * 1.25 + 20) 0 255),
            [int](Clamp ($avgB * 1.25 + 20) 0 255)
        )
        $dark = @(
            [int](Clamp ($avgR * 0.55) 0 255),
            [int](Clamp ($avgG * 0.55) 0 255),
            [int](Clamp ($avgB * 0.55) 0 255)
        )
    }

    $pLum = 0.299 * $primary[0] + 0.587 * $primary[1] + 0.114 * $primary[2]
    $textColor = '#000000'
    if ($pLum -le 150) { $textColor = '#ffffff' }

    $css = @"
:root {
    --wallpaper-primary: rgb($($primary[0]), $($primary[1]), $($primary[2]));
    --wallpaper-light: rgb($($light[0]), $($light[1]), $($light[2]));
    --wallpaper-dark: rgb($($dark[0]), $($dark[1]), $($dark[2]));
    --wallpaper-text: $textColor;
}
"@

    [System.IO.File]::WriteAllText($cssPath, $css)
    Write-Host "Wallpaper colors written from ${wallpaperPath}: primary rgb($($primary[0]), $($primary[1]), $($primary[2]))"

} catch {
    Write-Host "Error processing wallpaper: $_"
    exit 0
}
