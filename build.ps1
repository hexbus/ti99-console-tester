# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Jon Guidry (hexbus)
# Project: https://github.com/hexbus/ti99-console-tester
$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$outputDir = Join-Path $projectRoot 'build'
$source = Join-Path $projectRoot 'src\HEXDIAG.a99'
$extensionSource = Join-Path $projectRoot 'src\HEXEXT.a99'
$megaDemoSource = Join-Path $projectRoot 'src\MEGAU7.a99'
$xas = $env:XAS99_PATH
if (-not $xas) { $xas = Join-Path $projectRoot '..\xdt99\xas99.py' }
$python = (Get-Command python -ErrorAction Stop).Source

if (-not (Test-Path -LiteralPath $xas)) { throw "Missing xdt99 assembler: $xas" }
New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

$rom = Join-Path $outputDir 'ti99-sidecar-diag-8k.bin'
$listing = Join-Path $outputDir 'ti99-sidecar-diag-8k.lst'
$extensionRom = Join-Path $outputDir 'ti99-sidecar-extension-8k.bin'
$extensionListing = Join-Path $outputDir 'ti99-sidecar-extension-8k.lst'
$megaDemoRom = Join-Path $outputDir 'megademo-splitscreen3-u7.bin'
$megaDemoListing = Join-Path $outputDir 'megademo-splitscreen3-u7.lst'
Push-Location (Split-Path -Parent $source)
try {
    # Reassemble the original effect for the tester's own >D000 U7 SRAM before
    # the fixed core embeds it with BCOPY. -M removes 8K padding, leaving the
    # exact >538-byte runtime image.
    & $python $xas -B -M -R -X -L $megaDemoListing -o $megaDemoRom $megaDemoSource
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    $megaDemoBytes = [IO.File]::ReadAllBytes($megaDemoRom)
    if ($megaDemoBytes.Length -ne 0x538) {
        throw "Relocated MegaDemo is $($megaDemoBytes.Length) bytes; expected 1336"
    }
    if ([BitConverter]::ToString($megaDemoBytes[0..3]) -ne 'D0-04-D0-28') {
        throw 'Relocated MegaDemo TOPINI/TOPFRM vectors are not >D004,>D028'
    }
    & $python $xas -B -R -X -L $listing -o $rom $source
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    & $python $xas -B -R -X -L $extensionListing -o $extensionRom $extensionSource
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
} finally {
    Pop-Location
}

# xas99 permits AORG to move backward without reporting that the new block
# overwrote bytes emitted earlier.  Treat the listings as a link map: every
# absolute-origin region has a named first and end symbol, and every source has
# an exact, reviewed AORG inventory.  A new, removed, moved, oversized, or
# overlapping region therefore stops the build before any programmer image is
# produced.
$coreListingText = Get-Content -Raw -LiteralPath $listing
$extensionListingText = Get-Content -Raw -LiteralPath $extensionListing
$megaDemoListingText = Get-Content -Raw -LiteralPath $megaDemoListing

function Get-ListingAddress {
    param(
        [Parameter(Mandatory = $true)][string]$ListingText,
        [Parameter(Mandatory = $true)][string]$Symbol,
        [Parameter(Mandatory = $true)][string]$ImageName
    )
    $match = [regex]::Match(
        $ListingText,
        ('(?m)^\s*\d+\s+([0-9A-Fa-f]{{4}})\s+{0}\b' -f [regex]::Escape($Symbol))
    )
    if (-not $match.Success) {
        throw "$ImageName listing does not expose required layout symbol $Symbol"
    }
    return [Convert]::ToInt32($match.Groups[1].Value, 16)
}

function Assert-OriginInventory {
    param(
        [Parameter(Mandatory = $true)][string]$SourcePath,
        [Parameter(Mandatory = $true)][int[]]$ExpectedOrigins
    )
    $sourceText = Get-Content -Raw -LiteralPath $SourcePath
    $matches = [regex]::Matches($sourceText, '(?im)^\s*aorg\s+>([0-9a-f]{4})\s*(?:\*.*)?$')
    $actualOrigins = @($matches | ForEach-Object {
        [Convert]::ToInt32($_.Groups[1].Value, 16)
    })
    if ($actualOrigins.Count -ne $ExpectedOrigins.Count) {
        throw "$(Split-Path -Leaf $SourcePath) has $($actualOrigins.Count) AORG directives; expected $($ExpectedOrigins.Count). Update and review the complete ROM map."
    }
    for ($i = 0; $i -lt $ExpectedOrigins.Count; $i++) {
        if ($actualOrigins[$i] -ne $ExpectedOrigins[$i]) {
            throw ('{0} AORG #{1} is >{2:X4}; expected >{3:X4}' -f
                (Split-Path -Leaf $SourcePath), ($i + 1), $actualOrigins[$i], $ExpectedOrigins[$i])
        }
        if ($i -gt 0 -and $actualOrigins[$i] -le $actualOrigins[$i - 1]) {
            throw ('{0} AORG #{1} moves backward or repeats an origin' -f
                (Split-Path -Leaf $SourcePath), ($i + 1))
        }
    }
}

function Get-CheckedRegionMap {
    param(
        [Parameter(Mandatory = $true)][string]$ListingText,
        [Parameter(Mandatory = $true)][string]$ImageName,
        [Parameter(Mandatory = $true)][object[]]$Definitions
    )
    $map = @()
    foreach ($definition in $Definitions) {
        $actualStart = Get-ListingAddress $ListingText $definition.StartSymbol $ImageName
        if ($actualStart -ne $definition.Start) {
            throw ('{0} region "{1}" begins at >{2:X4}; expected >{3:X4}' -f
                $ImageName, $definition.Name, $actualStart, $definition.Start)
        }
        $actualEnd = Get-ListingAddress $ListingText $definition.EndSymbol $ImageName
        if ($actualEnd -lt $actualStart) { $actualEnd += 0x10000 }
        if ($actualEnd -gt $definition.NextStart) {
            throw ('{0} region "{1}" ends at >{2:X4} and overlaps the next block at >{3:X4}' -f
                $ImageName, $definition.Name, $actualEnd, $definition.NextStart)
        }
        if ($definition.PSObject.Properties['ExactEnd'] -and
            $actualEnd -ne $definition.ExactEnd) {
            throw ('{0} region "{1}" ends at >{2:X4}; required end is >{3:X4}' -f
                $ImageName, $definition.Name, $actualEnd, $definition.ExactEnd)
        }
        $map += [pscustomobject]@{
            Name = $definition.Name
            Start = $actualStart
            End = $actualEnd
            UsedBytes = $actualEnd - $actualStart
            GapBytes = $definition.NextStart - $actualEnd
        }
    }
    for ($i = 0; $i -lt ($map.Count - 1); $i++) {
        if ($map[$i].End -gt $map[$i + 1].Start) {
            throw ('{0} regions "{1}" and "{2}" overlap' -f
                $ImageName, $map[$i].Name, $map[$i + 1].Name)
        }
    }
    return $map
}

Assert-OriginInventory $source @(0xe000,0xf100,0xf22a,0xf546,0xf876,0xfdae,0xfdf8,0xfe00,0xff00,0xfff8)
Assert-OriginInventory $extensionSource @(0x6000,0x7f00,0x7f30,0x7f80,0x7ffe)

$coreDefinitions = @(
    [pscustomobject]@{ Name='Core header, code, text, font'; Start=0xe000; StartSymbol='CSTART'; EndSymbol='CEND'; NextStart=0xf100 },
    [pscustomobject]@{ Name='MegaDemo PSG phrase'; Start=0xf100; StartSymbol='MUSBEG'; EndSymbol='MDPSGE'; NextStart=0xf22a; ExactEnd=0xf22a },
    [pscustomobject]@{ Name='Enhanced-VDP detector and shared text'; Start=0xf22a; StartSymbol='F18BEG'; EndSymbol='F18END'; NextStart=0xf546 },
    [pscustomobject]@{ Name='VDP assets and keyboard matrix helpers'; Start=0xf546; StartSymbol='VDPBEG'; EndSymbol='VDPEND'; NextStart=0xf876 },
    [pscustomobject]@{ Name='Embedded relocated U7 effect'; Start=0xf876; StartSymbol='MFXBEG'; EndSymbol='MFXEND'; NextStart=0xfdae; ExactEnd=0xfdae },
    [pscustomobject]@{ Name='GROM-result formatter'; Start=0xfdae; StartSymbol='GRSBEG'; EndSymbol='GREND'; NextStart=0xfdf8 },
    [pscustomobject]@{ Name='Extension ABI marker'; Start=0xfdf8; StartSymbol='ABIBEG'; EndSymbol='ABIEND'; NextStart=0xfe00; ExactEnd=0xfdfc },
    [pscustomobject]@{ Name='Extension service gateway'; Start=0xfe00; StartSymbol='SVCBEG'; EndSymbol='SVCEND'; NextStart=0xff00 },
    [pscustomobject]@{ Name='LOAD entry'; Start=0xff00; StartSymbol='LODBEG'; EndSymbol='LODEND'; NextStart=0xfff8 },
    [pscustomobject]@{ Name='Core vectors and checksum'; Start=0xfff8; StartSymbol='VECBEG'; EndSymbol='ROMEND'; NextStart=0x10000; ExactEnd=0x10000 }
)
$extensionDefinitions = @(
    [pscustomobject]@{ Name='Extension header, code, text, data'; Start=0x6000; StartSymbol='XSTART'; EndSymbol='XEND'; NextStart=0x7f00 },
    [pscustomobject]@{ Name='TI-99/4A matrix table'; Start=0x7f00; StartSymbol='KMABEG'; EndSymbol='KMTEND'; NextStart=0x7f30; ExactEnd=0x7f30 },
    [pscustomobject]@{ Name='TI-99/4 matrix and SHIFT tables'; Start=0x7f30; StartSymbol='K4BEG'; EndSymbol='K4SEND'; NextStart=0x7f80; ExactEnd=0x7f80 },
    [pscustomobject]@{ Name='TI-99/4A SHIFT translation'; Start=0x7f80; StartSymbol='KSHBEG'; EndSymbol='KSHEND'; NextStart=0x7ffe; ExactEnd=0x7fc0 },
    [pscustomobject]@{ Name='Extension checksum'; Start=0x7ffe; StartSymbol='XSMBEG'; EndSymbol='XROMND'; NextStart=0x8000; ExactEnd=0x8000 }
)
$megaDefinitions = @(
    [pscustomobject]@{ Name='Relocated U7 runtime image'; Start=0xd000; StartSymbol='MSTART'; EndSymbol='MEND'; NextStart=0xe000; ExactEnd=0xd538 }
)

$coreRegionMap = @(Get-CheckedRegionMap $coreListingText 'core ROM' $coreDefinitions)
$extensionRegionMap = @(Get-CheckedRegionMap $extensionListingText 'extension ROM' $extensionDefinitions)
$megaRegionMap = @(Get-CheckedRegionMap $megaDemoListingText 'U7 runtime' $megaDefinitions)

$fontBegin = Get-ListingAddress $coreListingText 'FONTBEG' 'core ROM'
$fontEnd = Get-ListingAddress $coreListingText 'FONTEND' 'core ROM'
if (($fontEnd - $fontBegin) -ne 0x300) {
    throw ('The ASCII 32->127 font is {0} bytes; expected exactly 768' -f ($fontEnd - $fontBegin))
}
if ($fontBegin -lt 0xe000 -or $fontEnd -gt (Get-ListingAddress $coreListingText 'CEND' 'core ROM')) {
    throw 'The ASCII font lies outside the checked variable core region'
}

$xEnd = Get-ListingAddress $extensionListingText 'XEND' 'extension ROM'
if ($xEnd -gt 0x7ef0) {
    throw ('Variable extension content ends at >{0:X4}; >7EF0->7EFF is reserved headroom before the fixed >7F00 keyboard tables' -f $xEnd)
}
if ((Get-ListingAddress $extensionListingText 'K4TEND' 'extension ROM') -ne 0x7f58 -or
    (Get-ListingAddress $extensionListingText 'K4SBEG' 'extension ROM') -ne 0x7f58) {
    throw 'The TI-99/4 normal matrix table is not exactly 40 bytes'
}

$bytes = [IO.File]::ReadAllBytes($rom)
if ($bytes.Length -ne 0x2000) {
    throw "ROM is $($bytes.Length) bytes; the 27C64 image must be exactly 8192 bytes"
}
if ($bytes[0] -ne 0xaa -or $bytes[1] -ne 0x01) {
    throw 'The >E000 peripheral-ROM header is missing'
}
if ($bytes[0x1ff8] -ne 0xd1 -or $bytes[0x1ff9] -ne 0xa6) {
    throw 'The >FFF8 diagnostic marker is missing'
}
if ($bytes[0x1df8] -ne 0xd1 -or $bytes[0x1df9] -ne 0xa6 -or
    $bytes[0x1dfa] -ne 0x01 -or $bytes[0x1dfb] -ne 0x01) {
    throw 'The >FDF8 extension service ABI marker/version is missing'
}
if ($bytes[0x1ffc] -ne 0xc0 -or $bytes[0x1ffd] -ne 0x00 -or
    $bytes[0x1ffe] -ne 0xff -or $bytes[0x1fff] -ne 0x00) {
    throw 'The >FFFC LOAD vector is not >C000,>FF00'
}

$bytes[0x1ffa] = 0
$bytes[0x1ffb] = 0
[uint32]$sum = 0
for ($i = 0; $i -lt $bytes.Length; $i += 2) {
    $word = ([uint32]$bytes[$i] -shl 8) + [uint32]$bytes[$i + 1]
    $sum = ($sum + $word) -band 0xffff
}
[uint16]$fix = (0x10000 - $sum) -band 0xffff
$bytes[0x1ffa] = ($fix -shr 8) -band 0xff
$bytes[0x1ffb] = $fix -band 0xff
[IO.File]::WriteAllBytes($rom, $bytes)

[uint32]$verify = 0
for ($i = 0; $i -lt $bytes.Length; $i += 2) {
    $word = ([uint32]$bytes[$i] -shl 8) + [uint32]$bytes[$i + 1]
    $verify = ($verify + $word) -band 0xffff
}
if ($verify -ne 0) { throw 'Final ROM word sum is not zero' }

$extensionBytes = [IO.File]::ReadAllBytes($extensionRom)
if ($extensionBytes.Length -ne 0x2000) {
    throw "Extension is $($extensionBytes.Length) bytes; expected exactly 8192 bytes"
}
if ($extensionBytes[0] -ne 0xaa -or $extensionBytes[1] -ne 0x01) {
    throw 'The >6000 TI cartridge header is missing'
}
if ($extensionBytes[2] -ne 0x01 -or $extensionBytes[3] -ne 0x00) {
    throw 'The >6000 TI cartridge header does not advertise a program list'
}
if ($extensionBytes[0x2a] -ne 0xd1 -or $extensionBytes[0x2b] -ne 0xa6 -or
    $extensionBytes[0x2c] -ne 0x16 -or $extensionBytes[0x2d] -ne 0x08) {
    throw 'The private extension signature/version at >602A is missing'
}
$extensionEntry = ([uint32]$extensionBytes[0x2e] -shl 8) + [uint32]$extensionBytes[0x2f]
if ($extensionEntry -lt 0x6032 -or $extensionEntry -ge 0x7ffe) {
    throw ('The extension entry vector is outside executable ROM: >{0:X4}' -f $extensionEntry)
}
if ($extensionBytes[0x30] -ne 0x01 -or $extensionBytes[0x31] -ne 0x01) {
    throw 'The extension does not require fixed-core service ABI 1.1'
}
$extensionBytes[0x1ffe] = 0
$extensionBytes[0x1fff] = 0
[uint32]$extensionSum = 0
for ($i = 0; $i -lt $extensionBytes.Length; $i += 2) {
    $extensionWord = ([uint32]$extensionBytes[$i] -shl 8) + [uint32]$extensionBytes[$i + 1]
    $extensionSum = ($extensionSum + $extensionWord) -band 0xffff
}
[uint16]$extensionFix = (0x10000 - $extensionSum) -band 0xffff
$extensionBytes[0x1ffe] = ($extensionFix -shr 8) -band 0xff
$extensionBytes[0x1fff] = $extensionFix -band 0xff
[IO.File]::WriteAllBytes($extensionRom, $extensionBytes)

[uint32]$extensionVerify = 0
for ($i = 0; $i -lt $extensionBytes.Length; $i += 2) {
    $extensionWord = ([uint32]$extensionBytes[$i] -shl 8) + [uint32]$extensionBytes[$i + 1]
    $extensionVerify = ($extensionVerify + $extensionWord) -band 0xffff
}
if ($extensionVerify -ne 0) { throw 'Final extension word sum is not zero' }

# Safe no-banking W27C512 programmer image: all eight physical 8 KiB banks
# are identical, so A13/A14/A15 cannot select different contents yet.
$w27c512 = Join-Path $outputDir 'ti99-sidecar-diag-w27c512.bin'
$wide = New-Object byte[] 0x10000
for ($bank = 0; $bank -lt 8; $bank++) {
    [Array]::Copy($bytes, 0, $wide, $bank * 0x2000, 0x2000)
}
[IO.File]::WriteAllBytes($w27c512, $wide)

# First direct-mapped 16K engineering image.  CPU addresses and W27 offsets
# match because the lifted A13-A15 pins receive TI A2-A0 respectively.
$direct16Path = Join-Path $outputDir 'ti99-sidecar-diag-16k-w27c512.bin'
$direct16 = New-Object byte[] 0x10000
for ($i = 0; $i -lt $direct16.Length; $i++) { $direct16[$i] = 0xff }
[Array]::Copy($extensionBytes, 0, $direct16, 0x6000, 0x2000)
[Array]::Copy($bytes, 0, $direct16, 0xe000, 0x2000)
[IO.File]::WriteAllBytes($direct16Path, $direct16)
$beta08Path = Join-Path $outputDir 'ti99-sidecar-diag-beta-0.8-16k-w27c512.bin'
$tiSafePath = Join-Path $outputDir 'HEXDIAG08.BIN'
Copy-Item -LiteralPath $direct16Path -Destination $beta08Path -Force
Copy-Item -LiteralPath $direct16Path -Destination $tiSafePath -Force

function Convert-RegionMapForManifest {
    param([Parameter(Mandatory = $true)][object[]]$Regions)
    return @($Regions | ForEach-Object {
        [ordered]@{
            name = $_.Name
            start = ('>{0:X4}' -f $_.Start)
            end_exclusive = ('>{0:X4}' -f $_.End)
            used_bytes = $_.UsedBytes
            free_bytes_before_next_region = $_.GapBytes
        }
    })
}

$verifiedLayout = [ordered]@{
    core_rom = Convert-RegionMapForManifest $coreRegionMap
    extension_rom = Convert-RegionMapForManifest $extensionRegionMap
    u7_runtime = Convert-RegionMapForManifest $megaRegionMap
}

$manifest = [ordered]@{
    schema = 'ti99-sidecar-diagnostic-build-v1'
    version = '0.8'
    status = 'PUBLIC_BETA'
    mapping = [ordered]@{
        extension_rom = '>6000->7FFF'
        tester_sram = '>C000->DFFF'
        automatic_core_rom = '>E000->FFFF'
        megademo_runtime = '>D000->D537'
    }
    verified_regions = $verifiedLayout
    workspace = '>C000'
    load_vector = '>C000,>FF00'
    size_bytes = $bytes.Length
    runtime_word_sum = '>0000'
    sha256 = (Get-FileHash -LiteralPath $rom -Algorithm SHA256).Hash.ToLowerInvariant()
    w27c512 = [IO.Path]::GetFileName($w27c512)
    w27c512_size_bytes = $wide.Length
    w27c512_sha256 = (Get-FileHash -LiteralPath $w27c512 -Algorithm SHA256).Hash.ToLowerInvariant()
    w27c512_layout = 'eight identical 8 KiB banks; A13/A14/A15 do not select unique content'
    extension = [IO.Path]::GetFileName($extensionRom)
    extension_size_bytes = $extensionBytes.Length
    extension_runtime_word_sum = '>0000'
    extension_entry = ('>{0:X4}' -f $extensionEntry)
    extension_core_abi = '1.1'
    extension_sha256 = (Get-FileHash -LiteralPath $extensionRom -Algorithm SHA256).Hash.ToLowerInvariant()
    direct16_w27c512 = [IO.Path]::GetFileName($direct16Path)
    program_this_file = [IO.Path]::GetFileName($beta08Path)
    ti_filename_alias = [IO.Path]::GetFileName($tiSafePath)
    direct16_w27c512_size_bytes = $direct16.Length
    direct16_w27c512_sha256 = (Get-FileHash -LiteralPath $direct16Path -Algorithm SHA256).Hash.ToLowerInvariant()
    direct16_w27c512_layout = 'extension at >6000->7FFF; core at >E000->FFFF; all other bytes >FF'
    megademo_payload = [IO.Path]::GetFileName($megaDemoRom)
    megademo_payload_size_bytes = $megaDemoBytes.Length
    megademo_payload_sha256 = (Get-FileHash -LiteralPath $megaDemoRom -Algorithm SHA256).Hash.ToLowerInvariant()
    megademo_runtime_note = 'relocated original controller executes from sidecar U7 SRAM at >D000; no optional >A000 expansion RAM is used'
}
$manifest | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $outputDir 'manifest.json') -Encoding utf8

Write-Output "Built $rom"
Write-Output "SHA-256 $($manifest.sha256)"
Write-Output "Built $w27c512"
Write-Output "SHA-256 $($manifest.w27c512_sha256)"
Write-Output "Built $direct16Path"
Write-Output "SHA-256 $($manifest.direct16_w27c512_sha256)"
Write-Output "Verified $($coreRegionMap.Count + $extensionRegionMap.Count + $megaRegionMap.Count) non-overlapping AORG/XORG regions from assembler listings"
Write-Output "PROGRAM THIS PUBLIC BETA 0.8 BUILD: $beta08Path"
Write-Output "TI-SAFE FILENAME ALIAS: $tiSafePath"
