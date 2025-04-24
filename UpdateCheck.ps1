Param([string]$Path = '.')

function Check-GithubUpdate {
    param (
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Repo
    )

    $vpxItem = Get-Item -LiteralPath $Path -ErrorAction Stop

    $localVersion = 'v{0}' -f $vpxItem.VersionInfo.ProductVersion

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

Write-Host -ForegroundColor Cyan 'Visual PinMAME:'
$destination = Resolve-Path -LiteralPath (Join-Path -Path $Path -ChildPath 'VPinMAME')
$result = Check-GithubUpdate -Path (Join-Path -Path $destination -ChildPath 'VPinMAME64.dll') -Repo 'vpinball/pinmame'
'Local version:  {0} ({1})' -f $result.LocalVersion, $result.Path
'Online version: {0}' -f $result.OnlineVersion

if ($result.LocalVersion -ne $result.OnlineVersion) {
    Write-Host -ForegroundColor Yellow "VPM Update available (Extract to '$destination'):"
    $result.Assets | Where-Object { $_ -like '*/VPinMAME-sc-*-win-x64.*' }
}
else {
    Write-Host -ForegroundColor Green 'Latest version installed.'
}
