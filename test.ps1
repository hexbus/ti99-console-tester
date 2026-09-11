# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Jon Guidry (hexbus)
# Project: https://github.com/hexbus/ti99-console-tester

$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
& (Join-Path $projectRoot 'build.ps1')
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$rom = Join-Path $projectRoot 'build\ti99-sidecar-diag-8k.bin'
$bytes = [IO.File]::ReadAllBytes($rom)

if ($bytes.Length -ne 8192) { throw 'Unexpected image size' }
if ([BitConverter]::ToString($bytes[0..15]) -ne 'AA-01-00-00-00-00-E0-10-00-00-00-00-00-00-00-00') {
    throw 'Peripheral-ROM header differs from the proven legacy startup layout'
}
$titleLength = $bytes[0x14]
if ($titleLength -ne 17) { throw "Unexpected title length: $titleLength" }
$title = [Text.Encoding]::ASCII.GetString($bytes, 0x15, $titleLength)
if ($title -ne 'TI-99/4 & 4A DIAG') { throw "Unexpected title entry: $title" }

$imageText = [Text.Encoding]::ASCII.GetString($bytes)
$activeCoreSource = ((Get-Content -LiteralPath (Join-Path $projectRoot 'src\HEXDIAG.a99')) |
    ForEach-Object { ($_ -split '\*', 2)[0] }) -join "`n"
$activeExtensionSource = ((Get-Content -LiteralPath (Join-Path $projectRoot 'src\HEXEXT.a99')) |
    ForEach-Object { ($_ -split '\*', 2)[0] }) -join "`n"
if (($activeCoreSource + "`n" + $activeExtensionSource) -match '(?im)^\s*bl\s+@>000e\b') {
    throw 'Executable source still calls the console ROM KSCAN vector at >000E'
}
$requiredOperatorText = @(
    'CPU ROM READ',
    'GROM READ PATH',
    'STABLE',
    'UNSTABLE',
    'NO DATA?',
    'STOCK TI-99/4 (1979)',
    'STOCK TI-99/4A (1981)',
    'TI-99/4QI V2.2 (1983)',
    'UNKNOWN/HOMEBREW - CALL ME!',
    '=KNOWN',
    '=OTHER',
    'CUSTOM/MIXED IS NOT A FAILURE',
    '16K EXTENSION',
    '8K MODE',
    'PRESENT',
    'CORRUPT'
)
foreach ($label in $requiredOperatorText) {
    if (-not $imageText.Contains($label)) {
        throw "Required operator-facing result label is missing: $label"
    }
}

[uint32]$sum = 0
for ($i = 0; $i -lt $bytes.Length; $i += 2) {
    $sum = ($sum + (([uint32]$bytes[$i] -shl 8) + [uint32]$bytes[$i + 1])) -band 0xffff
}
if ($sum -ne 0) { throw 'Static checksum verification failed' }

# The fixed core carries the complete original MegaDemo bank-18 payload,
# reassembled to execute from the sidecar's own U7 SRAM at >D000.  Its checksum
# protects the initializer, frame loop, collision helpers, sine table, color
# tables, and local callback stub as one indivisible visual-test asset.
$megaDemoPayload = [byte[]]$bytes[0x1876..0x1dad]
$megaDemoSha = [Security.Cryptography.SHA256]::Create()
try {
    $megaDemoHash = ($megaDemoSha.ComputeHash($megaDemoPayload) | ForEach-Object { $_.ToString('x2') }) -join ''
} finally {
    $megaDemoSha.Dispose()
}
if ($megaDemoPayload.Length -ne 0x538 -or
    $megaDemoHash -ne 'e6e875daa2f9828bd1b2442a859602e2b9515bb9e7284ef2e01a52673af8b474') {
    throw 'U7-relocated MegaDemo bank-18 payload at >F876 changed'
}

# Protect the exact 298-byte music phrase copied from the released Pyuuta/Tutor
# v1.0 diagnostic so the TI build cannot silently retune or regenerate it.
$megaDemoMusic = [byte[]]$bytes[0x1100..0x1229]
$megaDemoMusicSha = [Security.Cryptography.SHA256]::Create()
try {
    $megaDemoMusicHash = ($megaDemoMusicSha.ComputeHash($megaDemoMusic) | ForEach-Object { $_.ToString('x2') }) -join ''
} finally {
    $megaDemoMusicSha.Dispose()
}
if ($megaDemoMusic.Length -ne 298 -or
    $megaDemoMusicHash -ne '8306ab290862a634d778931e9b3a9de47e01e2a2e3c4ba0dc0ab382a1325baf7') {
    throw 'Pyuuta/Tutor v1.0 MegaDemo PSG phrase at >F100 changed'
}

$widePath = Join-Path $projectRoot 'build\ti99-sidecar-diag-w27c512.bin'
$wide = [IO.File]::ReadAllBytes($widePath)
if ($wide.Length -ne 65536) { throw 'Unexpected W27C512 image size' }
for ($bank = 0; $bank -lt 8; $bank++) {
    for ($i = 0; $i -lt 8192; $i++) {
        if ($wide[$bank * 8192 + $i] -ne $bytes[$i]) {
            throw "W27C512 bank $bank differs from the 8 KiB core at offset $i"
        }
    }
}

$extensionPath = Join-Path $projectRoot 'build\ti99-sidecar-extension-8k.bin'
$extension = [IO.File]::ReadAllBytes($extensionPath)
if ($extension.Length -ne 8192) { throw 'Unexpected extension size' }
if ([BitConverter]::ToString($extension[0..1]) -ne 'AA-01') {
    throw 'Unexpected 16K TI cartridge header'
}
if ([BitConverter]::ToString($extension[2..3]) -ne '01-00') {
    throw 'The 16K TI cartridge header does not advertise a program list'
}
if ([BitConverter]::ToString($extension[0x2a..0x2d]) -ne 'D1-A6-16-06') {
    throw 'Unexpected private extension signature/version at >602A'
}
$extensionEntry = ([uint32]$extension[0x2e] -shl 8) + [uint32]$extension[0x2f]
if ($extensionEntry -lt 0x6032 -or $extensionEntry -ge 0x7ffe) {
    throw ('Unexpected extension entry vector >{0:X4}' -f $extensionEntry)
}
if ([BitConverter]::ToString($extension[0x30..0x31]) -ne '01-01') {
    throw 'Unexpected extension fixed-core ABI requirement'
}
$fixedKeyboardTables = @{
    'TI-99/4A 6x8 matrix' = @{ Offset = 0x1f00; Hex = '3D-80-81-85-82-83-84-86-2E-4C-4F-39-32-53-57-58-2C-4B-49-38-33-44-45-43-4D-4A-55-37-34-46-52-56-4E-48-59-36-35-47-54-42-2F-3B-50-30-31-41-51-5A' }
    'TI-99/4 5x8 matrix'  = @{ Offset = 0x1f30; Hex = '81-4C-50-30-83-80-51-31-2C-4B-4F-39-5A-41-57-32-4D-4A-49-38-58-53-45-33-4E-48-55-37-43-44-52-34-42-47-59-36-56-46-54-35' }
    'TI-99/4 SHIFT map'   = @{ Offset = 0x1f58; Hex = '0D-3D-22-29-FF-20-51-21-2E-2F-2B-28-5A-41-57-40-3B-5E-2D-2A-58-53-45-23-3A-3C-5F-26-43-44-52-24-3F-47-3E-27-56-46-54-25' }
}
foreach ($tableName in $fixedKeyboardTables.Keys) {
    $table = $fixedKeyboardTables[$tableName]
    $expected = $table.Hex -split '-'
    $actual = [BitConverter]::ToString($extension[$table.Offset..($table.Offset + $expected.Count - 1)])
    if ($actual -ne $table.Hex) { throw "$tableName bytes moved or changed: $actual" }
}
$helperCopySetup = '02-00-D0-00-02-01-F8-76-02-02-05-38'
$extensionHex = [BitConverter]::ToString($extension)
$fctnLegendTable = '41-00-7C-00-43-00-60-00-46-00-7B-00-47-00-7D-00-49-00-3F-00-4F-00-27-00-50-00-22-00-52-00-5B-00-54-00-5D-00-55-00-5F-00-57-00-7E-00-5A-00-5C-00'
if (-not $extensionHex.Contains($fctnLegendTable)) {
    throw 'The complete twelve-entry TI-99/4A FCTN legend table changed or is missing'
}
if (-not $extensionHex.Contains($helperCopySetup)) {
    throw 'MegaDemo copy does not map the fixed-core payload at >F876 to U7 SRAM >D000'
}
foreach ($requiredVectorRead in @('C0-60-D0-00', 'C0-60-D0-02')) {
    if (-not $extensionHex.Contains($requiredVectorRead)) {
        throw "MegaDemo runtime vector read is missing: $requiredVectorRead"
    }
}
foreach ($forbiddenExpansionRead in @('C0-60-A0-00', 'C0-60-A0-02')) {
    if ($extensionHex.Contains($forbiddenExpansionRead)) {
        throw "MegaDemo still depends on optional 32K expansion RAM: $forbiddenExpansionRead"
    }
}
$extensionText = [Text.Encoding]::ASCII.GetString($extension)
$executableText = $imageText + $extensionText
$requiredExtensionText = @(
    '16 KiB Diagnostic BIOS v0.7',
    'TI-99/4 & 4A Diagnostic',
    'github.com/hexbus 9/2026',
    'BETA - USE WITH CAUTION',
    'SYSTEM INFORMATION',
    'KEYBOARD / JOYSTICKS',
    'VRAM TESTS',
    'SCREEN-PRESERVING TEST',
    'FULL MARCH-B TEST',
    'VDP PATTERN TEST',
    'WAVE + PSG MUSIC',
    'R WARM START',
    'IDENTIFY BAD VRAM IC',
    'SIDECAR / LED TEST',
    'CREDITS',
    'RELEASE ALPHA LOCK',
    'LIVE INPUTS; HOLD 0 TO EXIT.',
    'TRANSLATED CODE >',
    'Sprites: 8x8 / 16x16 / Mag',
    'ORIGINAL HW/SW: GEOFF TROTT',
    'NEW DIAG HW/SW: JON GUIDRY',
    'TUTOR WORK: JIM F, TAKEO N',
    'WAVE: MEGADEMO TEAM',
    'RASMUS, TURSI, OLD CS1',
    'ATARIAGE TI-99 COMMUNITY',
    'U109',
    'U102'
)
foreach ($label in $requiredExtensionText) {
    if (-not $executableText.Contains($label)) {
        throw "Required executable label is missing from core and extension: $label"
    }
}
[uint32]$extensionSum = 0
for ($i = 0; $i -lt $extension.Length; $i += 2) {
    $extensionSum = ($extensionSum + (([uint32]$extension[$i] -shl 8) + [uint32]$extension[$i + 1])) -band 0xffff
}
if ($extensionSum -ne 0) { throw 'Static extension checksum verification failed' }

# All framed Graphics-I pages have 30 writable interior columns.  These are
# the only deliberately wider strings, and they are used solely after the VDP
# has been switched to 40-column Text mode.  Catch accidental 32-column wraps
# at build time instead of discovering them on a physical console.
$sourceText = Get-Content -LiteralPath (Join-Path $projectRoot 'src\HEXDIAG.a99')
$extensionSourceText = Get-Content -LiteralPath (Join-Path $projectRoot 'src\HEXEXT.a99')
$wideTextModeLabels = @('VDTTX2', 'VDTTX3')
foreach ($line in @($sourceText) + @($extensionSourceText)) {
    if ($line -match "^([A-Za-z0-9]+)\s+text\s+'([^']*)'") {
        $label = $Matches[1]
        $literal = $Matches[2]
        if ($literal.Length -gt 29 -and $wideTextModeLabels -notcontains $label) {
            throw "32-column text '$label' is $($literal.Length) characters and can overwrite the frame"
        }
        if ($wideTextModeLabels -contains $label -and $literal.Length -gt 40) {
            throw "40-column text '$label' is $($literal.Length) characters and wraps"
        }
    }
}

$literalByLabel = @{}
foreach ($line in @($sourceText) + @($extensionSourceText)) {
    if ($line -match "^([A-Za-z0-9]+)\s+text\s+'([^']*)'") {
        $literalByLabel[$Matches[1]] = $Matches[2]
    }
}
$placementByLabel = @{}
$allSourceText = (@($sourceText) + @($extensionSourceText)) -join "`n"
$putPattern = '(?im)^\s*li\s+r0,>([0-9a-f]{4})[^\r\n]*\r?\n\s*li\s+r1,([A-Za-z0-9]+)[^\r\n]*\r?\n\s*bl\s+@(PUTS|PUTSTR)'
foreach ($match in [regex]::Matches($allSourceText, $putPattern)) {
    $address = [Convert]::ToInt32($match.Groups[1].Value, 16)
    $label = $match.Groups[2].Value
    if (-not $literalByLabel.ContainsKey($label)) { continue }
    $width = if ($label -in @('VDTTX1', 'VDTTX2', 'VDTTX3')) { 40 } else { 32 }
    $column = $address % $width
    $endColumn = $column + $literalByLabel[$label].Length - 1
    $lastWritableColumn = if ($width -eq 32) { 30 } else { 39 }
    if ($column -lt 0 -or $endColumn -gt $lastWritableColumn) {
        throw "Screen text '$label' at column $column ends at $endColumn and wraps or overwrites the frame"
    }
    $placementByLabel[$label] = $column
}

$centeredTitles = @(
    'TITLE', 'SUBTTL', 'MNTITL', 'MNSUB', 'KTITL', 'VRLABT', 'VRSCTT',
    'VRSRTT', 'VTITL', 'DTITL', 'VDRTTL', 'STITL', 'VITITL', 'LTITL',
    'CRTITL'
)
foreach ($label in $centeredTitles) {
    if (-not $placementByLabel.ContainsKey($label)) {
        throw "Centered page title '$label' has no directly verifiable screen placement"
    }
    $expectedColumn = [Math]::Floor((32 - $literalByLabel[$label].Length) / 2)
    if ($placementByLabel[$label] -ne $expectedColumn) {
        throw "Page title '$label' is at column $($placementByLabel[$label]); centered column is $expectedColumn"
    }
}

$directPath = Join-Path $projectRoot 'build\ti99-sidecar-diag-16k-w27c512.bin'
$direct = [IO.File]::ReadAllBytes($directPath)
if ($direct.Length -ne 65536) { throw 'Unexpected direct 16K W27C512 image size' }
for ($i = 0; $i -lt 65536; $i++) {
    $expected = 0xff
    if ($i -ge 0x6000 -and $i -lt 0x8000) { $expected = $extension[$i - 0x6000] }
    if ($i -ge 0xe000) { $expected = $bytes[$i - 0xe000] }
    if ($direct[$i] -ne $expected) {
        throw ('Direct 16K image differs at W27 offset >{0:X4}' -f $i)
    }
}

$beta07Path = Join-Path $projectRoot 'build\ti99-sidecar-diag-beta-0.7-16k-w27c512.bin'
$beta07 = [IO.File]::ReadAllBytes($beta07Path)
if ($beta07.Length -ne $direct.Length -or
    (Get-FileHash -LiteralPath $beta07Path -Algorithm SHA256).Hash -ne
    (Get-FileHash -LiteralPath $directPath -Algorithm SHA256).Hash) {
    throw 'The clearly named Beta 0.7 programmer image differs from the verified direct-16K image'
}

$tiSafePath = Join-Path $projectRoot 'build\HEXDIAG07.BIN'
$tiSafe = [IO.File]::ReadAllBytes($tiSafePath)
if ($tiSafe.Length -ne $direct.Length -or
    (Get-FileHash -LiteralPath $tiSafePath -Algorithm SHA256).Hash -ne
    (Get-FileHash -LiteralPath $directPath -Algorithm SHA256).Hash) {
    throw 'The TI-safe HEXDIAG07 programmer image differs from the verified direct-16K image'
}

Write-Output 'Static 27C64 layout, header, title, LOAD vector, marker, and checksum checks passed.'
Write-Output 'Operator-facing stock/custom firmware labels are present.'
Write-Output 'No executable source calls the console ROM KSCAN vector at >000E.'
Write-Output 'The fixed TI-99/4A matrix, TI-99/4 matrix, and TI-99/4 SHIFT maps are byte-exact.'
Write-Output 'All twelve printable TI-99/4A FCTN legend translations are byte-exact.'
Write-Output 'All eight W27C512 banks exactly match the 8 KiB core.'
Write-Output ('The executable 16K extension entry is >{0:X4} and requires core ABI 1.1.' -f $extensionEntry)
Write-Output 'The direct 16K W27C512 image has only >6000 and >E000 populated.'
Write-Output 'The Beta 0.7 and TI-safe programmer-image aliases exactly match that verified direct image.'
Write-Output 'All framed-page strings fit within 30 columns; Text-mode strings fit within 40.'
Write-Output 'All page titles use their computed centered columns.'
