#Requires -RunAsAdministrator
<#
.SYNOPSIS
    MagikXIII Desktop Setup Installer
.DESCRIPTION
    Installs GlazeWM, Zebar, Alacritty, oh-my-posh, fastfetch, Neovim,
    optional NVIDIA App / AMD Adrenalin, and all configuration files
    for a complete tiling WM desktop.
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
    'zoxide',
    'fastfetch',
    'alacritty',
    'brave',
    'glazewm',
    'zebar',
    'neovim'
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

# ─────────────────────────── glaze-autotiler ──────────────────────
Write-Step "Installing glaze-autotiler (dwindle tiling)..."
$gaDir = "$env:USERPROFILE\.glzr\glaze-autotiler"
$gaExe = "$gaDir\glaze-autotiler.exe"
New-Item -ItemType Directory -Path $gaDir -Force | Out-Null
if (Test-Path $gaExe) {
    Write-Ok "glaze-autotiler already installed"
} else {
    try {
        Invoke-WebRequest -UseBasicParsing 'https://github.com/orbi-tal/glaze-autotiler/releases/download/v1.0.4/glaze-autotiler-1.0.4.exe' -OutFile $gaExe -ErrorAction Stop
        Write-Ok "glaze-autotiler installed (v1.0.4, dwindle default)"
    } catch {
        Remove-Item $gaExe -Force -ErrorAction SilentlyContinue
        Write-Warn "Could not download glaze-autotiler - Dwindle layout will not be active: $_"
    }
}

# ─────────────────────────── GPU Software ─────────────────────────
Write-Step "GPU software (optional)..."
Write-Host "   1) NVIDIA App"
Write-Host "   2) AMD Adrenalin"
Write-Host "   3) Both"
Write-Host "   4) Skip"
$gpuPkgs = @()
switch (Read-Host "   Which GPU software do you want? (1-4, default 4)") {
    '1' { $gpuPkgs = @('nvidia-app') }
    '2' { $gpuPkgs = @('amd-software-adrenalin-edition') }
    '3' { $gpuPkgs = @('nvidia-app', 'amd-software-adrenalin-edition') }
    default { $gpuPkgs = @() }
}

$amdDriversUrl = 'https://www.amd.com/en/support/download/drivers.html'
$uaHeaders = @{ 'User-Agent' = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)' }

foreach ($pkg in $gpuPkgs) {
    if (choco list --local-only $pkg 2>$null | Select-String $pkg) {
        Write-Ok "$pkg already installed"
        continue
    }
    Write-Host "   Installing $pkg (this can take a while)..."
    choco install $pkg -y --no-progress
    if ($LASTEXITCODE -eq 0) {
        Write-Ok "$pkg installed"
        continue
    }

    # Chocolatey packages for GPU software embed vendor CDN links that AMD/
    # NVIDIA rotate frequently - fall back to fetching straight from the vendor.
    if ($pkg -eq 'amd-software-adrenalin-edition') {
        Write-Warn "Chocolatey download failed - falling back to AMD's web installer..."
        try {
            $page = Invoke-WebRequest -UseBasicParsing $amdDriversUrl -Headers $uaHeaders -ErrorAction Stop
            $setupUrl = ([regex]::Matches($page.Content, 'https://drivers\.amd\.com/drivers/[^\s"'']+?\.exe') |
                Select-Object -ExpandProperty Value -First 1)
            if (-not $setupUrl) { throw 'no Adrenalin installer link found on AMD site' }
            Write-Host "   Downloading $(Split-Path $setupUrl -Leaf)..."
            $setup = "$env:TEMP\amd-adrenalin-setup.exe"
            Invoke-WebRequest -UseBasicParsing $setupUrl -OutFile $setup `
                -Headers ($uaHeaders + @{ Referer = $amdDriversUrl }) -ErrorAction Stop
            Start-Process -FilePath $setup -ArgumentList '-install' -Wait
            Write-Ok "AMD Adrenalin installed via AMD web installer"
        } catch {
            Write-Warn "AMD web installer failed: $_"
            Write-Warn "Download manually from: $amdDriversUrl"
            Start-Process $amdDriversUrl
        }
    } elseif ($pkg -eq 'nvidia-app') {
        Write-Warn "NVIDIA App failed to install - grab it manually from:"
        Write-Warn "  https://www.nvidia.com/en-us/software/nvidia-app/"
        Start-Process 'https://www.nvidia.com/en-us/software/nvidia-app/'
    } else {
        Write-Warn "$pkg failed to install (non-fatal)"
    }
}

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
$glazewmConfig = Get-Content "$glazewmHome\config.yaml" -Raw -Encoding UTF8
$escapedProfile = [regex]::Escape("C:\Users\Administrator")
$glazewmConfig = $glazewmConfig -replace $escapedProfile, $env:USERPROFILE
# Write without BOM (Out-File UTF8 adds BOM which GlazeWM can't parse)
[System.IO.File]::WriteAllText("$glazewmHome\config.yaml", $glazewmConfig)
Write-Ok "GlazeWM config deployed"

# Zebar
$zebarHome = "$env:USERPROFILE\.glzr\zebar"
$zebarPack = "$zebarHome\odyssey-bar"
New-Item -ItemType Directory -Path $zebarPack -Force | Out-Null
Copy-Item "$SetupDir\configs\zebar\settings.json" "$zebarHome\settings.json" -Force
Copy-Item "$SetupDir\configs\zebar\odyssey-bar\*" "$zebarPack\" -Force

# Theme files (optional - only if present in the repo)
$themesDir = "$zebarHome\themes"
New-Item -ItemType Directory -Path $themesDir -Force | Out-Null
if (Test-Path "$SetupDir\configs\zebar\themes") {
    Copy-Item "$SetupDir\configs\zebar\themes\*" "$themesDir\" -Force
    Copy-Item "$SetupDir\configs\zebar\cycle-theme.ps1" "$zebarHome\cycle-theme.ps1" -Force
}
Copy-Item "$SetupDir\configs\zebar\zebar-startup.ps1" "$zebarHome\zebar-startup.ps1" -Force
Write-Ok "Zebar config + Magik Bar deployed"

# Generate gpu-info.js now so it exists on first boot
$gpuScript = "$zebarPack\get-gpu-info.ps1"
if (Test-Path $gpuScript) {
    try {
        Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$gpuScript`"" -Wait -NoNewWindow
        Write-Ok "GPU info detected"
    } catch {
        Write-Warn "Could not detect GPU (non-fatal)"
    }
}

# Alacritty
$alacrittyDir = "$env:APPDATA\alacritty"
New-Item -ItemType Directory -Path $alacrittyDir -Force | Out-Null
Copy-Item "$SetupDir\configs\alacritty\alacritty.toml" "$alacrittyDir\alacritty.toml" -Force
Write-Ok "Alacritty config deployed"

# NOTE: Elevated launch for Alacritty/GlazeWM is handled by setup-admin-tasks.ps1
# (a scheduled task needs stored credentials to truly elevate - see below).

# Fastfetch
$ffDir = "$env:USERPROFILE\.config\fastfetch"
New-Item -ItemType Directory -Path $ffDir -Force | Out-Null
Copy-Item "$SetupDir\configs\fastfetch\config.jsonc" "$ffDir\config.jsonc" -Force
# Rewrite hardcoded paths to current user (config uses forward slashes)
$ffConfig = Get-Content "$ffDir\config.jsonc" -Raw -Encoding UTF8
$escapedFwd = [regex]::Escape("C:/Users/Administrator")
$escapedBwd = [regex]::Escape("C:\Users\Administrator")
$ffConfig = $ffConfig -replace $escapedFwd, ($env:USERPROFILE -replace '\\', '/')
$ffConfig = $ffConfig -replace $escapedBwd, $env:USERPROFILE
[System.IO.File]::WriteAllText("$ffDir\config.jsonc", $ffConfig)
Write-Ok "Fastfetch config deployed"

# ASCII art (incl. MagikOS.txt used by the fastfetch logo)
$asciiDir = "$env:USERPROFILE\Pictures\ASCII"
New-Item -ItemType Directory -Path $asciiDir -Force | Out-Null
Copy-Item "$SetupDir\assets\ASCII\*" "$asciiDir\" -Force
Write-Ok "ASCII art deployed"

# ─────────────────────────── PowerShell Modules ───────────────────
Write-Step "Installing PowerShell modules..."
$modules = @('Terminal-Icons', 'PSReadLine', 'PSFzf')
# Bootstrap NuGet provider + trust PSGallery so Install-Module works
# non-interactively (avoids the interactive provider/prompt hang).
try {
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope CurrentUser -ErrorAction Stop | Out-Null
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction Stop
} catch {
    Write-Warn "Could not bootstrap NuGet provider: $_"
}
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

# Purge stale Terminal-Icons preferences (old versions can leave an unreadable
# prefs.xml behind, causing a parse warning in every new shell)
$prefsFile = "$env:APPDATA\powershell\Community\Terminal-Icons\prefs.xml"
if (Test-Path $prefsFile) {
    try { Import-Clixml $prefsFile | Out-Null } catch { Remove-Item $prefsFile -Force }
}

# oh-my-posh theme
# Deploy to a user-writable location that the profile references. The old
# $env:LOCALAPPDATA\Programs\oh-my-posh\themes target only works for the
# Chocolatey install; the Windows Store install puts themes under
# C:\Program Files\WindowsApps (restricted + wiped on update).
$ompTheme = "$SetupDir\configs\oh-my-posh\night-owl.omp.json"
$ompDest = "$env:USERPROFILE\.config\oh-my-posh\themes\night-owl.omp.json"
New-Item -ItemType Directory -Path (Split-Path $ompDest) -Force | Out-Null
Copy-Item $ompTheme $ompDest -Force
Write-Ok "oh-my-posh theme deployed"

# PowerShell profile - detect which host(s) are installed so the profile
# lands in the right place for each one.
#   - Windows PowerShell 5.1 : Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1
#   - PowerShell 7 (pwsh)    : Documents\PowerShell\Microsoft.PowerShell_profile.ps1
$profileSource = "$SetupDir\configs\powershell\Microsoft.PowerShell_profile.ps1"
$psProfilesDeployed = @()

# Windows PowerShell 5.1 (powershell.exe - present on every Windows box)
$ps51Profile = "$env:USERPROFILE\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
$ps51Dir = Split-Path $ps51Profile
New-Item -ItemType Directory -Path $ps51Dir -Force | Out-Null
Copy-Item $profileSource $ps51Profile -Force
$psProfilesDeployed += "Windows PowerShell 5.1"

# PowerShell 7 (pwsh) - only if actually installed
$pwshCmd = Get-Command pwsh -ErrorAction SilentlyContinue
if ($pwshCmd) {
    $ps7Profile = "$env:USERPROFILE\Documents\PowerShell\Microsoft.PowerShell_profile.ps1"
    $ps7Dir = Split-Path $ps7Profile
    New-Item -ItemType Directory -Path $ps7Dir -Force | Out-Null
    Copy-Item $profileSource $ps7Profile -Force
    $psProfilesDeployed += "PowerShell 7 (pwsh)"
} else {
    Write-Warn "PowerShell 7 (pwsh) not detected - profile only patched for Windows PowerShell 5.1"
}

Write-Ok "PowerShell profile deployed to: $($psProfilesDeployed -join ', ')"

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
Write-Step "Setting up GlazeWM auto-start (elevated)..."
# GlazeWM must run elevated, or Windows (UIPI) won't let it tile/control
# the elevated apps launched from it (they'd float, and fullscreen would
# get "stuck"). A scheduled task needs STORED CREDENTIALS to truly elevate
# (an Interactive+Highest task silently runs unelevated). Since the
# installer can't ask for a password mid-run, elevation is set up via
# setup-admin-tasks.ps1, which prompts for credentials securely once.
$startupDir = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
$glazewmExe = "C:\Program Files\glzr.io\GlazeWM\glazewm.exe"
$glazewmTask = 'GlazeWM'

# Remove any stale raw glazewm.exe placed in Startup (would run unelevated)
Remove-Item "$startupDir\glazewm.exe" -Force -ErrorAction SilentlyContinue

if (Test-Path "$SetupDir\setup-admin-tasks.ps1") {
    Copy-Item "$SetupDir\setup-admin-tasks.ps1" "$env:USERPROFILE\setup-admin-tasks.ps1" -Force
}

$existing = Get-ScheduledTask -TaskName $glazewmTask -ErrorAction SilentlyContinue
if ($existing -and $existing.Principal.LogonType -eq 'Password' -and $existing.Principal.RunLevel -eq 'Highest') {
    Write-Ok "GlazeWM elevated task already configured"
} else {
    Write-Warn "Elevated GlazeWM task not yet configured - run setup-admin-tasks.ps1 once to enable it (no UAC after that)."
}

# ─────────────────────────── Done ─────────────────────────────────
Write-Host "`n" -NoNewline
Write-Host "============================================" -ForegroundColor Magenta
Write-Host "  MagikXIII Desktop Setup - Complete!" -ForegroundColor Magenta
Write-Host "============================================" -ForegroundColor Magenta
Write-Host ""
Write-Host "Installed:" -ForegroundColor White
Write-Host "  - GlazeWM (tiling window manager)"
Write-Host "  - glaze-autotiler (Dwindle tiling layout)"
Write-Host "  - Zebar (status bar with wallpaper colors)"
Write-Host "  - Alacritty (terminal)"
Write-Host "  - oh-my-posh (prompt theme: night-owl)"
Write-Host "  - fastfetch (system info)"
Write-Host "  - Neovim (editor)"
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
