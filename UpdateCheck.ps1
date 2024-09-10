Param([string]$Path = '.')

function Check-GithubUpdate {
    param (
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Repo
    )

    $vpxItem = Get-Item -LiteralPath $Path

    $vpxVer = 'v{0}' -f $vpxItem.VersionInfo.ProductVersion

    $json = (Invoke-WebRequest -Uri ('https://api.github.com/repos/{0}/releases' -f $Repo)).Content | ConvertFrom-Json

    $tag_name = @($json.tag_name)[0] -replace '-', '.'

    @{
        OnlineVersion = $tag_name
        LocalVersion  = $vpxVer
        LocalPath     = $Path
        Assets        = $json.assets.browser_download_url | Where-Object { $_ -match $tag_name }
    }
}

### Visual Pinball X

Write-Host -ForegroundColor Cyan 'Visual Pinball X:'
$result = Check-GithubUpdate -Path (Join-Path -Path $Path -ChildPath 'VPinballX64.exe') -Repo 'vpinball/vpinball'
'Local version:  {0} ({1})' -f $result.LocalVersion, $result.LocalPath
'Online version: {0}' -f $result.OnlineVersion

if ($result.LocalVersion -ne $result.OnlineVersion) {
    Write-Host -ForegroundColor Yellow 'VPX Update available from https://github.com/vpinball/vpinball/releases :'
    $result.Assets
}
else {
    Write-Host -ForegroundColor Green 'Latest version installed.'
}

''

### Visual PinMAME

Write-Host -ForegroundColor Cyan 'Visual PinMAME:'
$result = Check-GithubUpdate -Path (Join-Path -Path $Path -ChildPath 'VPinMAME\VPinMAME64.dll') -Repo 'vpinball/pinmame'
'Local version:  {0} ({1})' -f $result.LocalVersion, $result.LocalPath
'Online version: {0}' -f $result.OnlineVersion

if ($result.LocalVersion -ne $result.OnlineVersion) {
    Write-Host -ForegroundColor Yellow 'VPM Update available from https://github.com/vpinball/pinmame/releases :'
    $result.Assets
}
else {
    Write-Host -ForegroundColor Green 'Latest version installed.'
}
