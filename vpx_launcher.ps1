[CmdletBinding()]
Param(
    # Location to the VPinball EXE
    [string]$PinballExe = (Resolve-Path 'VPinballX64.exe'),
    # Folder containing VPX tables
    [string]$TablePath = (Resolve-Path 'Tables'),
    # Zero-based display number to use. Find numbers in Settings > System > Display
    [int]$Display = -1,
    # For launcher development testing
    [switch]$Benchmark
)

$script:launcherVersion = '1.2'

$script:colorScheme = @{
    ListView_BackColor     = [Drawing.Color]::FromArgb(56, 63, 62)
    ListView_ForeColor     = [Drawing.Color]::FromArgb(229, 230, 255)
    PanelStatus_BackColor  = [Drawing.Color]::FromArgb(38, 43, 46)
    PanelStatus_ForeColor  = [Drawing.Color]::FromArgb(143, 147, 149)
    ProgressBar_BackColor  = [Drawing.Color]::FromArgb(134, 134, 134)
    ProgressBar_ForeColor  = [Drawing.Color]::FromArgb(249, 248, 248)
    ButtonLaunch_BackColor = [Drawing.Color]::FromArgb(23, 18, 24)
    ButtonLaunch_ForeColor = [Drawing.Color]::FromArgb(234, 231, 232)
}

$script:metadataCache = @{}
$script:launchCount = @{}


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

    # "Last Action Hero (Data East 1993) VPW 2.0.vpx" had this in sbat->start table, so check for this as well.
    $Unknown = [uint32]0xffffffffL

    $blocks = @()

    for ($i = 0; $i -lt $Count) {
        if ($P -in $Eof, $Bat, $MetaBat, $Unknown) { break }
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
    if (!$fileStream) { return }
    # https://learn.microsoft.com/en-us/dotnet/api/system.io.binaryreader?view=net-8.0
    $fileReader = New-Object -TypeName 'IO.BinaryReader' -ArgumentList $fileStream
    if (!$fileReader) { return }

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

    $StartTime = Get-Date

    # bbat->SS-follow( header->dirent_start );
    $tree_blocks = SS-Follow -Buffer $bbat.data -Count $bbat.count -P $header.dirent_start

    $dirtree_blocks = SS-LoadBigBlocks -Blocks $tree_blocks
    $buflen = $tree_blocks.Length * $bbat.blockSize

    $dirtree = @()
    for ($i = 0; $i -lt $buflen / 128; $i++) {
        # NOTE: dirtree can be large (e.g. Machine Bride of Pinbot). We're just interested in first few entries, so drop out after a few
        # for performance.
        if ($i -ge 16 ) { break }

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

        $name = [Text.Encoding]::Unicode.GetString($dirtree_blocks[($p + $0)..($p + $name_len - 1)])

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
    if ($Benchmark) {
        Write-Host ('"{0}","dirtree", {1:n0}' -f (Split-Path $Path -Leaf), ((New-TimeSpan -Start $StartTime -End (Get-Date)).TotalMilliseconds))
    }

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

    $StartTime = Get-Date

    # block chain as data for small-files
    # bbat->SS-follow( sb_start );
    $sb_blocks = SS-Follow -Buffer $bbat.data -Count $bbat.count -P $sb_start

    if ($Benchmark) {
        Write-Host ('"{0}","Block chain",{1:n0}' -f (Split-Path $Path -Leaf), ((New-TimeSpan -Start $StartTime -End (Get-Date)).TotalMilliseconds))
    }

    #  __  __     _           _      _
    # |  \/  |___| |_ __ _ __| |__ _| |_ __ _
    # | |\/| / -_)  _/ _` / _` / _` |  _/ _` |
    # |_|  |_\___|\__\__,_\__,_\__,_|\__\__,_|
    #

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

    if ($Benchmark) {
        Write-Host ('"{0}","Metadata",{1:n0}' -f (Split-Path $Path -Leaf), ((New-TimeSpan -Start $StartTime -End (Get-Date)).TotalMilliseconds))
    }

    $fileStream.Dispose()
}

#  ___                               _       _                      _    ___              _
# |_ _|_ _  __ _ _ ___ _ __  ___ _ _| |_ ___| |   __ _ _  _ _ _  __| |_ / __|___ _  _ _ _| |_
#  | || ' \/ _| '_/ -_) '  \/ -_) ' \  _|___| |__/ _` | || | ' \/ _| ' \ (__/ _ \ || | ' \  _|
# |___|_||_\__|_| \___|_|_|_\___|_||_\__|   |____\__,_|\_,_|_||_\__|_||_\___\___/\_,_|_||_\__|
#

function Increment-LaunchCount {
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
    }

    Write-Verbose 'Waiting for VPX to exit'
    $proc.WaitForExit()

    $progressBar.Value = 0

    $buttonLaunch.Enabled = $true
    $buttonLaunch.Text = $prevText

    $filename = (Split-Path -Path $TablePath -Leaf).ToLower()
    $count = Increment-LaunchCount -FileName $filename

    # Update listview play count
    $listView.SelectedItems[0].SubItems[3].Text = $count

    Write-Verbose ('VPX (filename: {0}) exited' -f $filename)
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
    # $panelListView.Width = 500

    $listView = New-Object -TypeName 'Windows.Forms.ListView'
    $listView.Dock = [Windows.Forms.DockStyle]::Fill
    $listView.BorderStyle = [Windows.Forms.BorderStyle]::FixedSingle
    $listView.FullRowSelect = $true
    $listView.MultiSelect = $false
    $listView.View = [Windows.Forms.View]::Details
    $listView.Font = New-Object  System.Drawing.Font('Consolas', 11, [Drawing.FontStyle]::Regular)
    $listView.BackColor = $script:colorScheme.ListView_BackColor
    $listView.ForeColor = $script:colorScheme.ListView_ForeColor


    $listView.Columns.Add('Table', 330) | Out-Null
    $listView.Columns.Add('Manufact.', 130) | Out-Null
    $listView.Columns.Add('Year', 53) | Out-Null
    $listView.Columns.Add('Play', 50) | Out-Null

    $panelListView.Controls.Add($listView)

    foreach ($item in $Data) {
        $listItem = New-Object -TypeName 'Windows.Forms.ListViewItem'
        $listItem.Text = $item.Table
        $listItem.Tag = $item.FileName
        $listItem.SubItems.Add($item.Manufacturer) | Out-Null
        $listItem.SubItems.Add($item.Year) | Out-Null
        $launchCount = $script:launchCount[$listItem.Tag]
        if (!$launchCount) { $launchCount = '0' }
        $listItem.SubItems.Add($launchCount) | Out-Null

        $listView.Items.Add($listItem) | Out-Null
    }

    $listView.Items[0].Selected = $true

    $listView.add_SelectedIndexChanged({
            if ($listView.SelectedItems.Count -eq 1) {
                $filename = $listView.SelectedItems.Tag

                # Update metadata
                $meta = $script:metadataCache[$filename]
                if (!$meta) {
                    $meta = Read-VpxMetadata -Path (Join-Path -Path $TablePath -ChildPath $filename)
                    $script:metadataCache[$filename] = $meta
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
            $items = $this.Items `
            | ForEach-Object { $_ } `
            | Sort-Object -Descending:$script:listViewSort.Descending -Property @{ Expression = { $_.SubItems[$script:listViewSort.Column].Text } }

            $this.Items.Clear()
            $this.ShowGroups = $false
            $this.Sorting = 'none'

            $items | ForEach-Object { $this.Items.Add($_) }
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

    $form.Text = ('VPX Launcher v{0} - {1} machines' -f $script:launcherVersion, $listView.Items.Count)
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

function Append-Article {
    param ([Parameter(Mandatory)][string]$String)

    $appended = $false

    'the', 'a', 'an' | ForEach-Object {
        if ($String -like "$_ *") {
            '{0}, {1}' -f $String.SubString($_.Length + 1), $String.SubString(0, $_.Length)
            $appended = $true
        }
    }

    if (!$appended) {
        $String
    }
}

#  ___                      ___ _ _
# | _ \__ _ _ _ ___ ___ ___| __(_) |___ _ _  __ _ _ __  ___ ___
# |  _/ _` | '_(_-</ -_)___| _|| | / -_) ' \/ _` | '  \/ -_|_-<
# |_| \__,_|_| /__/\___|   |_| |_|_\___|_||_\__,_|_|_|_\___/__/
#

function Parse-Filenames {
    param (
        [string[]]$VpxFiles
    )

    $data = foreach ($vpxFile in $VpxFiles) {
        $baseName = [IO.Path]::GetFileNameWithoutExtension($vpxFile)

        # Use regex to try to guess table, manufacturer and year from filename.
        if ($baseName -match '(.+)[ _]?\((.+)(\d{4})\)') {
            [PSCustomObject]@{
                FileName     = $vpxFile
                Table        = Append-Article -String $matches[1].Trim()
                Manufacturer = $matches[2].Trim()
                Year         = $matches[3].Trim()
            }
        }
        else {
            [PSCustomObject]@{
                FileName     = $vpxFile
                Table        = $baseName
                Manufacturer = '?'
                Year         = '?'
            }
            Write-Warning ('Unable to parse filename "{0}"' -f $baseName)
        }
    }

    $data.GetEnumerator() | Sort-Object -Unique Table
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


$vpxFiles = (Get-ChildItem -File -LiteralPath $TablePath -Include '*.vpx').Name

# Read in database
$tables = Parse-Filenames -VpxFiles $vpxFiles
if ($tables.Count -eq 0) {
    Write-Warning "No tables found in $TablePath"
    return
}

if ($Benchmark) {
    'Duration: {0:n0}ms' -f ((Measure-Command -Expression {
                foreach ($table in $tables) {
                    Read-VpxMetadata -Path (Join-Path -Path $TablePath -ChildPath $table.FileName) | Out-Null
                }
            }).TotalMilliseconds)
    return
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

Invoke-Dialog -Data $tables | Out-Null

# Write out configuration
Write-Verbose "Writing config to $cfgPath"
@{
    LaunchCount = $script:launchCount
} | ConvertTo-Json | Out-File $cfgPath
