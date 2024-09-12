# Parse benchmark output:
# Get-Content out.csv | ConvertFrom-Csv -Header 'table','routine','ms' | Sort-Object -Descending { [int]$_.ms } | Select-Object -First 10

Param(
    [string]$Path = 'D:\Visual Pinball', 
    [switch]$Benchmark = $false, 
    [switch]$Verbose = $false
    )

$launcherArgs = @{
    Benchmark  = $Benchmark
    Verbose    = $Verbose
    PinballExe = Join-Path $Path 'VPinballX64.exe'
    TablePath  = Join-Path $Path 'Tables'
}

if (!$Benchmark) {
    $launcherArgs
    ''
    'Starting vpx_launcher.ps1'
    ''
}

& (Join-Path $PSScriptRoot 'vpx_launcher.ps1') @launcherArgs


