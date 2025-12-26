# Table folder structure assumed to be in format:
#
# Tables
# ├───Whoa Nellie! Big Juicy Melons (Stern 2015)
# │        Whoa Nellie! Big Juicy Melons (Stern 2015) UncleWilly 2.1.4 MOD VR.vpx

[CmdletBinding()]
param (
    [string]$TablePath = (Resolve-Path 'Tables'),
    [string]$PupLookupCsvFilePath = '.\puplookup.csv',
    # e.g. .\AuditTables.ps1 -ShowValid | ConvertTo-Csv
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
# $parentFolderName = 'Zarza (Taito do Brasil 1982)'
# $table.BaseName      = 'Zarza (Taito do Brasil 1982) JPSalas 6.0.0'

$requiredRoms = @()
$validTableCount = 0

$tables = Get-ChildItem -LiteralPath $TablePath -File -Filter '*.vpx' -Recurse -Depth 1 | Select-Object DirectoryName, BaseName
foreach ($table in $tables) {
    $isValid = $false

    $parentFolderName = Split-Path -Path $table.DirectoryName -Leaf

    Write-Verbose "Looking for '$parentFolderName' in PUPlookup"
    $entries = $puplookup | Where-Object GameName -eq $parentFolderName

    if ($entries.Count -ne 0) {
        # Found the matching folder name, now check the VPX file name

        Write-Verbose "Found $($entries.Count) matching entries for GameName '$parentFolderName'"

        foreach ($entry in $entries) {
            Write-Verbose "'$($entry.GameFileName)' -eq '$($table.BaseName)' ?"
            if ($entry.GameFileName -eq $table.BaseName) {
                $isValid = $true
                break
            }
        }

        if ($isValid) {
            $validTableCount++
            if ($ShowValid) {
                # Folder AND VPX filename match!

                if ($entry.Rom -ne '') {
                    $requiredRoms += $entry.Rom
                }

                $metadata = Read-VpxMetadata "$($table.DirectoryName)/$($table.BaseName).vpx"

                # For ShowValid, use pipeline so that it can be captured or redirected
                [PSCustomObject]@{
                    FileName = $table.BaseName
                    Name     = $metadata.TableName
                    Author   = $metadata.AuthorName
                    Version  = $metadata.TableVersion
                    Date     = $metadata.ReleaseDate
                }
                # Write-Host  "Match: $parentFolderName\$AnsiBoldGreen$($table.BaseName).vpx$AnsiResetAll"
                # Write-Host ("  Name: {0}`n  Author: {1}`n  Version: {2}`n  Date: {3}" `
                #         -f $metadata.TableName, $metadata.AuthorName, $metadata.TableVersion, $metadata.ReleaseDate)
                # Write-Host ''
            }
        }
        else {
            # Folder match, but VPX filename mismatch

            Write-Host "Filename Mismatch: $AnsiBoldRed$($table.BaseName)$AnsiResetAll in '$parentFolderName'"
            $FullPath = "$($table.DirectoryName)/$($table.BaseName).vpx"
            $metadata = Read-VpxMetadata $FullPath
            Write-Host ("  Metadata: $AnsiBoldYellow{0} {1} {2} {3}$AnsiResetAll" `
                    -f $metadata.TableName, $metadata.AuthorName, $metadata.TableVersion, $metadata.ReleaseDate)
            if ($entries.Count -eq 1) {
                $AnsiColor = $AnsiBoldYellow
            }
            else {
                $AnsiColor = $AnsiBoldPurple
            }
            foreach ($entry in $entries) {
                Write-Host "  Maybe: $AnsiColor$($entry.GameFileName)$AnsiResetAll ($($entry.GAMEVER)) - $AnsiBoldBlue$($entry.WebLink2URL)$AnsiResetAll"
            }
        }
    }
    else {
        # No matching folder name found

        # assumes format like "Table (Mfr Year)"
        $tableName = ($parentFolderName -split ' \(')[0]
        Write-Verbose "Looking for '$tableName' in PUPlookup (GameName)"
        # TODO: Remove prefixed 'the', 'a', 'an' for better matching
        $suggestions = $puplookup.GameName | Where-Object { $_ -like "*$tableName*" } | Select-Object -Unique | Sort-Object
        Write-Host "Folder mismatch: $AnsiBoldRed$($parentFolderName)$AnsiResetAll"
        if ($suggestions.Count -ne 0) {
            if ($suggestions.Count -eq 1) {
                $AnsiColor = $AnsiBoldYellow
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

    if (-not $isValid) {
        Write-Host ""
    }
}

if ($ShowValid) {
    Write-Host 'Required Roms:'
    Write-Host ("'" + (($requiredRoms | Sort-Object -Unique) -join "', '") + "'")
}

Write-Host ("Valid tables: $validTableCount / $($tables.Count)")
