# .\Get-TableDetails.ps1 | Select-Object FileName, TableName, TableVersion, AuthorName | ConvertTo-Csv -NoTypeInformation

[CmdletBinding()]
Param(
    [string]$TablePath = (Resolve-Path 'Tables'),
    [string]$Filter = '*.vpx'
)

Import-Module "./StructuredStorage.psm1"

#
# MAIN
#

# '# Table Details'
# ''

# REVIEW: Is .Version binary?
# REVIEW: Are .CustomInfoTags binary?
Get-ChildItem -LiteralPath $TablePath -File -Filter $Filter -Recurse -Depth 1 | ForEach-Object {
    Write-Progress -Activity "Processing Tables" -Status $_.BaseName
    Read-VpxMetadata -Path $_.FullName
    # $metadata = Read-VpxMetadata -Path $_.FullName
    # foreach ($value in $metadata) {
    #     '## {0}' -f $value.Filename
    #     ''
    #     'Name: {0}' -f $value.TableName
    #     ''
    #     'Version: {0} - {1}' -f $value.TableVersion, $value.ReleaseDate
    #     ''
    #     'Author: {0} ({1}) - {2}' -f $value.AuthorName, $value.AuthorEmail, $value.AuthorWebSite
    #     ''
    #     ''
    #     if ($value.TableInfo) {
    #         '### Info'
    #         ''
    #         # '```text'
    #         $value.TableInfo
    #         # '```'
    #         ''
    #     }
    #     if ($value.TableDescription) {
    #         '### Description'
    #         ''
    #         # '```text'
    #         $value.TableDescription
    #         # '```'
    #         ''
    #     }
    #     if ($value.TableRules) {
    #         '### Rules'
    #         ''
    #         # '```text'
    #         $value.TableRules
    #         # '```'
    #         ''
    #     }
    # }
}
