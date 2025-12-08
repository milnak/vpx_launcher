<#
.DESCRIPTION
    Create a ClrMAME .dat file for Visual Pinball VPX tables using data from puplookup.csv.
#>
[CmdletBinding()]
param (
    [string]$TablePath = (Resolve-Path 'Tables'),
    [string]$PupLookupCsvFilePath = '.\puplookup.csv',
    [string]$OutputXmlFilePath = "$($(Get-Location).Path)\Visual Pinball VPX Tables.xml"
)

if (-not (Test-Path $PupLookupCsvFilePath)) {
    Write-Error "PUP lookup CSV file not found: $PupLookupCsvFilePath"
    Write-Output 'Go to  https://virtualpinballspreadsheet.github.io/export'
    Write-Output 'Click 'Export CSV' and save 'puplookup.csv' to this folder.'
    exit 1
}
$puplookup = Get-Content $PupLookupCsvFilePath | ConvertFrom-Csv

# Create a new XML document
$xmlDocument = New-Object Xml.XmlDocument

# version, encoding, standalone
$xmlDecl = $xmlDocument.CreateXmlDeclaration("1.0", 'UTF-8', $null)
$xmlDocument.AppendChild($xmlDecl) | Out-Null

# Parameters: name, publicId, systemId, internalSubset
$docType = $xmlDocument.CreateDocumentType('datafile', '-//Logiqx//DTD ROM Management Datafile//EN', 'http://www.logiqx.com/Dats/datafile.dtd', $null)
$xmlDocument.AppendChild($docType) | Out-Null

# Create the root element
$root = $xmlDocument.CreateElement('datafile')
$xmlDocument.AppendChild($root) | Out-Null

$header = $xmlDocument.CreateElement('header')
$headerFields = @(
    @{ Name = 'author'; Value = 'JeffMill' }
    @{ Name = 'category'; Value = 'Pinball' }
    @{ Name = 'clrmamepro'; Value = $null }
    @{ Name = 'comment'; Value = 'Using details from https://virtualpinballspreadsheet.github.io/export' }
    @{ Name = 'date'; Value = (Get-Date).ToString('MMM d yyyy') }
    @{ Name = 'description'; Value = 'VPX Tables' }
    @{ Name = 'email'; Value = 'email' }
    @{ Name = 'homepage'; Value = 'homepage' }
    @{ Name = 'name'; Value = 'Visual Pinball VPX Tables' }
    @{ Name = 'url'; Value = 'url' }
    @{ Name = 'version'; Value = '1.0' }
)
foreach ($field in $headerFields) {
    $element = $xmlDocument.CreateElement($field.Name)
    if ($field.Value) {
        $element.InnerText = $field.Value
    }
    $header.AppendChild($element) | Out-Null
}
$root.AppendChild($header) | Out-Null

# Table folder structure assumed to be in format:
#
# Tables
# ├───Whoa Nellie! Big Juicy Melons (Stern 2015)
# │        Whoa Nellie! Big Juicy Melons (Stern 2015) UncleWilly 2.1.4 MOD VR.vpx
# │        Whoa Nellie! Big Juicy Melons (Stern 2015) UncleWilly 2.1.4 MOD VR.directb2s

foreach ($directory in (Get-ChildItem -LiteralPath $TablePath -File -Include '*.vpx', '*.directb2s' -Recurse -Depth 1 | Group-Object DirectoryName)) {
    $parentFolderName = Split-Path -Leaf -Path $directory.Name

    Write-Verbose "Looking for '$parentFolderName' in PUPlookup"
    $entries = $puplookup | Where-Object GameName -eq $parentFolderName
    if ($entries.Count -eq 0) {
        Write-Warning "No matching entries in PUPlookup for '$parentFolderName'"
        continue
    }

    $gameFileName = $directory.Group[0].BaseName

    $found = $null
    foreach ($entry in $entries) {
        Write-Verbose "'$($entry.GameFileName)' -eq '$gameFileName' ?"
        if ($entry.GameFileName -eq $gameFileName) {
            $found = $entry
            break
        }
    }
    if (-not $found) {
        Write-Warning "Cant find GameFileName entry for '$gameFileName' in folder '$parentFolderName'"
        continue
    }

    $machine = $xmlDocument.CreateElement('machine')

    $attribute = $xmlDocument.CreateAttribute('name')
    $attribute.Value = $found.GameName
    $machine.Attributes.Append($attribute) | Out-Null

    $year = $xmlDocument.CreateElement('year')
    $year.InnerText = $found.GameYear
    $machine.AppendChild($year) | Out-Null

    $manufacturer = $xmlDocument.CreateElement('manufacturer')
    $manufacturer.InnerText = $found.Manufact
    $machine.AppendChild($manufacturer) | Out-Null

    foreach ($item in $directory.Group) {
        # Note: description not required.
        # $description = $xmlDocument.CreateElement('description')
        # $description.InnerText = $found.WebLink2URL
        # $machine.AppendChild($description) | Out-Null

        $rom = $xmlDocument.CreateElement('rom')

        $attribute = $xmlDocument.CreateAttribute('name')
        $attribute.Value = $item.Name
        $rom.Attributes.Append($attribute) | Out-Null

        $attribute = $xmlDocument.CreateAttribute('size')
        $attribute.Value = $item.Length
        $rom.Attributes.Append($attribute) | Out-Null

        # Note: CRC not required.
        # $attribute = $xmlDocument.CreateAttribute('crc')
        # $attribute.Value = ''''
        # $rom.Attributes.Append($attribute) | Out-Null

        $attribute = $xmlDocument.CreateAttribute('md5')
        $attribute.Value = ((Get-FileHash -LiteralPath $item.FullName -Algorithm MD5).Hash).ToLower()
        $rom.Attributes.Append($attribute) | Out-Null

        $attribute = $xmlDocument.CreateAttribute('sha1')
        $attribute.Value = ((Get-FileHash -LiteralPath $item.FullName -Algorithm SHA1).Hash).ToLower()
        $rom.Attributes.Append($attribute) | Out-Null

        $machine.AppendChild($rom) | Out-Null
    }

    $root.AppendChild($machine) | Out-Null
}

# Save to file
$xmlDocument.Save($OutputXmlFilePath)
