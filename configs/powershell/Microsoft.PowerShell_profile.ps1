# System Info
fastfetch

# Zoxide (Jump directories)
try { Invoke-Expression (& { (zoxide init powershell | Out-String) }) } catch {}

# FZF & Hotkeys
try {
    Import-Module PSFzf -ErrorAction Stop
    Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'
} catch {}

# --- Icons ---
try { Import-Module Terminal-Icons -ErrorAction Stop } catch {}

# --- Oh My Posh ---
$ompTheme = "$env:LOCALAPPDATA\Programs\oh-my-posh\themes\night-owl.omp.json"
if (Test-Path $ompTheme) {
    oh-my-posh init pwsh --config "$ompTheme" | Invoke-Expression
} else {
    oh-my-posh init pwsh --config "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/night-owl.omp.json" | Invoke-Expression
}
# Enable predictive suggestions (Fish-like)
try {
    Set-PSReadLineOption -PredictionSource History
    Set-PSReadLineOption -PredictionViewStyle ListView
    Set-PSReadLineOption -Colors @{ InlinePrediction = "DarkGray" }
} catch {}

# Chocolatey tab completion
$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path($ChocolateyProfile)) {
  Import-Module "$ChocolateyProfile"
}
