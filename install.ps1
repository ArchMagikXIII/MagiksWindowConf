#Requires -RunAsAdministrator
param(
    # GPU software to install: 'none' (default), 'nvidia', 'amd', or 'both'.
    # Omit entirely on machines that already have their GPU drivers installed.
    [ValidateSet('none', 'nvidia', 'amd', 'both')]
    [string]$GpuSoftware = 'none'
)
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
    'fzf',
    'fastfetch',
    'alacritty',
    'brave',
    'glazewm',
    'zebar',
    'flow-launcher',
    'discord',
    'steam',
    'neovim'
)
foreach ($pkg in $packages) {
    # choco 2.x: `choco list` lists local packages by default (--local-only was removed)
    if (choco list --exact $pkg 2>$null | Select-String $pkg) {
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
# Non-interactive by default (Read-Host hangs/fails in piped & non-console
# sessions). Pass -GpuSoftware nvidia|amd|both to install in one shot.
$gpuPkgs = switch ($GpuSoftware) {
    'nvidia' { @('nvidia-app') }
    'amd'    { @('amd-software-adrenalin-edition') }
    'both'   { @('nvidia-app', 'amd-software-adrenalin-edition') }
    default  { @() }
}
if (-not $gpuPkgs) {
    Write-Host "   Skipping (installer was not asked to add GPU software)"
}

$amdDriversUrl = 'https://www.amd.com/en/support/download/drivers.html'
$uaHeaders = @{ 'User-Agent' = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)' }

foreach ($pkg in $gpuPkgs) {
    if (choco list --exact $pkg 2>$null | Select-String $pkg) {
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
# Rewrite hardcoded paths to current user. Handles both plain backslashes and
# YAML-escaped double backslashes (e.g. single-quoted strings like
# "C:\\Users\\Administrator\\...").
$glazewmConfig = Get-Content "$glazewmHome\config.yaml" -Raw -Encoding UTF8
$glazewmConfig = $glazewmConfig -replace [regex]::Escape("C:\Users\Administrator"), $env:USERPROFILE
$doubledProfile = $env:USERPROFILE.Replace('\', '\\')
$glazewmConfig = $glazewmConfig -replace [regex]::Escape("C:\\Users\\Administrator"), $doubledProfile
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

# ─────────────────────────── Startup (GlazeWM + Zebar) ────────────
Write-Step "Setting up GlazeWM + Zebar auto-start..."
# Both apps launch at logon from the user Startup folder. GlazeWM does NOT
# need the old stored-credentials scheduled task: it runs unelevated here and
# tiles everything else at the same (normal) integrity level. If you DO want
# elevated apps, GlazeWM must run elevated too - register it via Task
# Scheduler manually with stored credentials instead of using this shortcut.
$startupDir = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
$ws = New-Object -ComObject WScript.Shell
$startupApps = @(
    @{ Name = 'GlazeWM'; Exe = 'C:\Program Files\glzr.io\GlazeWM\glazewm.exe' },
    @{ Name = 'Zebar';   Exe = '' }
)

foreach ($app in $startupApps) {
    $shortcutPath = "$startupDir\$($app.Name).lnk"

    $exe = $app.Exe
    if (-not $exe) {
        $exe = @(
            "$env:LOCALAPPDATA\Programs\$($app.Name)\$($app.Name).exe",
            "C:\Program Files\glzr.io\$($app.Name)\$($app.Name).exe"
        ) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    }

    if (-not $exe -or -not (Test-Path -LiteralPath $exe)) {
        Write-Warn "Could not locate $($app.Name) - add it to Startup manually"
        continue
    }

    if (Test-Path -LiteralPath $shortcutPath) {
        Write-Ok "$($app.Name) auto-start already configured"
    } else {
        $shortcut = $ws.CreateShortcut($shortcutPath)
        $shortcut.TargetPath = $exe
        $shortcut.WorkingDirectory = Split-Path $exe
        $shortcut.WindowStyle = 1
        $shortcut.Save()
        Write-Ok "$($app.Name) added to Startup folder"
    }
}

# Clean up the old elevation approach (no longer used by this installer).
# Alacritty also launches directly now (see glazewm config), so the on-demand
# elevated task is gone too.
Remove-Item "$env:USERPROFILE\setup-admin-tasks.ps1" -Force -ErrorAction SilentlyContinue

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
Write-Host "  - Flow Launcher (app launcher)"
Write-Host "  - Alacritty (terminal)"
Write-Host "  - oh-my-posh (prompt theme: night-owl)"
Write-Host "  - fzf + zoxide + PSFzf (PowerShell profile)"
Write-Host "  - fastfetch (system info, MagikOS ASCII art)"
Write-Host "  - Discord, Steam, Brave"
Write-Host "  - Neovim (editor)"
Write-Host "  - JetBrains Mono + BlexMono Nerd Fonts"
Write-Host ""
Write-Host "Auto-start on login:" -ForegroundColor Yellow
Write-Host "  - GlazeWM + Zebar (Startup folder)"
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Log out and back in (for PATH changes)"
Write-Host "  2. GlazeWM + Zebar will auto-start on next login"
Write-Host "  3. Or launch them manually: glazewm, zebar"
Write-Host ""
Write-Host "Key bindings:" -ForegroundColor Yellow
Write-Host "  Alt+Enter  = Alacritty terminal"
Write-Host "  Alt+B      = Brave browser"
Write-Host "  Alt+Space  = Flow Launcher"
Write-Host "  Alt+1-9    = Switch workspace"
Write-Host "  Alt+R      = Resize mode"
Write-Host "  Alt+Shift+E = Exit GlazeWM"
Write-Host ""
