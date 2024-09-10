Param([string]$Path = 'D:\Visual Pinball')

$launcherArgs = @{
    Verbose    = $true
    # Benchmark  = $true
    PinballExe = Join-Path $Path 'VPinballX64.exe'
    TablePath  = Join-Path $Path 'Tables'
}

$launcherArgs
& (Join-Path $PSScriptRoot 'vpx_launcher.ps1') @launcherArgs


