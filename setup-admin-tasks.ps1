#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Registers truly-elevated scheduled tasks for GlazeWM + Alacritty.
.DESCRIPTION
    The listed apps need to run at High integrity so the (also elevated)
    GlazeWM window manager can tile them and toggle their fullscreen.
    An Interactive+Highest task does NOT actually elevate a UAC-filtered
    admin session, so this registers the tasks with STORED CREDENTIALS
    ("run whether logged on or not" + RUNLEVEL HIGHEST). Result: the apps
    launch fully elevated with NO UAC prompts.

    Your password is used only to register the tasks (stored securely by
    Windows Task Scheduler). It is never saved to this repo or disk.
.NOTES
    Run as Administrator once. Re-run any time the password changes.
#>

$ErrorActionPreference = 'Stop'

function Write-Step { param([string]$Msg) Write-Host "`n>> $Msg" -ForegroundColor Cyan }
function Write-Ok   { param([string]$Msg) Write-Host "   [OK] $Msg" -ForegroundColor Green }
function Write-Warn { param([string]$Msg) Write-Host "   [!] $Msg" -ForegroundColor Yellow }

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warn "Please run this script as Administrator."
    exit 1
}

# Securely capture credentials (in-memory only, never logged).
Write-Step "Enter your Windows login to register the elevated tasks."
$cred = Get-Credential -Message "Windows credentials for elevated GlazeWM/Alacritty tasks (used only to register scheduled tasks; password is not saved to disk or this repo)" -UserName "$env:USERDOMAIN\$env:USERNAME"
if (-not $cred) {
    Write-Warn "No credentials provided - aborting."
    exit 1
}
$pw = $cred.GetNetworkCredential().Password

$glazewmExe   = 'C:\Program Files\glzr.io\GlazeWM\glazewm.exe'
$alacrittyExe = 'C:\Program Files\Alacritty\alacritty.exe'

$tasks = @(
    @{ Name = 'GlazeWM';        Exe = $glazewmExe;   AutoStart = $true  }
    @{ Name = 'AlacrittyAdmin'; Exe = $alacrittyExe; AutoStart = $false }
)

foreach ($t in $tasks) {
    if (-not (Test-Path $t.Exe)) {
        Write-Warn "Skipping $($t.Name) - $($t.Exe) not found."
        continue
    }

    # Remove any prior registration so we re-register cleanly.
    Unregister-ScheduledTask -TaskName $t.Name -Confirm:$false -ErrorAction SilentlyContinue

    $action  = New-ScheduledTaskAction -Execute $t.Exe
    # MultipleInstances Parallel: Alt+Enter spawns a fresh Alacritty even if one is open
    # (IgnoreNew silently refuses the second launch). ExecutionTimeLimit PT0S: never
    # force-kill the window after 72h.
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -RestartCount 5 -RestartInterval (New-TimeSpan -Minutes 1) -MultipleInstances Parallel -ExecutionTimeLimit ([TimeSpan]::Zero)
    $registerArgs = @{
        TaskName  = $t.Name
        Action    = $action
        Settings  = $settings
        User      = $cred.UserName
        Password  = $pw
        RunLevel  = 'Highest'
        Force     = $true
    }
    if ($t.AutoStart) {
        # Launch elevated as soon as the user logs on.
        $registerArgs.Trigger = New-ScheduledTaskTrigger -AtLogOn -User $cred.UserName
    }

    Register-ScheduledTask @registerArgs | Out-Null

    $runLevel = (Get-ScheduledTask -TaskName $t.Name).Principal.RunLevel
    $logon    = (Get-ScheduledTask -TaskName $t.Name).Principal.LogonType
    Write-Ok "$($t.Name) registered (RunLevel: $runLevel, LogonType: $logon)"

    # For AlacrittyAdmin (no trigger) verify it fires elevated on demand.
    if (-not $t.AutoStart) {
        schtasks /run /tn $t.Name | Out-Null
        Start-Sleep -Seconds 2
        Write-Ok "AlacrittyAdmin test-run issued."
    }
}

Write-Host "`nDone. Restart the session or log out/in - GlazeWM will start elevated." -ForegroundColor Magenta