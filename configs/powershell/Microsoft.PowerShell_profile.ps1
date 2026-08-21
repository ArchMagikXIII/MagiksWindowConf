# System Info
fastfetch

# Zoxide (Jump directories)
Invoke-Expression (& { (zoxide init powershell | Out-String) })

# FZF & Hotkeys
Import-Module PSFzf
Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'

# --- Icons ---
Import-Module Terminal-Icons

# --- Oh My Posh ---
$ompTheme = "$env:LOCALAPPDATA\Programs\oh-my-posh\themes\night-owl.omp.json"
if (Test-Path $ompTheme) {
    oh-my-posh init pwsh --config "$ompTheme" | Invoke-Expression
} else {
    oh-my-posh init pwsh --config "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/night-owl.omp.json" | Invoke-Expression
}
# Enable predictive suggestions (Fish-like)
Set-PSReadLineOption -PredictionSource History
Set-PSReadLineOption -PredictionViewStyle ListView

# Use a standard console color for suggestions instead of raw escape codes
Set-PSReadLineOption -Colors @{ InlinePrediction = "DarkGray" }
# Import the Chocolatey Profile that contains the necessary code to enable
# tab-completions to function for `choco`.
# Be aware that if you are missing these lines from your profile, tab completion
# for `choco` will not function.
# See https://ch0.co/tab-completion for details.
$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path($ChocolateyProfile)) {
  Import-Module "$ChocolateyProfile"
}
