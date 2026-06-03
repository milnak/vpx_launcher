Param([string]$Path = '.')

function Get-GithubUpdate {
    param (
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Repo
    )

    Write-Host "Checking $Repo for updates..."

    $vpxItem = Get-Item -LiteralPath $Path -ErrorAction SilentlyContinue
    if ($vpxItem) {
        # e.g. "3.7.0.222.8133307"
        $localVersion = $vpxItem.VersionInfo.ProductVersion # -replace '\.\d+$',''
    }
    else {
        $localVersion = '0.0.0.0'
    }

    try {
        # Note: /releases/latest doesn't include pre-release versions.
        $json = (Invoke-WebRequest -Uri ('https://api.github.com/repos/{0}/releases' -f $Repo)).Content | ConvertFrom-Json
    }
    catch {
        Write-Warning "Failed to check $Repo : $_"
        return $null
    }

    #  e.g. "v10.8.0-2051-28dd6c3"
    $onlineVersion = @($json.tag_name)[0] -replace '^v',''

    @{
        OnlineVersion = $onlineVersion
        LocalVersion  = $localVersion
        Path          = $Path
        Assets        = $json.assets.browser_download_url
    }
}

function Show-UpdateResult {
    param (
        [Parameter(Mandatory)][string]$Label,
        [Parameter(Mandatory)][hashtable]$Result,
        [Parameter(Mandatory)][string]$ExtractPath,
        [Parameter(Mandatory)][scriptblock]$AssetFilter
    )

    Write-Host -ForegroundColor Cyan "${Label}:"
    'Local version:  {0} ({1})' -f $Result.LocalVersion, $Result.Path
    'Online version: {0}' -f $Result.OnlineVersion

    if ($Result.LocalVersion -lt $Result.OnlineVersion) {
        Write-Host -ForegroundColor Yellow "$Label update available (Extract to '$ExtractPath'):"
        $Result.Assets | Where-Object $AssetFilter
    }
    else {
        Write-Host -ForegroundColor Green 'Latest version installed.'
    }
    ''
}

### Visual Pinball X

$destination = Resolve-Path -LiteralPath $Path
$result = Get-GithubUpdate -Path (Join-Path -Path $destination -ChildPath 'VPinballX64.exe') -Repo 'vpinball/vpinball'
if ($result) {
    Show-UpdateResult `
        -Label 'Visual Pinball X' `
        -Result $result -ExtractPath $destination `
        -AssetFilter { $_ -like '*/VPinballX-*-windows-x64-Release.zip' -and $_ -notlike '*-dev-third-party-*' }
}

### Visual PinMAME

$vpinmame_path = Join-Path -Path $Path -ChildPath 'VPinMAME'
New-Item -Path $vpinmame_path -ItemType Directory -ErrorAction SilentlyContinue | Out-Null
New-Item -Path (Join-Path -Path $vpinmame_path -ChildPath 'roms') -ItemType Directory -ErrorAction SilentlyContinue | Out-Null
$vpinmame_path = Resolve-Path -LiteralPath $vpinmame_path

$result = Get-GithubUpdate -Path (Join-Path -Path $vpinmame_path -ChildPath 'VPinMAME64.dll') -Repo 'vpinball/pinmame'
if ($result) {
    Show-UpdateResult `
        -Label 'Visual PinMAME' `
        -Result $result -ExtractPath $vpinmame_path `
        -AssetFilter { $_ -like '*/VPinMAME-sc-*-win-x64.*' }
}

### dmd-extensions

$result = Get-GithubUpdate -Path (Join-Path -Path $vpinmame_path -ChildPath 'dmdext.exe') -Repo 'freezy/dmd-extensions'
if ($result) {
    Show-UpdateResult `
        -Label 'dmd-extensions' `
        -Result $result -ExtractPath $vpinmame_path `
        -AssetFilter { $_ -like '*/dmdext-v*-x64.zip' }
}
