[CmdletBinding()]
Param(
    [string]$PinballExe = 'VPinballX64.exe',
    [string]$TablePath = 'Tables',
    [string]$RomPath = 'VPinMAME\roms',
    [string]$Database = 'vpx_launcher.csv'
)

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
    Start-Process -FilePath $PinballExe -ArgumentList '-ExtMinimized', '-Play', ('"{0}"' -f $TablePath) -NoNewWindow -Wait

    $buttonLaunch.Enabled = $true
    $buttonLaunch.Text = $prevText
}

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
    $panelStatus.Height = 100
    $panelStatus.Width = 300

    $label1 = New-Object -TypeName 'Windows.Forms.Label'
    $label1.Text = ''
    $label1.Font = New-Object  System.Drawing.Font('Segoe UI', 16, [Drawing.FontStyle]::Bold)
    $label1.Location = New-Object -TypeName 'Drawing.Point' -ArgumentList 0, 0
    $label1.Width = 440
    $label1.Height = 30
    $label1.AutoSize = $false
    $panelStatus.Controls.Add($label1)

    $label2 = New-Object -TypeName 'Windows.Forms.Label'
    $label2.Text = ('{0} Machines' -f $listView.Items.Count)
    $label2.Location = New-Object -TypeName 'Drawing.Point' -ArgumentList 3, 40
    $label1.Width = 440
    $label2.AutoSize = $false
    $panelStatus.Controls.Add($label2)

    $buttonLaunch = New-Object -TypeName 'Windows.Forms.Button'
    $buttonLaunch.Location = New-Object -TypeName 'Drawing.Size' -ArgumentList 450, 0
    $buttonLaunch.Size = New-Object -TypeName 'Drawing.Size' -ArgumentList 118, 40
    $buttonLaunch.Text = 'Launch'
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

    $form.Text = 'VPX Launcher'
    $form.Width = 600
    $form.Height = 600
    $form.FormBorderStyle = [Windows.Forms.FormBorderStyle]::FixedSingle
    $form.AcceptButton = $buttonLaunch
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false

    $form.ShowDialog()
}

function Read-Database {
    param (
        [string]$DatabasePath,
        [string]$RomPath
    )

    $totalSize = 0
    $tableData = $null
    if ($DatabasePath.Length -ne 0) {
        $tableData = Get-Content -LiteralPath $DatabasePath | ConvertFrom-Csv -Header 'Filename', 'Table', 'Manufacturer', 'Year', 'ROM'
    }

    $data = foreach ($item in (Get-ChildItem -File -LiteralPath $TablePath -Include '*.vpx')) {
        $baseName = $item.BaseName
        $found = $tableData | Where-Object Filename -eq $baseName

        $totalSize += $item.Length

        if (!$found) {
            Write-Warning ('Table not found in database: "{0}"' -f $baseName)

            # Use regex to try to guess table, manufacturer and year from filename.
            if ($baseName -match '(.+)[ _]\((.+) (\d{4})\)') {
                [PSCustomObject]@{
                    Filename     = $item.Name
                    Table        = $matches[1]
                    Manufacturer = $matches[2]
                    Year         = $matches[3]
                }
            }
            else {
                [PSCustomObject]@{
                    Filename     = $item.Name
                    Table        = $baseName
                    Manufacturer = '?'
                    Year         = '?'
                }
            }
        }
        else {
            if ($found.ROM.Length -eq 0) {
                # No ROM needed
                if ([int]$found.Year -gt 1977) {
                    # Machines after 1977 likely require a ROM.
                    Write-Warning ('Database claims table "{0}" has no ROM?' -f $baseName)
                }
            }
            elseif ($RomPath.Length -ne 0) {
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

    # Return list sorted by table (friendly name).
    $data.GetEnumerator() | Sort-Object -Property Table

    Write-Verbose ('Table and ROM size: {0:N0} bytes' -f $totalSize)
}

# Verify paths. Database and RomPath are optional.

Get-Item -ErrorAction Stop -LiteralPath $PinballExe | Out-Null
Get-Item -ErrorAction Stop -LiteralPath $TablePath | Out-Null

# Read in database

$tables = Read-Database -DatabasePath $Database -RomPath $RomPath
if ($tables.Count -eq 0) {
    Write-Warning "No tables found in $TablePath"
    return
}

if ((Invoke-Dialog -Data $tables) -eq [Windows.Forms.DialogResult]::OK) {
}
