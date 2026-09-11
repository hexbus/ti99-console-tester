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
    $extensionBytes[0x2c] -ne 0x16 -or $extensionBytes[0x2d] -ne 0x06) {
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
$beta07Path = Join-Path $outputDir 'ti99-sidecar-diag-beta-0.7-16k-w27c512.bin'
$tiSafePath = Join-Path $outputDir 'HEXDIAG07.BIN'
Copy-Item -LiteralPath $direct16Path -Destination $beta07Path -Force
Copy-Item -LiteralPath $direct16Path -Destination $tiSafePath -Force

$manifest = [ordered]@{
    schema = 'ti99-sidecar-diagnostic-build-v1'
    version = '0.7'
    status = 'PUBLIC_BETA'
    mapping = [ordered]@{
        extension_rom = '>6000->7FFF'
        tester_sram = '>C000->DFFF'
        automatic_core_rom = '>E000->FFFF'
        megademo_runtime = '>D000->D537'
    }
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
    program_this_file = [IO.Path]::GetFileName($beta07Path)
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
Write-Output "PROGRAM THIS FOR BETA 0.7: $beta07Path"
Write-Output "TI-SAFE FILENAME ALIAS: $tiSafePath"
