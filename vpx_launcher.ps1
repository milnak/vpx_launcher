[CmdletBinding()]
Param(
    [string]$PinballExe = 'VPinballX64.exe',
    [string]$TablePath = 'Tables',
    [string]$Database = 'vpx_launcher.csv'
)

$launcherVersion = '1.0'

#  ___             _            ___
# |_ _|_ ___ _____| |_____ ___ / __|__ _ _ __  ___
#  | || ' \ V / _ \ / / -_)___| (_ / _` | '  \/ -_)
# |___|_||_\_/\___/_\_\___|    \___\__,_|_|_|_\___|
#

function Invoke-Game {
    Param(
        [Parameter(Mandatory)][Windows.Forms.Button]$LaunchButton,
        [Parameter(Mandatory)][string]$PinballExe,
        [Parameter(Mandatory)][string]$TablePath
    )

    $prevText = $buttonLaunch.Text
    $buttonLaunch.Enabled = $false
    $buttonLaunch.Text = 'Running'

    Write-Verbose "Launching: $tablePath"
    $proc = Start-Process -FilePath $PinballExe -ArgumentList '-ExtMinimized', '-Play', ('"{0}"' -f $TablePath) -NoNewWindow -PassThru

    # Games take a while to load, so show a fake progress bar.
    for ($i = 0; $i -le $progressBar.Maximum - $progressBar.Minimum; $i++) {
        $progressBar.Value = $i
        Start-Sleep -Milliseconds 500
    }

    Write-Verbose 'Waiting for VPX to exit'
    $proc.WaitForExit()

    $progressBar.Value = 0

    $buttonLaunch.Enabled = $true
    $buttonLaunch.Text = $prevText
}

#  ___             _           ___  _      _
# |_ _|_ ___ _____| |_____ ___|   \(_)__ _| |___  __ _
#  | || ' \ V / _ \ / / -_)___| |) | / _` | / _ \/ _` |
# |___|_||_\_/\___/_\_\___|   |___/|_\__,_|_\___/\__, |
#                                                |___/

function Invoke-Dialog {
    Param($Data)

    $script:listViewSort = @{
        Column     = 0
        Descending = $false
    }

    Add-Type -AssemblyName 'System.Windows.Forms'

    $form = New-Object -TypeName 'Windows.Forms.Form'

    ### LIST PANEL

    $panelListView = New-Object -TypeName 'Windows.Forms.Panel'
    $panelListView.Dock = [Windows.Forms.DockStyle]::Top
    $panelListView.Height = 450
    $panelListView.Width = 300
    $listView = New-Object -TypeName 'Windows.Forms.ListView'
    $listView.Dock = [Windows.Forms.DockStyle]::Fill
    $listView.FullRowSelect = $true
    $listView.MultiSelect = $false
    $listView.View = [Windows.Forms.View]::Details
    $listView.Font = New-Object  System.Drawing.Font('Consolas', 11, [Drawing.FontStyle]::Regular)
    $listView.Columns.Add('Table', 375) | Out-Null
    $listView.Columns.Add('Manufact.', 125) | Out-Null
    $listView.Columns.Add('Year', 50) | Out-Null
    $panelListView.Controls.Add($listView)

    foreach ($item in $Data) {
        $listItem = New-Object -TypeName 'Windows.Forms.ListViewItem'
        $listItem.Text = $item.Table
        $listItem.Tag = $item.Filename
        $listItem.SubItems.Add($item.Manufacturer) | Out-Null
        $listItem.SubItems.Add($item.Year) | Out-Null
        $listView.Items.Add($listItem) | Out-Null
    }

    $listView.Items[0].Selected = $true

    $listView.add_SelectedIndexChanged({
            if ($listView.SelectedItems.Count -gt 0) {
                $label1.Text = $listView.SelectedItems.Tag
            }
        })

    $listView.add_ColumnClick({
            $column = $_.Column
            $items = $this.Items | ForEach-Object { $_ }
            if ($column -ne $script:listViewSort.Column) {
                # Column change, always start with ascending sort
                $script:listViewSort.Column = $column
                $script:listViewSort.Descending = $false
            }
            else {
                $script:listViewSort.Descending = !$script:listViewSort.Descending
            }
            $this.Items.Clear()
            $this.ShowGroups = $false
            $this.Sorting = 'none'

            $this.Items.AddRange(
                ($items | Sort-Object -Descending:$script:listViewSort.Descending -Property @{ Expression = { $_.SubItems[$script:listViewSort.Column].Text } } )
            )

        })

    $listView.add_MouseDoubleClick(
        {
            # $_ : Windows.Forms.MouseEventArgs
            $tablePath = Join-Path $TablePath $listView.SelectedItems.Tag

            Invoke-Game -LaunchButton $buttonLaunch -PinballExe $PinballExe -TablePath $tablePath
        }
    )

    ### STATUS PANEL

    $panelStatus = New-Object -TypeName 'Windows.Forms.Panel'
    $panelStatus.Dock = [Windows.Forms.DockStyle]::Bottom
    $panelStatus.Height = 111
    $panelStatus.BackColor = [Drawing.Color]::FromArgb(115, 118, 255)
    $panelStatus.ForeColor = [Drawing.Color]::FromArgb(239, 244, 255)

    $label1 = New-Object -TypeName 'Windows.Forms.Label'
    $label1.Text = ''
    $label1.Font = New-Object  System.Drawing.Font('Segoe UI', 16, [Drawing.FontStyle]::Bold)
    $label1.Left = 5
    $label1.Width = 440
    $label1.Height = 30
    $label1.AutoSize = $false
    $panelStatus.Controls.Add($label1)

    $label2 = New-Object -TypeName 'Windows.Forms.Label'
    $label2.Text = ('{0} Machines' -f $listView.Items.Count)
    $label2.Left = 7
    $label2.Top = 35
    $label1.Width = 440
    $label2.AutoSize = $false
    $panelStatus.Controls.Add($label2)

    $progressBar = New-Object -TypeName 'Windows.Forms.ProgressBar'
    $progressBar.Top = 70
    $progressBar.Left = 10
    $progressBar.Width = 560
    $progressBar.Height = 20
    $progressBar.Minimum = 0
    $progressBar.Maximum = 9
    $progressBar.Value = 0
    $panelStatus.Controls.Add($progressBar)

    $buttonLaunch = New-Object -TypeName 'Windows.Forms.Button'
    $buttonLaunch.Location = New-Object -TypeName 'Drawing.Size' -ArgumentList 453, 15
    $buttonLaunch.Size = New-Object -TypeName 'Drawing.Size' -ArgumentList 118, 40
    $buttonLaunch.Text = 'Launch'
    $buttonLaunch.BackColor = [Drawing.Color]::FromArgb(216, 218, 254)
    $buttonLaunch.ForeColor = [Drawing.Color]::FromArgb(72, 78, 150)
    $panelStatus.Controls.Add($buttonLaunch)

    $buttonLaunch.Add_Click(
        {
            $tablePath = Join-Path $TablePath $listView.SelectedItems.Tag

            Invoke-Game -LaunchButton $buttonLaunch -PinballExe $PinballExe -TablePath $tablePath

            # $form.DialogResult = [Windows.Forms.DialogResult]::OK
            # $form.Close() | Out-Null
            # $form.Dispose() | Out-Null
        }
    )

    ### FORM MAIN

    $form.Controls.Add($panelStatus)
    $form.Controls.Add($panelListView)

    $form.Add_Activated({ $listView.Select() })

    $form.Text = ('VPX Launcher v{0}' -f $launcherVersion)
    $form.Width = 600
    $form.Height = 600
    $form.FormBorderStyle = [Windows.Forms.FormBorderStyle]::FixedSingle
    $form.AcceptButton = $buttonLaunch
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false

    $form.ShowDialog()
}

#  ___             _     _  _ _    _                ___       _
# | _ \___ __ _ __| |___| || (_)__| |_ ___ _ _ _  _|   \ __ _| |_
# |   / -_) _` / _` |___| __ | (_-<  _/ _ \ '_| || | |) / _` |  _|
# |_|_\___\__,_\__,_|   |_||_|_/__/\__\___/_|  \_, |___/\__,_|\__|
#                                              |__/

function Read-HistoryDat {
    param (
        [Parameter(Mandatory)][string]$DatabasePath
    )

    $roms = $null
    $readingBio = $false
    [string[]]$bio = $null

    # History.DAT file is optional.
    foreach ($line in (Get-Content -ErrorAction SilentlyContinue -LiteralPath $DatabasePath)) {
        if ($line.Length -ge 6 -and $line.Substring(0, 6) -eq '$info=') {
            $roms = $line.Substring(6).TrimEnd(',') -split ','
        }
        elseif ($line.Length -ge 4 -and $line.Substring(0, 4) -eq '$bio') {
            $bio = $null
            $readingBio = $true
        }
        elseif ($line.Length -ge 4 -and $line.SubString(0, 4) -eq '$end') {
            foreach ($rom in $roms) {
                [PSCustomObject]@{
                    ROM = $rom
                    Bio = $bio
                }
            }
            $readingBio = $false
            $bio = $null
        }
        elseif ($readingBio) {
            $bio += $line
        }
    }
}

#  ___             _     ___       _        _
# | _ \___ __ _ __| |___|   \ __ _| |_ __ _| |__  __ _ ___ ___
# |   / -_) _` / _` |___| |) / _` |  _/ _` | '_ \/ _` (_-</ -_)
# |_|_\___\__,_\__,_|   |___/\__,_|\__\__,_|_.__/\__,_/__/\___|
#

function Read-Database {
    param (
        [string]$DatabasePath,
        [string]$RomPath
    )

    $totalSize = 0
    $tableData = $null
    if (![string]::IsNullOrEmpty($DatabasePath)) {
        Get-Item -LiteralPath $DatabasePath -ErrorAction Stop | Out-Null

        $tableData = Get-Content -LiteralPath $DatabasePath `
        | ConvertFrom-Csv -Header 'Filename', 'Table', 'Manufacturer', 'Year', 'ROM' `
        | Sort-Object -Unique Filename
    }

    $data = foreach ($item in (Get-ChildItem -File -LiteralPath $TablePath -Include '*.vpx')) {
        $baseName = $item.BaseName
        $found = $tableData | Where-Object Filename -eq $baseName

        $totalSize += $item.Length

        if (!$found) {
            # Use regex to try to guess table, manufacturer and year from filename.
            if ($baseName -match '(.+)[ _]\((.+) (\d{4})\)') {
                [PSCustomObject]@{
                    Filename     = $item.Name
                    Table        = $matches[1]
                    Manufacturer = $matches[2]
                    Year         = $matches[3]
                }
                Write-Warning ('Not found in database: "{0}","{1}","{2}","{3}",""' -f $item.BaseName, $matches[1], $matches[2], $matches[3])
            }
            else {
                [PSCustomObject]@{
                    Filename     = $item.Name
                    Table        = $baseName
                    Manufacturer = '?'
                    Year         = '?'
                }
                Write-Warning ('Not found in database: "{0}"' -f $baseName)
            }
        }
        else {
            # Found in database.
            if ([string]::IsNullOrEmpty($found.ROM)) {
                # No ROM needed
                if ([int]$found.Year -gt 1977) {
                    # Machines after 1977 likely require a ROM.
                    Write-Warning ('Database claims table "{0}" has no ROM?' -f $baseName)
                }
            }
            elseif (![string]::IsNullOrEmpty($RomPath)) {
                # If $RomPath specified, check to see if the rom file exists.
                $rom = $found.ROM + '.zip'
                $romItem = Get-Item -ErrorAction SilentlyContinue -LiteralPath (Join-Path $RomPath $rom)
                if (!$romItem) {
                    Write-Warning ('Table "{0}" ROM "{1}" not found' -f $baseName, $rom)
                }
                else {
                    # ROM found
                    $totalSize += $romItem.Size
                }
            }

            [PSCustomObject]@{
                Filename     = $item.Name
                Table        = $found.Table
                Manufacturer = $found.Manufacturer
                Year         = $found.Year
            }
        }
    }

    Write-Verbose 'Sorting database'
    # Remove sort by table name
    $data.GetEnumerator() | Sort-Object -Unique Table

    Write-Verbose ('Table and ROM size: {0:N0} bytes' -f $totalSize)
}

#  __  __      _
# |  \/  |__ _(_)_ _
# | |\/| / _` | | ' \
# |_|  |_\__,_|_|_||_|
#

# Verify paths. Database path is optional.
Get-Item -ErrorAction Stop -LiteralPath $PinballExe | Out-Null
Get-Item -ErrorAction Stop -LiteralPath $TablePath | Out-Null

# Try to read VPinMAME ROM path from registry.
$RomPath = (Get-ItemProperty -ErrorAction SilentlyContinue -LiteralPath 'HKCU:\Software\Freeware\Visual PinMame\globals').rompath

# Read in database

$tables = Read-Database -DatabasePath $Database -RomPath $RomPath
if ($tables.Count -eq 0) {
    Write-Warning "No tables found in $TablePath"
    return
}

# TODO: Display VPinMAME ROM history in a text window.
# $historyDat = (Get-ItemProperty -ErrorAction SilentlyContinue -LiteralPath 'HKCU:\Software\Freeware\Visual PinMame\globals').history_file
# $history = Read-HistoryDat -DatabasePath $historyDat
# Write-Host -ForegroundColor Red "'$($found.Table)' Bio:"
# ($history | Where-Object ROM -eq $found.ROM).Bio | ForEach-Object { Write-Host -ForegroundColor DarkCyan $_ }

if ((Invoke-Dialog -Data $tables) -eq [Windows.Forms.DialogResult]::OK) {
}
