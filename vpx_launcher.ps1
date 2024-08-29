Param(
    [string]$TablePath = 'D:\Visual Pinball\Tables',
    [string]$RomPath = 'D:\Visual Pinball\VPinMAME\roms',
    [string]$ExePath = 'D:\Visual Pinball\VPinballX64.exe'
)

function Invoke-Dialog {
    Param($Data)

    $script:selectedItem = $null
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
    $listView.Columns.Add('Table', 400) | Out-Null
    $listView.Columns.Add('Manufact.', 100) | Out-Null
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
                $script:selectedItem = $listView.SelectedItems.Tag + '.vpx'

                $label1.Text = $listView.SelectedItems.Text
                $label2.Text = $listView.SelectedItems.Tag
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

    ### STATUS PANEL

    $panelStatus = New-Object -TypeName 'Windows.Forms.Panel'
    $panelStatus.Dock = [Windows.Forms.DockStyle]::Bottom
    $panelStatus.Height = 100
    $panelStatus.Width = 300

    $label1 = New-Object -TypeName 'Windows.Forms.Label'
    $label1.Text = ''
    $label1.Font = New-Object  System.Drawing.Font('Segoe UI', 16, [Drawing.FontStyle]::Bold)
    $label1.Location = New-Object -TypeName 'Drawing.Point' -ArgumentList 0, 0
    $label1.AutoSize = $true
    $panelStatus.Controls.Add($label1)

    $label2 = New-Object -TypeName 'Windows.Forms.Label'
    $label2.Text = ""
    $label2.Location = New-Object -TypeName 'Drawing.Point' -ArgumentList 3, 40
    $label2.AutoSize = $true
    $panelStatus.Controls.Add($label2)

    $buttonLaunch = New-Object -TypeName 'Windows.Forms.Button'
    $buttonLaunch.Location = New-Object -TypeName 'Drawing.Size' -ArgumentList 450, 0
    $buttonLaunch.Size = New-Object -TypeName 'Drawing.Size' -ArgumentList 120, 40
    $buttonLaunch.Text = 'Launch'
    $panelStatus.Controls.Add($buttonLaunch)

    $buttonLaunch.Add_Click(
        {
            $item = Join-Path $TablePath $script:selectedItem

            $prevText = $buttonLaunch.Text
            $buttonLaunch.Enabled = $false
            $buttonLaunch.Text = 'Running'

            Start-Process -FilePath $ExePath -ArgumentList '-ExtMinimized', '-Play', ('"{0}"' -f $item) -NoNewWindow -Wait

            $buttonLaunch.Enabled = $true
            $buttonLaunch.Text = $prevText

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
    $form.ShowDialog()
}

$tableData = Get-Content -LiteralPath 'tables.csv' | ConvertFrom-Csv -Header 'Filename', 'Table', 'Manufacturer', 'Year', 'ROM'
$tables = foreach ($item in (Get-ChildItem -File -LiteralPath $TablePath -Include '*.vpx')) {
    $name = $item.BaseName
    $found = $tableData | Where-Object Filename -eq $name

    if (!$found) {
        Write-Warning ('Table not found: "{0}"' -f $name)
    }
    else {
        if ($found.ROM.Length -eq 0) {
            # No ROM needed
            $found
        }
        else {
            $rom = $found.ROM + '.zip'
            if (!(Get-Item -ErrorAction SilentlyContinue -LiteralPath (Join-Path $RomPath $rom))) {
                Write-Warning ('Table "{0}" ROM "{1}" not found' -f $name, $rom)
            }
            else {
                # ROM found
                $found
            }
        }
    }
}

if ($tables.Count -eq 0) {
    Write-Warning "No tables found in $TablePath"
    return
}

if ((Invoke-Dialog -Data $tables) -eq [Windows.Forms.DialogResult]::OK) {
}
