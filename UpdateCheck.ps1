Param([string]$Path = '.')

function Check-GithubUpdate {
    param (
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Repo
    )

    $vpxItem = Get-Item -LiteralPath $Path -ErrorAction SilentlyContinue
    if ($vpxItem) {
        $localVersion = 'v{0}' -f $vpxItem.VersionInfo.ProductVersion
    }
    else {
        $localVersion = '0.0.0.0'
    }

    $json = (Invoke-WebRequest -Uri ('https://api.github.com/repos/{0}/releases' -f $Repo)).Content | ConvertFrom-Json

    $onlineVersion = @($json.tag_name)[0] -replace '-', '.'

    @{
        OnlineVersion = $onlineVersion
        LocalVersion  = $localVersion
        Path          = $Path
        Assets        = $json.assets.browser_download_url | Where-Object { $_ -match $onlineVersion }
    }
}

### Visual Pinball X

Write-Host -ForegroundColor Cyan 'Visual Pinball X:'
$destination = Resolve-Path -LiteralPath $Path
$result = Check-GithubUpdate -Path (Join-Path -Path $destination -ChildPath 'VPinballX64.exe') -Repo 'vpinball/vpinball'
'Local version:  {0} ({1})' -f $result.LocalVersion, $result.Path
'Online version: {0}' -f $result.OnlineVersion

if ($result.LocalVersion -ne $result.OnlineVersion) {
    Write-Host -ForegroundColor Yellow "VPX Update available (Extract to '$destination'):"
    $result.Assets | Where-Object { $_ -like '*/VPinballX-*-windows-x64-Release.zip' -and $_ -notlike '*-dev-third-party-*' }
}
else {
    Write-Host -ForegroundColor Green 'Latest version installed.'
}

''

### Visual PinMAME

mkdir 'VPinMAME' -ErrorAction SilentlyContinue
mkdir 'VPinMAME/roms' -ErrorAction SilentlyContinue

Write-Host -ForegroundColor Cyan 'Visual PinMAME:'
$vpinmame_path = Resolve-Path -LiteralPath (Join-Path -Path $Path -ChildPath 'VPinMAME') -ErrorAction SilentlyContinue
$destination = Join-Path -Path $vpinmame_path -ChildPath 'VPinMAME64.dll'
$result = Check-GithubUpdate -Path $destination -Repo 'vpinball/pinmame'
'Local version:  {0} ({1})' -f $result.LocalVersion, $result.Path
'Online version: {0}' -f $result.OnlineVersion

if ($result.LocalVersion -ne $result.OnlineVersion) {
    Write-Host -ForegroundColor Yellow "VPM Update available (Extract to '$vpinmame_path'):"
    $result.Assets | Where-Object { $_ -like '*/VPinMAME-sc-*-win-x64.*' }
}
else {
    Write-Host -ForegroundColor Green 'Latest version installed.'
}

''

### dmd-extensions

Write-Host -ForegroundColor Cyan 'dmd-extensions:'
$destination = Join-Path -Path $vpinmame_path -ChildPath 'dmdext.exe'
$result = Check-GithubUpdate -Path $destination -Repo 'freezy/dmd-extensions'
'Local version:  {0} ({1})' -f $result.LocalVersion, $result.Path
'Online version: {0}' -f $result.OnlineVersion

if ($result.LocalVersion -ne $result.OnlineVersion) {
    Write-Host -ForegroundColor Yellow "dmd-extensions Update available (Extract to '$vpinmame_path'):"
    $result.Assets | Where-Object { $_ -like '*/dmdext-v*-x64.zip' }
}
else {
    Write-Host -ForegroundColor Green 'Latest version installed.'
}
