# .\Get-TableDetails.ps1 | Select-Object FileName, TableName, TableVersion, AuthorName | ConvertTo-Csv -NoTypeInformation

[CmdletBinding()]
Param(
    [string]$TablePath = (Resolve-Path 'Tables'),
    [string]$Filter = '*.vpx'
)

#
# MAIN
#

# '# Table Details'
# ''

Get-ChildItem -LiteralPath $TablePath -File -Filter $Filter -Recurse -Depth 1 | ForEach-Object -Parallel {
    Import-Module "./StructuredStorage.psm1"

    Write-Progress -Activity "Processing Tables" -Status $_.BaseName
    Read-VpxMetadata -Path $_.FullName
}
