# TODO: Support pipeline (begin, process, end)

# .\Get-TableDetails.ps1 | Select-Object FileName, TableName, TableVersion, ReleaseDate

[CmdletBinding()]
Param(
    # Folder containing VPX tables
    [string]$TablePath = (Resolve-Path 'Tables')
)

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

function Get-LoadBigBlocks {
    [CmdletBinding()]
    param ($Blocks)

    for ($i = 0; $i -lt $blocks.Length; $i++) {
        $block = $blocks[$i]
        $pos = $bbat.blockSize * ($block + 1)
        $fileStream.Seek($pos, [IO.SeekOrigin]::Begin) | Out-Null
        $fileReader.ReadBytes($bbat.blockSize)
    }
}

function Get-DebugAllocTable {
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

function Get-Follow {
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
    $bbat.data = Get-LoadBigBlocks -Blocks $header.bbat_blocks
    $bbat.count = $bbat.data.Length / 4

    Write-Verbose ('bbat{0}' -f ($bbat | Out-String))

    # Get-DebugAllocTable -Buffer $bbat.data -Length $bbat.count

    #  ___             _   ___            _ _   ___       _
    # | _ \___ __ _ __| | / __|_ __  __ _| | | | _ ) __ _| |_
    # |   / -_) _` / _` | \__ \ '  \/ _` | | | | _ \/ _` |  _|
    # |_|_\___\__,_\__,_| |___/_|_|_\__,_|_|_| |___/\__,_|\__|
    #

    # bbat->Get-follow( header->sbat_start );
    $header.sbat_blocks = Get-Follow -Buffer $bbat.data -Count $bbat.count -P $header.sbat_start

    $sbat.data = Get-LoadBigBlocks -Blocks $header.sbat_blocks
    $sbat.count = $sbat.data.Length / 4

    # Get-DebugAllocTable -Buffer $sbat.data -Length $sbat.count

    #  ___             _   ___  _            _
    # | _ \___ __ _ __| | |   \(_)_ _ ___ __| |_ ___ _ _ _  _
    # |   / -_) _` / _` | | |) | | '_/ -_) _|  _/ _ \ '_| || |
    # |_|_\___\__,_\__,_| |___/|_|_| \___\__|\__\___/_|  \_, |
    #                                                    |__/

    $StartTime = Get-Date

    # bbat->Get-follow( header->dirent_start );
    $tree_blocks = Get-Follow -Buffer $bbat.data -Count $bbat.count -P $header.dirent_start

    $dirtree_blocks = Get-LoadBigBlocks -Blocks $tree_blocks
    $buflen = $tree_blocks.Length * $bbat.blockSize

    # Array +=  recreates the entire array on each add, so use ArrayList with .Add() to optimize.
    $dirtree = [Collections.ArrayList]@() # $dirtree = @()
    for ($i = 0; $i -lt $buflen / 128; $i++) {
        # NOTE: dirtree can be large (e.g. Machine Bride of Pinbot). We're just interested in first few entries, so drop out after a few
        # for performance. However, for general use (outside of VPX), this should read the entire dirtree.
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

        # $dirtree += @{
        $dirtree.Add(@{
                Name  = $name
                Type  = $type
                Size  = $size
                Start = $start
                # Next  = Read-U32 -Buffer $dirtree_blocks -Offset ($p + 0x40 + 0x08)
                # Prev  = Read-U32 -Buffer $dirtree_blocks -Offset ($p + 0x40 + 0x04)
                # Child = Read-U32 -Buffer $dirtree_blocks -Offset ($p + 0x40 + 0x0c)
            }) | Out-Null
    }

    Write-Verbose ('"{0}","dirtree", {1:n0}' -f (Split-Path $Path -Leaf), ((New-TimeSpan -Start $StartTime -End (Get-Date)).TotalMilliseconds))

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
    # bbat->Get-follow( sb_start );
    $sb_blocks = Get-Follow -Buffer $bbat.data -Count $bbat.count -P $sb_start


    Write-Verbose ('"{0}","Block chain",{1:n0}' -f (Split-Path $Path -Leaf), ((New-TimeSpan -Start $StartTime -End (Get-Date)).TotalMilliseconds))

    #  __  __     _           _      _
    # |  \/  |___| |_ __ _ __| |__ _| |_ __ _
    # | |\/| / -_)  _/ _` / _` / _` |  _/ _` |
    # |_|  |_\___|\__\__,_\__,_\__,_|\__\__,_|
    #

    $metadata = [PSCustomObject]@{
        'FileName' = (Split-Path -Leaf $Path)
    }

    $StartTime = Get-Date

    'AuthorEmail',
    'AuthorName',
    'AuthorWebSite',
    'Collection*',
    'CustomInfoTags',
    'GameData',
    'GameItem*',
    'GameStg',
    'Image*',
    'MAC',
    'ReleaseDate',
    'Sound*',
    'Root Entry',
    'TableBlurb',
    'TableDescription',
    'TableInfo',
    'TableName',
    'TableRules',
    'TableSaveDate',
    'TableSaveRev',
    'TableVersion',
    'Version'
    | ForEach-Object {
        $key = $_
        $entry = $dirtree | Where-Object Name -eq $key
        if ($entry) {
            if ($entry.Size -ge $header.threshold) {
                # blocks = io->bbat->Get-follow( e->start );
                $blocks = Get-Follow -Buffer $sbat.data -Count $sbat.count -P $entry.Start

                # TODO: implement multiple block reading
                Write-Verbose "Detected BBAT block (NYI) in $Path"
                # $metadata | Add-Member -MemberType NoteProperty -Name 'BBAT' -Value ''
            }
            else {
                # Read from "mini" stream
                $blocks = Get-Follow -Buffer $sbat.data -Count $sbat.count -P $entry.Start
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

                $metadata | Add-Member -MemberType NoteProperty -Name $key -Value ([Text.Encoding]::Unicode.GetString($fileReader.ReadBytes($len)))
            }
        }
    }

    Write-Verbose ('"{0}","Metadata",{1:n0}' -f (Split-Path $Path -Leaf), ((New-TimeSpan -Start $StartTime -End (Get-Date)).TotalMilliseconds))

    $fileStream.Dispose()

    $metadata
}

#
# MAIN
#

Get-ChildItem -LiteralPath $TablePath -File -Filter '*.vpx' | ForEach-Object {
    Read-VpxMetadata -Path $_.FullName
}
