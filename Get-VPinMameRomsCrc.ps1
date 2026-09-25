<#
.DESCRIPTION
    This script iterates through all ZIP files in the 'VPinMAME\roms' directory,
    extracts their CRC-32 checksums using unzip.exe, and outputs the details as
    PowerShell custom objects.

.EXAMPLE
    ./Get-VPinMameRomsCrc.ps1 | Where-Object CRC -eq 'e4e66c9f' | Select-Object FileName,Name,Size
#>
foreach ($rom in (Get-ChildItem -File 'VPinMAME\roms\*.zip')) {
    foreach ($line in (& unzip.exe -v $rom)) {
        Write-Progress -Activity "Processing ROMs" -Status "Processing $($rom.Name)"
        $out = $line
        if ($out -match '^\s*(?<Length>\d+)\s+(?<Method>\S+)\s+(?<Size>\d+)\s+(?<Cmpr>\d+)%\s+(?<Date>\d{2}\/\d{2}\/\d{4})\s+(?<Time>\d{2}:\d{2})\s+(?<CRC>[0-9a-fA-F]{8})\s+(?<Name>\S+)') {
            [PSCustomObject]@{
                FileName = $rom.Name
                Length = $matches['Length']
                Method = $matches['Method']
                Size   = $matches['Size']
                Cmpr   = $matches['Cmpr']
                Date   = $matches['Date']
                Time   = $matches['Time']
                CRC    = $matches['CRC']
                Name   = $matches['Name']
            }
        }
    }
}
