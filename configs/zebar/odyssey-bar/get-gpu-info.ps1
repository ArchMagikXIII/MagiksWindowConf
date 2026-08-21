# get-gpu-info.ps1
# Detects GPU hardware and writes info to gpu-info.js for the Zebar bar.
# Runs before Zebar on startup.

$ErrorActionPreference = 'SilentlyContinue'

$gpus = Get-CimInstance Win32_VideoController | Select-Object Name, AdapterRAM
$gpuNames = $gpus | ForEach-Object {
    $name = $_.Name.Trim()
    # Shorten common prefixes
    $name = $name -replace 'NVIDIA GeForce ', 'NVIDIA '
    $name = $name -replace 'AMD Radeon ', ''
    $name = $name -replace 'Intel\(R\) UHD Graphics ', 'Intel UHD '
    $name = $name -replace 'Intel\(R\) Arc', 'Intel Arc'
    $name
}

$js = @"
window.__GPU_LIST__ = $(ConvertTo-Json -InputObject $gpuNames);
"@

$jsPath = Join-Path $PSScriptRoot "odyssey-bar\gpu-info.js"
[System.IO.File]::WriteAllText($jsPath, $js)
Write-Host "GPU info written: $($gpuNames -join ', ')"
