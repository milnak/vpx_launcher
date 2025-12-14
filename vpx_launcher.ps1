[CmdletBinding()]
Param(
    # Location to the VPinball EXE
    [string]$PinballExe = (Resolve-Path 'VPinballX64.exe'),
    # Folder containing VPX tables
    [string]$TablePath = (Resolve-Path 'Tables'),
    # Zero-based display number to use. Find numbers in Settings > System > Display
    [int]$Display = -1
)

$script:launcherVersion = '1.5'

$script:colorScheme = @{
    # "Ubuntu Custom"
    ListView_BackColor     = [Drawing.Color]::FromArgb(94, 92, 100) # Dark Gray
    ListView_ForeColor     = [Drawing.Color]::FromArgb(255, 255, 255) # White
    PanelStatus_BackColor  = [Drawing.Color]::FromArgb(23, 20, 33) # Very Dark Purple
    PanelStatus_ForeColor  = [Drawing.Color]::FromArgb(162, 115, 76) # Light Brown
    ProgressBar_BackColor  = [Drawing.Color]::FromArgb(23, 20, 33) # Very Dark Purple
    ProgressBar_ForeColor  = [Drawing.Color]::FromArgb(51, 218, 122) # Light Green
    ButtonLaunch_BackColor = [Drawing.Color]::FromArgb(18, 72, 139) # Dark Blue
    ButtonLaunch_ForeColor = [Drawing.Color]::FromArgb(208, 207, 204) # Light Gray
}

$script:metadataCache = @{}
$script:launchCount = @{}

# =============================================================================
# Write-IncrementedLaunchCount

function Write-IncrementedLaunchCount {
    param ([Parameter(Mandatory)][string]$FileName)

    $count = 1

    if ($script:launchCount.Contains($FileName)) {
        $count = $script:launchCount[$FileName] += 1
    }
    else {
        $script:launchCount.Add($FileName, 1)
    }

    $count
}

#######################################################################################################################

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
        if ($win32::FindWindow('VPinball', 'Visual Pinball') -ne 0) {
            # Visual Pinball exited immediately. maybe a game crashed or it started quickly.
            break
        }
    }

    Write-Verbose 'Waiting for VPX to exit'
    $proc.WaitForExit()

    $progressBar.Value = 0

    $buttonLaunch.Enabled = $true
    $buttonLaunch.Text = $prevText

    $baseName = [IO.Path]::GetFileNameWithoutExtension((Split-Path -Path $TablePath -Leaf).ToLower())
    $count = Write-IncrementedLaunchCount -FileName $baseName

    # Update listview play count
    $listView.SelectedItems[0].SubItems[4].Text = $count

    # Remove this file that's left over after running a game.
    $tableFolder = Split-Path -Parent $TablePath
    Remove-Item "$tableFolder/altsound.log" -ErrorAction SilentlyContinue

    if (Test-Path "$tableFolder/crash.dmp" -PathType Leaf ) {
        Write-Host -ForegroundColor Red "Table '$baseName' crashed!"
        Remove-Item "$tableFolder/crash.dmp" -ErrorAction SilentlyContinue
        Remove-Item "$tableFolder/crash.txt" -ErrorAction SilentlyContinue
    }

    Write-Verbose ('VPX (filename: {0}) exited' -f $filename)
}

# =============================================================================
# Invoke-ListRefresh

function Invoke-ListRefresh {
    param(
        [Parameter(Mandatory)][string]$TablePath,
        [Parameter(Mandatory)][object]$listView
    )

    $selectedItemText = $null
    if ($listView.SelectedItems.Count -eq 1) {
        $selectedItemText = $listView.SelectedItems.Text
    }

    $listView.Items.Clear()

    # Read in Read-VpxFileMetadatadatabase
    $vpxFiles = (Get-ChildItem -Recurse -Depth 1 -File -LiteralPath $TablePath -Include '*.vpx').FullName
    $tables = Read-VpxFileMetadata -VpxFiles $vpxFiles
    if ($tables.Count -eq 0) {
        Write-Warning "No tables found in $TablePath"
        return
    }

    foreach ($table in $tables) {
        $listItem = New-Object -TypeName 'Windows.Forms.ListViewItem'
        $listItem.Text = $table.Table
        $listItem.Tag = $table.FileName
        $listItem.SubItems.Add($table.Manufacturer) | Out-Null
        $listItem.SubItems.Add($table.Year) | Out-Null
        $listItem.SubItems.Add($table.Details) | Out-Null ## TESTX
        $launchCount = $script:launchCount[[IO.Path]::GetFileNameWithoutExtension($listItem.Tag)]
        if (!$launchCount) { $launchCount = '0' }
        $listItem.SubItems.Add($launchCount) | Out-Null

        $listView.Items.Add($listItem) | Out-Null
    }


    $listView.Refresh()
    $listView.Focus()

    if ($listView.Items.Count -ne 0) {
        if ($selectedItemText) {
            $found = $listView.FindItemWithText($selectedItemText)
            if ($found) {
                $listView.EnsureVisible($found.Index)
                $found.Selected = $true
            }
            else {
                $listView.Items[0].Selected = $true
            }
        }
        else {
            $listView.Items[0].Selected = $true
        }
    }
}

# =============================================================================
# Invoke-MainWindow

function Invoke-MainWindow {
    param (
        [Parameter(Mandatory)][string]$TablePath
    )

    Write-Verbose "Using table path $TablePath"

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
    # $panelListView.Width = 500

    $listView = New-Object -TypeName 'Windows.Forms.ListView'
    $listView.Dock = [Windows.Forms.DockStyle]::Fill
    $listView.BorderStyle = [Windows.Forms.BorderStyle]::FixedSingle
    $listView.FullRowSelect = $true
    $listView.MultiSelect = $false
    $listView.View = [Windows.Forms.View]::Details
    $listView.Font = New-Object  System.Drawing.Font('Calibri', 12, [Drawing.FontStyle]::Regular)
    $listView.BackColor = $script:colorScheme.ListView_BackColor
    $listView.ForeColor = $script:colorScheme.ListView_ForeColor


    $listView.Columns.Add('Table', 200) | Out-Null
    $listView.Columns.Add('Manufact.', 130) | Out-Null
    $listView.Columns.Add('Year', 53) | Out-Null
    $listView.Columns.Add('Details', 130) | Out-Null
    $listView.Columns.Add('Play', 50) | Out-Null

    $panelListView.Controls.Add($listView)

    Invoke-ListRefresh -TablePath $TablePath -ListView $listView

    $listView.add_SelectedIndexChanged({
            if ($listView.SelectedItems.Count -eq 1) {
                $filename = $listView.SelectedItems.Tag

                # Update metadata
                $meta = $script:metadataCache[$filename]

                if (-not $meta) {
                    $meta = @{
                        TableName    = $listView.SelectedItems.Text
                        TableVersion = $listView.SelectedItems.SubItems[2].Text
                        Details      = ''
                        AuthorName   = $listView.SelectedItems.SubItems[1].Text
                    }
                    $script:metadataCache[$filename] = $meta
                }

                $label1.Text = $meta.TableName
                $text = $null
                if ($meta.TableVersion) {
                    $text += "$($meta.TableVersion) "
                }
                if ($meta.AuthorName) {
                    $text += "by $($meta.AuthorName)"
                }
                if ($meta.Details) {
                    $text += " - $($meta.Details) "
                }
                $label2.Text = $text
            }
        })

    $listView.add_ColumnClick({
            $column = $_.Column
            if ($column -ne $script:listViewSort.Column) {
                # Column change, always start with ascending sort
                $script:listViewSort.Column = $column
                $script:listViewSort.Descending = $false
            }
            else {
                $script:listViewSort.Descending = !$script:listViewSort.Descending
            }

            # https://learn.microsoft.com/en-us/dotnet/api/system.windows.forms.listviewitem?view=windowsdesktop-9.0
            # Make deep copy of Items and sort

            if ($script:listViewSort.Column -eq 1) {
                # When sorting by Manufacturer, also sort by year
                $items = $this.Items `
                | ForEach-Object { $_ } `
                | Sort-Object -Descending:$script:listViewSort.Descending  -Property `
                @{Expression = { $_.SubItems[$script:listViewSort.Column].Text } }, @{Expression = { $_.SubItems[2].Text } }
            }

            else {
                $items = $this.Items `
                | ForEach-Object { $_ } `
                | Sort-Object -Descending:$script:listViewSort.Descending -Property @{
                    Expression = { $_.SubItems[$script:listViewSort.Column].Text }
                }
            }

            $this.Items.Clear()
            $this.ShowGroups = $false
            $this.Sorting = 'none'

            $items | ForEach-Object { $this.Items.Add($_) }
        })

    $listView.add_MouseDoubleClick(
        {
            # $_ : Windows.Forms.MouseEventArgs
            # $tablePath = Join-Path $TablePath $listView.SelectedItems.Tag
            $tablePath = $listView.SelectedItems.Tag

            Invoke-Game -LaunchButton $buttonLaunch -PinballExe $PinballExe -TablePath $tablePath
        }
    )

    $form.KeyPreview = $true

    $listView.Add_KeyDown({
            # $_ : Windows.Forms.KeyEventArgs
            if ($_.KeyCode -eq 'F5') {
                Write-Verbose 'F5 pressed. Refreshing.'
                Invoke-ListRefresh -TablePath $TablePath -listView $listView
                $_.Handled = $true
            }
        })

    $listView.Add_KeyUp({
            if ($_.Control -and $_.KeyCode -eq 'C') {
                Write-Verbose 'Ctrl-C pressed. Copying.'

                # TODO: Create global defines for column names / indices
                #   text = table, 1 = manuf, 2 = year, 3 = details, 4 = play
                '{0} ({1} {2}) {3}' -f `
                    $listView.SelectedItems.Text, `
                    $listView.SelectedItems.SubItems[1].Text, `
                    $listView.SelectedItems.SubItems[2].Text, `
                    $listView.SelectedItems.SubItems[3].Text `
                | Set-Clipboard

                $_.Handled = $true
            }
        }
    )

    ### STATUS PANEL

    $panelStatus = New-Object -TypeName 'Windows.Forms.Panel'
    $panelStatus.Dock = [Windows.Forms.DockStyle]::Bottom
    $panelStatus.Height = 111
    $panelStatus.BackColor = $script:colorScheme.PanelStatus_BackColor
    $panelStatus.ForeColor = $script:colorScheme.PanelStatus_ForeColor

    $label1 = New-Object -TypeName 'Windows.Forms.Label'
    $label1.Text = ''
    $label1.Font = New-Object  System.Drawing.Font('Segoe UI', 16, [Drawing.FontStyle]::Bold)
    $label1.Left = 5
    $label1.Top = 4
    $label1.Width = 440
    $label1.Height = 30
    $label1.AutoSize = $false
    $label1.AutoEllipsis = $true
    $panelStatus.Controls.Add($label1)

    $label2 = New-Object -TypeName 'Windows.Forms.Label'
    $label2.Text = ''
    $label2.Left = 7
    $label2.Top = 37
    $label2.Height = 20
    $label2.Width = 400
    $label2.AutoSize = $false
    $label2.AutoEllipsis = $true
    $panelStatus.Controls.Add($label2)

    $progressBar = New-Object -TypeName 'Windows.Forms.ProgressBar'
    $progressBar.Top = 70
    $progressBar.Left = 10
    $progressBar.Width = 561
    $progressBar.Height = 20
    $progressBar.Minimum = 0
    $progressBar.Maximum = 9
    $progressBar.Value = 0
    $progressBar.BackColor = $script:colorScheme.ProgressBar_BackColor
    $progressBar.ForeColor = $script:colorScheme.ProgressBar_ForeColor
    $progressBar.Style = [Windows.Forms.ProgressBarStyle]::Continuous

    $panelStatus.Controls.Add($progressBar)

    $buttonLaunch = New-Object -TypeName 'Windows.Forms.Button'
    $buttonLaunch.Location = New-Object -TypeName 'Drawing.Size' -ArgumentList 453, 15
    $buttonLaunch.Size = New-Object -TypeName 'Drawing.Size' -ArgumentList 118, 40
    $buttonLaunch.Text = 'Launch'

    $buttonLaunch.BackColor = $script:colorScheme.ButtonLaunch_BackColor
    $buttonLaunch.ForeColor = $script:colorScheme.ButtonLaunch_ForeColor
    $buttonLaunch.FlatStyle = [Windows.Forms.FlatStyle]::Flat
    $buttonLaunch.FlatAppearance.BorderColor = [Drawing.Color]::FromArgb(61, 142, 167)
    $buttonLaunch.FlatAppearance.BorderSize = 1;
    $panelStatus.Controls.Add($buttonLaunch)

    $buttonLaunch.Add_Click(
        {
            # $tablePath = Join-Path $TablePath $listView.SelectedItems.Tag
            $tablePath = $listView.SelectedItems.Tag

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

    $form.Text = ('VPX Launcher v{0}' -f $script:launcherVersion)
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

# =============================================================================
# ConvertTo-AppendedArticle

function ConvertTo-AppendedArticle {
    param ([Parameter(Mandatory)][string]$String)

    'the', 'a', 'an' | ForEach-Object {
        if ($String -like "$_ *") {
            '{0}, {1}' -f $String.SubString($_.Length + 1), $String.SubString(0, $_.Length)
            return
        }
    }

    $String
}

# =============================================================================
# Read-VpxFileMetadata

function Read-VpxFileMetadata {
    param (
        [string[]]$VpxFiles
    )

    if ($VpxFiles.Count -eq 0) {
        return @()
    }

    $data = foreach ($vpxFile in $VpxFiles) {
        Write-Verbose "Parsing filename: $vpxFile"
        $baseName = [IO.Path]::GetFileNameWithoutExtension($vpxFile)

        # Use regex to try to guess table, manufacturer and year from filename.
        if ($baseName -match '(.+)[ _]?\((.+)(\d{4})\)\s*(.*)') {
            [PSCustomObject]@{
                FileName     = $vpxFile
                Table        = ConvertTo-AppendedArticle -String $matches[1].Trim()
                Manufacturer = $matches[2].Trim()
                Year         = $matches[3].Trim()
                Details      = $matches[4].Trim()
            }
        }
        else {
            [PSCustomObject]@{
                FileName     = $vpxFile
                Table        = $baseName
                Manufacturer = ''
                Year         = ''
                Details      = ''
            }
            Write-Warning ('Unable to parse filename "{0}"' -f $baseName)
        }
    }

    # Note: Not using -Unique so that each folder can have .VPX variants.
    $data.GetEnumerator() | Sort-Object Table
}

#  __  __      _
# |  \/  |__ _(_)_ _
# | |\/| / _` | | ' \
# |_|  |_\__,_|_|_||_|
#

$win32 = Add-Type -Namespace Win32  -MemberDefinition @'
    [DllImport("user32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
    public static extern IntPtr FindWindow(string className, string windowName);

    [DllImport("kernel32.dll")]
    public static extern uint GetLastError();
'@ -Name 'Funcs' -PassThru


# Note: can't just search for class name. Window title must be specified.
if ($win32::FindWindow('VPinball', 'Visual Pinball') -ne 0) {
    Write-Warning 'Visual Pinball should be closed before running this launcher.'
    return
}


# Verify paths.
Get-Item -ErrorAction Stop -LiteralPath $PinballExe | Out-Null
Get-Item -ErrorAction Stop -LiteralPath $TablePath | Out-Null

if ($Display -ne -1) {
    # Change display in INI file.
    $vpxIni = Resolve-Path -LiteralPath "$env:AppData\vpinballx\VPinballX.ini"
    $iniData = Get-Content -LiteralPath $vpxIni -ErrorAction Stop
    $iniData -replace 'Display = \d+', ('Display = {0}' -f $Display) | Out-File -LiteralPath $vpxIni -Encoding ascii
}


$cfgPath = Join-Path -Path $env:LocalAppData -ChildPath 'vpx_launcher.json'

# Read in configuration
Write-Verbose "Reading config from $cfgPath"
if (Test-Path -LiteralPath $cfgPath -PathType Leaf) {
    $cfg = Get-Content $cfgPath | ConvertFrom-Json
    # Convert JSON to hash
    foreach ($p in $cfg.LaunchCount.PSObject.Properties) { $script:launchCount[$p.Name] = $p.Value }
}

# TODO: Display VPinMAME ROM history in a text window.
# $vpmRegistry = Get-ItemProperty -ErrorAction SilentlyContinue -LiteralPath 'HKCU:\Software\Freeware\Visual PinMame\globals'
# $historyDat = $vpmRegistry.history_file
# $history = Read-HistoryDat -DatabasePath $historyDat
# Write-Host -ForegroundColor Red "'$($found.Table)' Bio:"
# ($history | Where-Object ROM -eq $found.ROM).Bio | ForEach-Object { Write-Host -ForegroundColor DarkCyan $_ }

Invoke-MainWindow -TablePath $TablePath | Out-Null

# Write out configuration
Write-Verbose "Writing config to $cfgPath"
@{
    LaunchCount = $script:launchCount
} | ConvertTo-Json | Out-File $cfgPath
