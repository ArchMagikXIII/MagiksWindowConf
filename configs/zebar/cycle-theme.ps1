# cycle-theme.ps1
# Cycles through Zebar themes and triggers a redraw.
# Usage: powershell -WindowStyle Hidden -File cycle-theme.ps1

$ErrorActionPreference = 'SilentlyContinue'

$themesDir = "$env:USERPROFILE\.glzr\zebar\themes"
$activeFile = "$themesDir\.active"
$targetFile = "$env:USERPROFILE\.glzr\zebar\odyssey-bar\wallpaper-colors.css"

# Get all CSS theme files
$themes = Get-ChildItem "$themesDir\*.css" | Sort-Object Name
if ($themes.Count -eq 0) {
    Write-Host "No themes found in $themesDir"
    exit
}

# Read current active index
$currentName = ""
if (Test-Path $activeFile) {
    $currentName = Get-Content $activeFile -Raw
}

# Find next theme
$currentIndex = -1
for ($i = 0; $i -lt $themes.Count; $i++) {
    if ($themes[$i].Name -eq $currentName) {
        $currentIndex = $i
        break
    }
}
$nextIndex = ($currentIndex + 1) % $themes.Count
$nextTheme = $themes[$nextIndex]

# Copy theme to active location
Copy-Item $nextTheme.FullName $targetFile -Force

# Save current selection
$nextTheme.Name | Out-File -FilePath $activeFile -Encoding UTF8 -NoNewline

Write-Host "Switched to theme: $($nextTheme.BaseName)"
