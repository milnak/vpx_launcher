# Table folder structure assumed to be in format:
#
# Tables
# ├───Whoa Nellie! Big Juicy Melons (Stern 2015)
# │        Whoa Nellie! Big Juicy Melons (Stern 2015) UncleWilly 2.1.4 MOD VR.vpx

[CmdletBinding()]
param (
    [string]$TablePath = (Resolve-Path 'Tables'),
    [string]$PupLookupCsvFilePath = '.\puplookup.csv',
    [switch]$ShowValid
)

Import-Module "./StructuredStorage.psm1"

$AnsiBoldRed = "`e[1;31m"
$AnsiBoldGreen = "`e[1;32m"
$AnsiBoldYellow = "`e[1;33m"
$AnsiBoldBlue = "`e[1;34m"
$AnsiBoldPurple = "`e[1;35m"
$AnsiBoldCyan = "`e[1;36m"
$AnsiBoldWhite = "`e[1;37m"

$AnsiResetAll = "`e[0m"

# e.g.
# GameFileName : Big Guns (Williams 1987) Morttis 2.1-3.0 MOD
# GameName     : Big Guns (Williams 1987)
# Manufact     : Williams
# GameYear     : 1987
# NumPlayers   : 4
# GameType     : SS
# Category     :
# GameTheme    : Science Fiction
# WebLinkURL   : http://www.ipdb.org/machine.cgi?id=250
# WebLink2URL  : https://virtualpinballspreadsheet.github.io/tables?game=C41LTxtl&fileType=tables&fileId=3KsimEXZ
# IPDBNum      : 250
# AltRunMode   :
# DesignedBy   : Mark Ritchie
# Author       : Morttis, Arconovum, 32assassin, Destruk, Francisco666, rom
# GAMEVER      : 2.1-3.0
# Rom          : bguns_l8
# Tags         : FSS, MOD
# VPS-ID       : 3KsimEXZ
# GameFileName : Big Guns (Williams 1987) Morttis 2.1-3.0 MOD
# GameName     : Big Guns (Williams 1987)
# Manufact     : Williams
# GameYear     : 1987
# NumPlayers   : 4
# GameType     : SS
# Category     :
# GameTheme    : Science Fiction
# WebLinkURL   : http://www.ipdb.org/machine.cgi?id=250
# WebLink2URL  : https://virtualpinballspreadsheet.github.io/tables?game=C41LTxtl&fileType=tables&fileId=3KsimEXZ
# IPDBNum      : 250
# AltRunMode   :
# DesignedBy   : Mark Ritchie
# Author       : Morttis, Arconovum, 32assassin, Destruk, Francisco666, rom
# GAMEVER      : 2.1-3.0
# Rom          : bguns_l8
# Tags         : FSS, MOD
# VPS-ID       : 3KsimEXZ
# WebGameID    : 3KsimEXZ

if (-not (Test-Path $PupLookupCsvFilePath)) {
    Write-Error "PUP lookup CSV file not found: $PupLookupCsvFilePath"
    Write-Output 'Go to  https://virtualpinballspreadsheet.github.io/export'
    Write-Output 'Click 'Export CSV' and save 'puplookup.csv' to this folder.'
    exit 1
}
$puplookup = Get-Content $PupLookupCsvFilePath | ConvertFrom-Csv

# Tables
# ├───Zarza (Taito do Brasil 1982)
# │        Zarza (Taito do Brasil 1982) JPSalas 6.0.0.vpx
#
# $table.DirectoryName = 'E:\Visual Pinball\tables\Zarza (Taito do Brasil 1982)'
# $parentDirectory = 'Zarza (Taito do Brasil 1982)'
# $table.BaseName      = 'Zarza (Taito do Brasil 1982) JPSalas 6.0.0'

foreach ($table in (Get-ChildItem -LiteralPath $TablePath -File -Filter '*.vpx' -Recurse -Depth 1 | Select-Object DirectoryName, BaseName)) {
    $parentDirectory = Split-Path -Path $table.DirectoryName -Leaf

    Write-Verbose "Looking for '$parentDirectory' in PUPlookup"
    $entries = $puplookup | Where-Object GameName -eq $parentDirectory

    if ($entries.Count -ne 0) {
        # Found the matching folder name, now check the VPX file name

        Write-Verbose "Found $($entries.Count) matching entries for GameName '$parentDirectory'"
        $found = $null
        foreach ($entry in $entries) {
            Write-Verbose "'$($entry.GameFileName)' -eq '$($table.BaseName)' ?"
            if ($entry.GameFileName -eq $table.BaseName) {
                $found = $entry.GameFileName
                break
            }
        }


        if ($found) {
            if ($ShowValid) {
                # Folder AND VPX filename match

                Write-Host  "Match: $AnsiBoldGreen$($found).vpx$AnsiResetAll"
            }
        }
        else {
            # Folder match, but VPX filename mismatch

            Write-Host "Filename Mismatch: ($parentDirectory)\$AnsiBoldWhite$($table.BaseName)$AnsiResetAll"
            $FullPath = "$($table.DirectoryName)/$($table.BaseName).vpx"
            $metadata = Read-VpxMetadata $FullPath
            Write-Host ("  Metadata: $($AnsiBoldYellow){0}, {1}, {2} ({3})$AnsiResetAll" `
                    -f $metadata.TableName, $metadata.AuthorName, $metadata.TableVersion, $metadata.ReleaseDate)
            if ($entries.Count -eq 1) {
                $AnsiColor = $AnsiBoldGreen
            }
            else {
                $AnsiColor = $AnsiBoldPurple
            }
            foreach ($entry in ($entries | Sort-Object -Descending GAMEVER)) {
                Write-Host "  Maybe: $AnsiColor$($entry.GameFileName)$AnsiResetAll ($($entry.GAMEVER)) - $AnsiBoldBlue$($entry.WebLink2URL)$AnsiResetAll"
            }
        }
    }
    else {
        # No matching folder name found

        # assumes format like "Table (Mfr Year)"
        $tableName = ($parentDirectory -split ' \(')[0]
        Write-Verbose "Looking for '$tableName' in PUPlookup (GameName)"
        # TODO: Remove prefixed 'the', 'a', 'an' for better matching
        $suggestions = $puplookup.GameName | Where-Object { $_ -like "*$tableName*" } | Select-Object -Unique | Sort-Object
        Write-Host "Folder mismatch: $AnsiBoldWhite$($parentDirectory)$AnsiResetAll"
        if ($suggestions.Count -ne 0) {
            if ($suggestions.Count -eq 1) {
                $AnsiColor = $AnsiBoldGreen
            }
            else {
                $AnsiColor = $AnsiBoldCyan
            }
            foreach ($suggestion in $suggestions) {
                Write-Host "  Maybe: $AnsiColor$suggestion$AnsiResetAll"
            }
        }
        else {
            Write-Host "  $($AnsiBoldRed)No suggestions found.$AnsiResetAll"
        }
    }

    Write-Host ""
}
