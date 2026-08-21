#Requires -RunAsAdministrator
<#
.SYNOPSIS
    MagikXIII Desktop Setup Installer
.DESCRIPTION
    Installs GlazeWM, Zebar, Alacritty, oh-my-posh, fastfetch,
    and all configuration files for a complete tiling WM desktop.
.NOTES
    Run as Administrator: Right-click -> Run with PowerShell
#>

$ErrorActionPreference = 'Stop'
$SetupDir = $PSScriptRoot
$ProgressPreference = 'SilentlyContinue'

function Write-Step { param([string]$Msg) Write-Host "`n>> $Msg" -ForegroundColor Cyan }
function Write-Ok   { param([string]$Msg) Write-Host "   [OK] $Msg" -ForegroundColor Green }
function Write-Warn { param([string]$Msg) Write-Host "   [!] $Msg" -ForegroundColor Yellow }

# ─────────────────────────── Chocolatey ───────────────────────────
Write-Step "Checking for Chocolatey..."
if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
    Write-Host "   Installing Chocolatey..."
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    $env:PATH = [System.Environment]::GetEnvironmentVariable('PATH', 'Machine') + ';' + [System.Environment]::GetEnvironmentVariable('PATH', 'User')
    Write-Ok "Chocolatey installed"
} else {
    Write-Ok "Chocolatey already installed"
}

# ─────────────────────────── Packages ─────────────────────────────
Write-Step "Installing packages via Chocolatey..."
$packages = @(
    'git',
    'gh',
    'oh-my-posh',
    'fastfetch',
    'alacritty',
    'brave',
    'glazewm',
    'zebar'
)
foreach ($pkg in $packages) {
    if (choco list --local-only $pkg 2>$null | Select-String $pkg) {
        Write-Ok "$pkg already installed"
    } else {
        Write-Host "   Installing $pkg..."
        choco install $pkg -y --no-progress
        Write-Ok "$pkg installed"
    }
}

# Refresh PATH
$env:PATH = [System.Environment]::GetEnvironmentVariable('PATH', 'Machine') + ';' + [System.Environment]::GetEnvironmentVariable('PATH', 'User')

# ─────────────────────────── Fonts ────────────────────────────────
Write-Step "Installing Nerd Fonts..."
$fonts = Get-ChildItem "$SetupDir\fonts\*.ttf" -ErrorAction SilentlyContinue
$fontDestUser = "$env:LOCALAPPDATA\Microsoft\Windows\Fonts"
$fontDestSystem = "C:\Windows\Fonts"
New-Item -ItemType Directory -Path $fontDestUser -Force | Out-Null

foreach ($font in $fonts) {
    $destUser = Join-Path $fontDestUser $font.Name
    $destSystem = Join-Path $fontDestSystem $font.Name
    if (-not (Test-Path $destUser) -and -not (Test-Path $destSystem)) {
        # Copy to user fonts folder
        Copy-Item $font.FullName $destUser -Force
        # Get the actual font family name from the TTF
        Add-Type -AssemblyName System.Drawing
        $fc = New-Object System.Drawing.Text.PrivateFontCollection
        $fc.AddFontFile($font.FullName)
        $fontFamily = $fc.Families[0].Name
        # Register in HKCU for user
        $regPath = "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts"
        New-ItemProperty -Path $regPath -Name "$fontFamily (TrueType)" -Value $font.Name -PropertyType String -Force | Out-Null
        # Also try system-wide install
        Copy-Item $font.FullName $destSystem -Force
        $regPathSystem = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"
        New-ItemProperty -Path $regPathSystem -Name "$fontFamily (TrueType)" -Value $font.Name -PropertyType String -Force | Out-Null
        Write-Ok "Installed $fontFamily ($($font.Name))"
    } else {
        Write-Ok "$($font.Name) already installed"
    }
}

# ─────────────────────────── Config Files ─────────────────────────
Write-Step "Deploying configuration files..."

# GlazeWM
$glazewmHome = "$env:USERPROFILE\.glzr\glazewm"
New-Item -ItemType Directory -Path $glazewmHome -Force | Out-Null
Copy-Item "$SetupDir\configs\glazewm\config.yaml" "$glazewmHome\config.yaml" -Force
# Rewrite hardcoded paths to current user
$glazewmConfig = Get-Content "$glazewmHome\config.yaml" -Raw
$escapedProfile = [regex]::Escape("C:\Users\Administrator")
$glazewmConfig = $glazewmConfig -replace $escapedProfile, $env:USERPROFILE
$glazewmConfig | Out-File -FilePath "$glazewmHome\config.yaml" -Encoding UTF8 -NoNewline
Write-Ok "GlazeWM config deployed"

# Zebar
$zebarHome = "$env:USERPROFILE\.glzr\zebar"
$zebarPack = "$zebarHome\odyssey-bar"
New-Item -ItemType Directory -Path $zebarPack -Force | Out-Null
Copy-Item "$SetupDir\configs\zebar\settings.json" "$zebarHome\settings.json" -Force
Copy-Item "$SetupDir\configs\zebar\odyssey-bar\*" "$zebarPack\" -Force

# Theme files
$themesDir = "$zebarHome\themes"
New-Item -ItemType Directory -Path $themesDir -Force | Out-Null
Copy-Item "$SetupDir\configs\zebar\themes\*" "$themesDir\" -Force
Copy-Item "$SetupDir\configs\zebar\cycle-theme.ps1" "$zebarHome\cycle-theme.ps1" -Force
Write-Ok "Zebar config + Magik Bar + themes deployed"

# Alacritty
$alacrittyDir = "$env:APPDATA\alacritty"
New-Item -ItemType Directory -Path $alacrittyDir -Force | Out-Null
Copy-Item "$SetupDir\configs\alacritty\alacritty.toml" "$alacrittyDir\alacritty.toml" -Force
Write-Ok "Alacritty config deployed"

# Fastfetch
$ffDir = "$env:USERPROFILE\.config\fastfetch"
New-Item -ItemType Directory -Path $ffDir -Force | Out-Null
Copy-Item "$SetupDir\configs\fastfetch\config.jsonc" "$ffDir\config.jsonc" -Force
Write-Ok "Fastfetch config deployed"

# ASCII art
$asciiDir = "$env:USERPROFILE\Pictures\ASCII"
New-Item -ItemType Directory -Path $asciiDir -Force | Out-Null
Copy-Item "$SetupDir\assets\ASCII\*" "$asciiDir\" -Force
Write-Ok "ASCII art deployed"

# ─────────────────────────── PowerShell Modules ───────────────────
Write-Step "Installing PowerShell modules..."
$modules = @('Terminal-Icons', 'PSReadLine', 'PSFzf')
foreach ($mod in $modules) {
    if (Get-Module -ListAvailable -Name $mod -ErrorAction SilentlyContinue) {
        Write-Ok "$mod already installed"
    } else {
        Write-Host "   Installing $mod..."
        try {
            Install-Module -Name $mod -Force -SkipPublisherCheck -Scope CurrentUser -ErrorAction Stop
            Write-Ok "$mod installed"
        } catch {
            Write-Warn "Failed to install $mod - $_"
        }
    }
}

# oh-my-posh theme
$ompTheme = "$SetupDir\configs\oh-my-posh\night-owl.omp.json"
$ompDest = "$env:LOCALAPPDATA\Programs\oh-my-posh\themes\night-owl.omp.json"
if (Test-Path (Split-Path $ompDest)) {
    Copy-Item $ompTheme $ompDest -Force
    Write-Ok "oh-my-posh theme deployed"
} else {
    New-Item -ItemType Directory -Path (Split-Path $ompDest) -Force | Out-Null
    Copy-Item $ompTheme $ompDest -Force
    Write-Ok "oh-my-posh theme deployed (new directory)"
}

# PowerShell profile
$psDir = "$env:USERPROFILE\Documents\WindowsPowerShell"
New-Item -ItemType Directory -Path $psDir -Force | Out-Null
Copy-Item "$SetupDir\configs\powershell\Microsoft.PowerShell_profile.ps1" "$psDir\Microsoft.PowerShell_profile.ps1" -Force
Write-Ok "PowerShell profile deployed"

# ─────────────────────────── Wallpapers ───────────────────────────
Write-Step "Setting up wallpapers..."
$wallpaperDir = "$env:USERPROFILE\Pictures\Wallpapers"
New-Item -ItemType Directory -Path $wallpaperDir -Force | Out-Null
Copy-Item "$SetupDir\assets\wallpapers\*" "$wallpaperDir\" -Force

# Set the first wallpaper as active
$firstWallpaper = Get-ChildItem "$wallpaperDir\*" -ErrorAction SilentlyContinue | Where-Object { $_.Extension -match '\.(jpg|png|bmp)$' } | Select-Object -First 1
if ($firstWallpaper) {
    Add-Type -TypeDefinition @"
    using System.Runtime.InteropServices;
    public class Wallpaper {
        [DllImport("user32.dll", CharSet = CharSet.Auto)]
        public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
    }
"@
    $SPI_SETDESKWALLPAPER = 0x0014
    [Wallpaper]::SystemParametersInfo($SPI_SETDESKWALLPAPER, 0, $firstWallpaper.FullName, 0x01 -bor 0x02)
    Write-Ok "Wallpaper set to: $($firstWallpaper.Name)"
} else {
    Write-Warn "No wallpapers found to set"
}

# ─────────────────────────── Wallpaper Colors ─────────────────────
Write-Step "Generating wallpaper color palette..."
$colorScript = "$zebarPack\get-wallpaper-colors.ps1"
if (Test-Path $colorScript) {
    try {
        Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$colorScript`"" -Wait -NoNewWindow
        Write-Ok "Wallpaper colors generated"
    } catch {
        Write-Warn "Could not generate wallpaper colors (non-fatal)"
    }
}

# ─────────────────────────── GlazeWM Startup ──────────────────────
Write-Step "Setting up GlazeWM auto-start..."
$startupDir = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
$glazewmExe = "C:\Program Files\glzr.io\GlazeWM\glazewm.exe"
if (Test-Path $glazewmExe) {
    $shortcutPath = "$startupDir\GlazeWM.lnk"
    if (-not (Test-Path $shortcutPath)) {
        $shell = New-Object -ComObject WScript.Shell
        $shortcut = $shell.CreateShortcut($shortcutPath)
        $shortcut.TargetPath = $glazewmExe
        $shortcut.WorkingDirectory = Split-Path $glazewmExe
        $shortcut.Save()
        Write-Ok "GlazeWM auto-start shortcut created"
    } else {
        Write-Ok "GlazeWM auto-start already configured"
    }
} else {
    Write-Warn "GlazeWM exe not found at $glazewmExe - skipping startup setup"
}

# ─────────────────────────── Done ─────────────────────────────────
Write-Host "`n" -NoNewline
Write-Host "============================================" -ForegroundColor Magenta
Write-Host "  MagikXIII Desktop Setup - Complete!" -ForegroundColor Magenta
Write-Host "============================================" -ForegroundColor Magenta
Write-Host ""
Write-Host "Installed:" -ForegroundColor White
Write-Host "  - GlazeWM (tiling window manager)"
Write-Host "  - Zebar (status bar with wallpaper colors)"
Write-Host "  - Alacritty (terminal)"
Write-Host "  - oh-my-posh (prompt theme: night-owl)"
Write-Host "  - fastfetch (system info)"
Write-Host "  - JetBrains Mono + BlexMono Nerd Fonts"
Write-Host "  - PowerShell profile (zoxide, PSFzf, icons)"
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Log out and back in (for PATH changes)"
Write-Host "  2. GlazeWM will auto-start on next login"
Write-Host "  3. Or launch it manually: glazewm"
Write-Host ""
Write-Host "Key bindings:" -ForegroundColor Yellow
Write-Host "  Alt+Enter  = Alacritty terminal"
Write-Host "  Alt+B      = Brave browser"
Write-Host "  Alt+1-9    = Switch workspace"
Write-Host "  Alt+R      = Resize mode"
Write-Host "  Alt+Shift+E = Exit GlazeWM"
Write-Host ""
