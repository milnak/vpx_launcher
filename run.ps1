Param([string]$Path = 'D:\Visual Pinball')

$launcherArgs = @{
    Verbose    = $true
    PinballExe = Join-Path $Path 'VPinballX64.exe'
    TablePath  = Join-Path $Path 'Tables'
    RomPath    = Join-Path $Path 'VPinMAME\roms'
    Database   = Join-Path $PSScriptRoot 'vpx_launcher.csv'
}

$launcherArgs
& (Join-Path $PSScriptRoot 'vpx_launcher.ps1') @launcherArgs


