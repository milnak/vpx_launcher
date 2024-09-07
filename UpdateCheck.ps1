Param([string]$Path = '.')

### Visual Pinball X

Write-Host -ForegroundColor Cyan 'Visual Pinball X:'

$vpx = Join-Path -Path $Path -ChildPath 'VPinballX64.exe'

$vpxVer = 'v{0}' -f (Get-Item  $vpx -ErrorAction SilentlyContinue).VersionInfo.ProductVersion
if (!$vpxVer) {
    "Unable to find $vpx"
    return
}

try {
    $req = Invoke-WebRequest -Uri 'https://api.github.com/repos/vpinball/vpinball/releases'
}
catch {
    Write-Warning "Unable to connect to api.github.com: $_"
    return
}

$json = $req.Content | ConvertFrom-Json
$tag = $json.tag_name[0] -replace '-','.'
"Online version: $tag"
"Local version:  $vpxVer"

if ($vpxVer -ne $tag) {
    Write-Host -ForegroundColor Yellow 'VPX Update available from https://github.com/vpinball/vpinball/releases'
}

### Visual PinMAME

Write-Host -ForegroundColor Cyan 'Visual PinMAME:'

$vpm = Join-Path -Path $Path -ChildPath 'VPinMAME\VPinMAME64.dll'

$vpmVer = 'v{0}' -f (Get-Item  $vpm -ErrorAction SilentlyContinue).VersionInfo.ProductVersion
if (!$vpmVer) {
    "Unable to find $vpm"
    return
}

try {
    $req = Invoke-WebRequest -Uri 'https://api.github.com/repos/vpinball/pinmame/releases'
} 
catch {
    Write-Warning "Unable to connect to api.github.com: $_"
    return
}

$json = $req.Content | ConvertFrom-Json
$tag = $json.tag_name[0] -replace '-','.'
"Online version: $tag"
"Local version:  $vpmVer"

if ($vpmVer -ne $tag) {
    Write-Host -ForegroundColor Yellow 'VPM Update available from https://github.com/vpinball/pinmame/releases'
}

