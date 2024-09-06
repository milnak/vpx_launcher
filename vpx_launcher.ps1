[CmdletBinding()]
Param(
    [string]$PinballExe = 'VPinballX64.exe',
    [string]$TablePath = 'Tables',
    [string]$Database = 'vpx_launcher.csv'
)

$launcherVersion = '1.1'

#######################################################################################################################
# Adapted from
# https://github.com/DBHeise/oless/blob/fd56c893fb48614cde656cd305e1eb554664ba25/oless/pole.cpp

#  ___ _               _                   _   ___ _
# / __| |_ _ _ _  _ __| |_ _  _ _ _ ___ __| | / __| |_ ___ _ _ __ _ __ _ ___
# \__ \  _| '_| || / _|  _| || | '_/ -_) _` | \__ \  _/ _ \ '_/ _` / _` / -_)
# |___/\__|_|  \_,_\__|\__|\_,_|_| \___\__,_| |___/\__\___/_| \__,_\__, \___|
#                                                                  |___/

# NOTE: Powershell method calls are slow! Avoid calling this in a loop.
function Read-U16 {
    Param([byte[]] $Buffer, $Offset)

    [uint32]$Buffer[$Offset + 0] `
        + (([uint32]$Buffer[$Offset + 1]) -shl 8)
}
# NOTE: Powershell method calls are slow! Avoid calling this in a loop.
function Read-U32 {
    Param([byte[]] $Buffer, [uint64]$Offset)

    [uint32]$Buffer[$Offset + 0] `
        + (([uint32]$Buffer[$Offset + 1]) -shl 8) `
        + (([uint32]$Buffer[$Offset + 2]) -shl 16) `
        + (([uint32]$Buffer[$Offset + 3]) -shl 24)
}

function SS-LoadBigBlocks {
    [CmdletBinding()]
    param ($Blocks)

    for ($i = 0; $i -lt $blocks.Length; $i++) {
        $block = $blocks[$i]
        $pos = $bbat.blockSize * ($block + 1)
        $fileStream.Seek($pos, [IO.SeekOrigin]::Begin) | Out-Null
        $fileReader.ReadBytes($bbat.blockSize)
    }
}

function SS-DebugAllocTable {
    Param([byte[]]$Buffer, [uint32]$Length)

    # AllocTable identifiers
    $MetaBat = [uint32]0xfffffffcL
    $Bat = [uint32]0xfffffffdL
    $Eof = [uint32]0xfffffffeL
    $Avail = [uint32]0xffffffffL

    Write-Verbose "Alloc Table length: $Length"
    for ($temp = 0; $temp -lt $Length; $temp++) {
        $e = Read-U32 -Buffer $Buffer -Offset ($temp * 4)
        if ($e -ne $Avail) {
            if ($e -eq $Eof) { $e = '[eof]' }
            elseif ($e -eq $Bat) { $e = '[bat]' }
            elseif ($e -eq $MetaBat) { $e = '[metabat]' }
            Write-Verbose ('{0}: {1}' -f $temp, $e)
        }
    }
}

function SS-Follow {
    Param(
        [byte[]]$Buffer,
        [uint32]$Count,
        [uint32]$P
    )

    # AllocTable identifiers
    $MetaBat = [uint32]0xfffffffcL
    $Bat = [uint32]0xfffffffdL
    $Eof = [uint32]0xfffffffeL

    $blocks = @()

    for ($i = 0; $i -lt $Count) {
        if ($P -in $Eof, $Bat, $MetaBat) { break }
        $blocks += $P

        # $P = Read-U32 -Buffer $Buffer -Offset ($P * 4)
        $offset = $P * 4
        $P = [uint32]$Buffer[$offset + 0] `
            + (([uint32]$Buffer[$offset + 1]) -shl 8) `
            + (([uint32]$Buffer[$offset + 2]) -shl 16) `
            + (([uint32]$Buffer[$offset + 3]) -shl 24)

    }

    $blocks
}

function Read-VpxMetadata {
    [CmdletBinding()]
    param ([Parameter(Mandatory)][string]$Path)

    ### StorageIO::load

    # https://learn.microsoft.com/en-us/dotnet/api/system.io.filestream?view=net-8.0
    $fileStream = New-Object -TypeName 'IO.FileStream' -ArgumentList ($Path, [System.IO.FileMode]::Open, [IO.FileAccess]::Read)
    # https://learn.microsoft.com/en-us/dotnet/api/system.io.binaryreader?view=net-8.0
    $fileReader = New-Object -TypeName 'IO.BinaryReader' -ArgumentList $fileStream

    #  ___             _   _  _             _
    # | _ \___ __ _ __| | | || |___ __ _ __| |___ _ _
    # |   / -_) _` / _` | | __ / -_) _` / _` / -_) '_|
    # |_|_\___\__,_\__,_| |_||_\___\__,_\__,_\___|_|
    #

    $buffer = $fileReader.ReadBytes(512)

    $header = @{
        # [1EH,02] size of sectors in power-of-two; typically 9 indicating 512-byte sectors and 12 for 4096
        b_shift      = Read-U16 -Buffer $buffer -Offset 0x1e
        # [20H,02] size of mini-sectors in power-of-two; typically 6 indicating 64-byte mini-sectors
        s_shift      = Read-U16 -Buffer $buffer -Offset 0x20
        # [2CH,04] number of SECTs in the FAT chain
        num_bat      = Read-U32 -Buffer $buffer -Offset 0x2c
        # [30H,04] first SECT in the directory chain
        dirent_start = Read-U32 -Buffer $buffer -Offset 0x30
        # [38H,04] maximum size for a mini stream; typically 4096 bytes
        threshold    = Read-U32 -Buffer $buffer -Offset 0x38
        # [3CH,04] first SECT in the MiniFAT chain
        sbat_start   = Read-U32 -Buffer $buffer -Offset 0x3c
        # [40H,04] number of SECTs in the MiniFAT chain
        num_sbat     = Read-U32 -Buffer $buffer -Offset 0x40
        # [44H,04] first SECT in the DIFAT chain
        mbat_start   = Read-U32 -Buffer $buffer -Offset 0x44
        # [48H,04] number of SECTs in the DIFAT chain
        num_mbat     = Read-U32 -Buffer $buffer -Offset 0x48
        # Signature
        id           = $buffer[0..7]
    }

    # [4CH,436] the SECTs of first 109 FAT sectors
    $header.bbat_blocks = @()
    for ($i = 0; $i -lt $header.num_bat; $i++ ) {
        # $p = Read-U32 -Buffer $buffer -Offset (0x4C + $i * 4)
        $Buffer = $buffer
        $Offset = 0x4C + $i * 4
        $p = [uint32]$Buffer[$Offset + 0] `
            + (([uint32]$Buffer[$Offset + 1]) -shl 8) `
            + (([uint32]$Buffer[$Offset + 2]) -shl 16) `
            + (([uint32]$Buffer[$Offset + 3]) -shl 24)

        $header.bbat_blocks += $p
    }

    Write-Verbose ("header{0}" -f ($header | Out-String))

    # sanity checks
    if ($header.threshold -ne 4096 `
            -or $header.num_bat -eq 0 `
            -or ($header.num_bat -lt 109 -and $header.num_mbat -ne 0) `
            -or $header.s_shift -gt $header.b_shift `
            -or $header.b_shift -le 6 `
            -or $header.b_shift -ge 31) {
        throw 'Sanity checks failed'
    }
    $pole_magic = 0xd0, 0xcf, 0x11, 0xe0, 0xa1, 0xb1, 0x1a, 0xe1
    if (Compare-Object -ReferenceObject $pole_magic -DifferenceObject $header.id) {
        throw 'Invalid signature'
    }

    # size of sectors, typically 9 indicating 512-byte sectors and 12 for 4096
    $bbat = @{
        blockSize = [Convert]::ToUint64(1) -shl $header.b_shift
    }
    $sbat = @{
        blockSize = [Convert]::ToUint64(1) -shl $header.s_shift
    }

    #  ___             _   ___ _        ___       _
    # | _ \___ __ _ __| | | _ |_)__ _  | _ ) __ _| |_
    # |   / -_) _` / _` | | _ \ / _` | | _ \/ _` |  _|
    # |_|_\___\__,_\__,_| |___/_\__, | |___/\__,_|\__|
    #                           |___/

    # NOTE: bbat.data is byte[], but should be treated as uint32[]
    $bbat.data = SS-LoadBigBlocks -Blocks $header.bbat_blocks
    $bbat.count = $bbat.data.Length / 4
    Write-Verbose ('bbat{0}' -f ($bbat | Out-String))

    # SS-DebugAllocTable -Buffer $bbat.data -Length $bbat.count

    #  ___             _   ___            _ _   ___       _
    # | _ \___ __ _ __| | / __|_ __  __ _| | | | _ ) __ _| |_
    # |   / -_) _` / _` | \__ \ '  \/ _` | | | | _ \/ _` |  _|
    # |_|_\___\__,_\__,_| |___/_|_|_\__,_|_|_| |___/\__,_|\__|
    #

    # bbat->SS-follow( header->sbat_start );
    $header.sbat_blocks = SS-Follow -Buffer $bbat.data -Count $bbat.count -P $header.sbat_start

    $sbat.data = SS-LoadBigBlocks -Blocks $header.sbat_blocks
    $sbat.count = $sbat.data.Length / 4

    # SS-DebugAllocTable -Buffer $sbat.data -Length $sbat.count

    #  ___             _   ___  _            _
    # | _ \___ __ _ __| | |   \(_)_ _ ___ __| |_ ___ _ _ _  _
    # |   / -_) _` / _` | | |) | | '_/ -_) _|  _/ _ \ '_| || |
    # |_|_\___\__,_\__,_| |___/|_|_| \___\__|\__\___/_|  \_, |
    #                                                    |__/

    Write-Verbose 'Start dirtree'
    $StartTime = Get-Date

    # bbat->SS-follow( header->dirent_start );
    $tree_blocks = SS-Follow -Buffer $bbat.data -Count $bbat.count -P $header.dirent_start

    $dirtree_blocks = SS-LoadBigBlocks -Blocks $tree_blocks
    $buflen = $tree_blocks.Length * $bbat.blockSize

    $dirtree = @()
    for ($i = 0; $i -lt $buflen / 128; $i++) {
        $p = $i * 128

        $type = $dirtree_blocks[$p + 0x40 + 0x02]
        if ($type -eq 0) {
            break
        }

        # $name_len = Read-U16 -Buffer $dirtree_blocks -Offset ($p + 0x40)
        $Buffer = $dirtree_blocks
        $Offset = $p + 0x40
        $name_len = [uint32]$Buffer[$Offset + 0] `
            + (([uint32]$Buffer[$Offset + 1]) -shl 8)
        if ($name_len -gt 0x40) { throw 'Invalid name_len' }

        $name = [Text.Encoding]::Unicode.GetString($dirtree_blocks[($p + $0)..($p + $name_len - 3)]) # REVIEW: Why -3?

        # Size  = Read-U32 -Buffer $dirtree_blocks -Offset ($p + 0x40 + 0x38)
        $Buffer = $dirtree_blocks
        $Offset = $p + 0x40 + 0x38
        $size = [uint32]$Buffer[$Offset + 0] `
            + (([uint32]$Buffer[$Offset + 1]) -shl 8) `
            + (([uint32]$Buffer[$Offset + 2]) -shl 16) `
            + (([uint32]$Buffer[$Offset + 3]) -shl 24)

        # Start = Read-U32 -Buffer $dirtree_blocks -Offset ($p + 0x40 + 0x34)
        $Buffer = $dirtree_blocks
        $Offset = $p + 0x40 + 0x34
        $start = [uint32]$Buffer[$Offset + 0] `
            + (([uint32]$Buffer[$Offset + 1]) -shl 8) `
            + (([uint32]$Buffer[$Offset + 2]) -shl 16) `
            + (([uint32]$Buffer[$Offset + 3]) -shl 24)

        $dirtree += @{
            Name  = $name
            Type  = $type
            Size  = $size
            Start = $start
            # Next  = Read-U32 -Buffer $dirtree_blocks -Offset ($p + 0x40 + 0x08)
            # Prev  = Read-U32 -Buffer $dirtree_blocks -Offset ($p + 0x40 + 0x04)
            # Child = Read-U32 -Buffer $dirtree_blocks -Offset ($p + 0x40 + 0x0c)
        }
    }
    Write-Verbose ('End dirtree {0}s' -f ((New-TimeSpan -Start $StartTime -End (Get-Date)).TotalSeconds))

    if ($VerbosePreference -eq 'Continue') {
        # DirTree identifiers
        # $End = [uint32]0xffffffffL

        for ($temp = 0; $temp -lt $dirtree.Length; $temp++) {
            $e = $dirtree[$temp]
            $t = ('0?', 'Dir', 'File', '3?', '4?', 'Root')[$e.Type]
            # if ($e.Prev -eq $End) { $p = '-' } else { $p = $e.Prev }
            # if ($e.Next -eq $End) { $n = '-' } else { $n = $e.Next }
            # Write-Verbose ('{0}: {1} ({2}) {3} s:{4} (- {5}:{6})' -f $temp, $e.Name, $t, $e.Size, $e.Start, $p, $n)
            Write-Verbose ('{0}: {1} ({2}) {3} s:{4}' -f $temp, $e.Name, $t, $e.Size, $e.Start)
        }
    }

    #  ___            _ _   ___ _         _      ___ _         _
    # / __|_ __  __ _| | | | _ ) |___  __| |__  / __| |_  __ _(_)_ _
    # \__ \ '  \/ _` | | | | _ \ / _ \/ _| / / | (__| ' \/ _` | | ' \
    # |___/_|_|_\__,_|_|_| |___/_\___/\__|_\_\  \___|_||_\__,_|_|_||_|
    #

    $sb_start = read-U32 -Buffer $dirtree_blocks -Offset 0x74

    Write-Verbose 'Start block chain'
    $StartTime = Get-Date

    # block chain as data for small-files
    # bbat->SS-follow( sb_start );
    $sb_blocks = SS-Follow -Buffer $bbat.data -Count $bbat.count -P $sb_start

    Write-Verbose ('End block chain {0}s' -f ((New-TimeSpan -Start $StartTime -End (Get-Date)).TotalSeconds))

    #  __  __     _           _      _
    # |  \/  |___| |_ __ _ __| |__ _| |_ __ _
    # | |\/| / -_)  _/ _` / _` / _` |  _/ _` |
    # |_|  |_\___|\__\__,_\__,_\__,_|\__\__,_|
    #

    Write-Verbose 'Start metadata'
    $StartTime = Get-Date

    # Metadata fields:
    # 'AuthorEmail'
    # 'AuthorName'
    # 'AuthorWebSite'
    # 'Collection*'
    # 'CustomInfoTags'
    # 'GameData'
    # 'GameItem*'
    # 'GameStg'
    # 'Image*'
    # 'MAC'
    # 'ReleaseDate'
    # 'Sound*'
    # 'Root Entry'
    # 'TableBlurb'
    # 'TableDescription'
    # 'TableInfo'
    # 'TableName'
    # 'TableRules'
    # 'TableSaveDate'
    # 'TableSaveRev'
    # 'TableVersion'
    # 'Version'

    # Only return commonly found text metadata fields.
    'AuthorName', `
        'TableName', `
        'TableSaveDate', `
        'TableVersion' `
    | ForEach-Object {
        $key = $_
        $entry = $dirtree | Where-Object Name -eq $key
        if ($entry) {
            if ($entry.Size -ge $header.threshold) {
                # blocks = io->bbat->SS-follow( e->start );
                $blocks = SS-Follow -Buffer $sbat.data -Count $sbat.count -P $entry.Start

                # TODO: implement multiple block reading
                @{
                    $key = 'BBAT'
                }
            }
            else {
                # Read from "mini" stream
                $blocks = SS-Follow -Buffer $sbat.data -Count $sbat.count -P $entry.Start
                if ($blocks.Length -eq 0) {
                    Write-Verbose "$key has no blocks"
                    return # go to next entry
                }

                # TODO: implement multiple block reading
                if ($blocks.Length -gt 1) {
                    Write-Verbose "$key has $($blocks.Length) blocks, only using first."
                }
                $entry_block = $blocks[0]

                # loadBigBlock( sb_blocks[ bbindex ], buf, bbat->blockSize );
                $bbpos = [uint64]$entry_block * $sbat.blockSize
                $bbindex = [uint64][Math]::Floor($bbpos / $bbat.blockSize)

                $block = $sb_blocks[$bbindex]
                $pos = [uint64]$bbat.blockSize * ($block + 1)

                $offset = [uint64]$bbpos % $bbat.blockSize

                # StorageIO::loadBigBlocks
                $fileStream.Seek($offset + $pos, [IO.SeekOrigin]::Begin) | Out-Null

                # TODO: can span multiple blocks. see Banzai Run -- TableDescription @ 7879d80
                $len = $entry.Size
                if ($offset + $len -gt $bbat.blockSize) {
                    $len = $bbat.blockSize - $offset
                }

                # Return {key, byte data}
                @{
                    $key = [Text.Encoding]::Unicode.GetString($fileReader.ReadBytes($len))
                }
            }
        }
    }

    Write-Verbose ('End metadata {0}s' -f ((New-TimeSpan -Start $StartTime -End (Get-Date)).TotalSeconds))

    $fileStream.Dispose()
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
    }

    Write-Verbose 'Waiting for VPX to exit'
    $proc.WaitForExit()

    $progressBar.Value = 0

    $buttonLaunch.Enabled = $true
    $buttonLaunch.Text = $prevText
}

$metadataCache = @{}

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
                $filename = $listView.SelectedItems.Tag
                $meta = $metadataCache[$filename]
                if (!$meta) {
                    $meta = Read-VpxMetadata -Path (Join-Path -Path $TablePath -ChildPath $filename)
                    $metadataCache[$filename] = $meta
                }

                $label1.Text = $meta.TableName
                $text = $null
                if ($meta.TableVersion) {
                    $text += "v$($meta.TableVersion) "
                }
                if ($meta.TableSaveDate) {
                    $text += "($($meta.TableSaveDate)) "
                }
                if ($meta.AuthorName) {
                    $text += "by $($meta.AuthorName)"
                }
                $label2.Text = $text
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
    $label1.AutoEllipsis = $true
    $panelStatus.Controls.Add($label1)

    $label2 = New-Object -TypeName 'Windows.Forms.Label'
    $label2.Text = ''
    $label2.Left = 7
    $label2.Top = 35
    $label2.Height = 20
    $label2.Width = 400
    $label2.AutoSize = $false
    $label2.AutoEllipsis = $true
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

    $form.Text = ('VPX Launcher v{0} - {1} machines' -f $launcherVersion, $listView.Items.Count)
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
        [string[]]$VpxFiles,
        [string]$DatabasePath,
        [string]$RomPath
    )

    $tableData = $null
    if (![string]::IsNullOrEmpty($DatabasePath)) {
        if (Test-Path -LiteralPath $DatabasePath -PathType Leaf) {
            $tableData = Get-Content -LiteralPath $DatabasePath `
            | ConvertFrom-Csv -Header 'Filename', 'Table', 'Manufacturer', 'Year', 'ROM' `
            | Sort-Object -Unique Filename
        }
    }

    $data = foreach ($vpxFile in $VpxFiles) {
        $baseName = [IO.Path]::GetFileNameWithoutExtension($vpxFile)
        $found = $tableData | Where-Object Filename -eq $baseName

        if (!$found) {
            # Use regex to try to guess table, manufacturer and year from filename.
            if ($baseName -match '(.+)[ _]\((.+) (\d{4})\)') {
                [PSCustomObject]@{
                    Filename     = $vpxFile
                    Table        = $matches[1]
                    Manufacturer = $matches[2]
                    Year         = $matches[3]
                }
                Write-Warning ('Not found in database: "{0}","{1}","{2}","{3}",""' -f $vpxFile, $matches[1], $matches[2], $matches[3])
            }
            else {
                [PSCustomObject]@{
                    Filename     = $vpxFile
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
            }

            [PSCustomObject]@{
                Filename     = $vpxFile
                Table        = $found.Table
                Manufacturer = $found.Manufacturer
                Year         = $found.Year
            }
        }
    }

    $data.GetEnumerator() | Sort-Object -Unique Table
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

$vpxFiles = (Get-ChildItem -File -LiteralPath $TablePath -Include '*.vpx').Name

# Read in database

$tables = Read-Database -VpxFiles $vpxFiles -DatabasePath $Database -RomPath $RomPath
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
