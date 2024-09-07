Param([string]$Path = '.')

### Visual Pinball X

Write-Host -ForegroundColor Cyan 'Visual Pinball X:'

$vpx = Join-Path -Path $Path -ChildPath 'VPinballX64.exe'

$vpxItem = Get-Item  $vpx -ErrorAction SilentlyContinue
if ($vpxItem) {
    $vpxVer = 'v{0}' -f $vpxItem.VersionInfo.ProductVersion

    try {
        $req = Invoke-WebRequest -Uri 'https://api.github.com/repos/vpinball/vpinball/releases'
    }
    catch {
        Write-Warning "Unable to connect to api.github.com: $_"
        return
    }

    $json = $req.Content | ConvertFrom-Json
    $tag = $json.tag_name[0] -replace '-', '.'
    "Online version: $tag"
    "Local version:  $vpxVer ($vpxItem)"

    if ($vpxVer -ne $tag) {
        Write-Host -ForegroundColor Yellow 'VPX Update available from https://github.com/vpinball/vpinball/releases'
    }
    else {
        Write-Host -ForegroundColor Green 'Latest version installed.'
    }
}
else {
    "Unable to find $vpx"
}

### Visual PinMAME

Write-Host -ForegroundColor Cyan 'Visual PinMAME:'

$vpm = Join-Path -Path $Path -ChildPath 'VPinMAME\VPinMAME64.dll'
$vpmItem = Get-Item  $vpm -ErrorAction SilentlyContinue
if ($vpmItem) {
    $vpmVer = 'v{0}' -f $vpmItem.VersionInfo.ProductVersion

    try {
        $req = Invoke-WebRequest -Uri 'https://api.github.com/repos/vpinball/pinmame/releases'
    }
    catch {
        Write-Warning "Unable to connect to api.github.com: $_"
        return
    }

    $json = $req.Content | ConvertFrom-Json
    $tag = $json.tag_name[0] -replace '-', '.'
    "Online version: $tag"
    "Local version:  $vpmVer ($vpmItem)"

    if ($vpmVer -ne $tag) {
        Write-Host -ForegroundColor Yellow 'VPM Update available from https://github.com/vpinball/pinmame/releases'
    }
    else {
        Write-Host -ForegroundColor Green 'Latest version installed.'
    }
}
else {
    "Unable to find $vpm"
}


