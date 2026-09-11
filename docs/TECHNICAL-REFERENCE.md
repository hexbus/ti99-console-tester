<!-- SPDX-License-Identifier: CC-BY-4.0 -->
# Beta 0.7 technical reference

This is the authoritative technical description of the released diagnostic.
It combines the former address-map, 16 KiB ROM, firmware-checksum, and Beta 0.7
specification notes.

## Address map

| CPU address | Hardware or content | Notes |
| --- | --- | --- |
| `>0000->1FFF` | Console CPU ROM | Read twice for stability and identity |
| `>6000->7FFF` | Diagnostic extension | Cartridge header, menu, and interactive tests |
| `>8300->83FF` | Common scratchpad | Saved, tested, and restored |
| `>8400` | Sound write port | Muted at startup; driven by the PSG test |
| `>8800`, `>8802` | VDP read/status | Direct hardware access |
| `>8C00`, `>8C02` | VDP write/control | Direct hardware access |
| `>9800`, `>9C02` | GROM read/address | Stable-read and identity checks only |
| `>C000->DFFF` | Tester U7 SRAM | Workspace, results, and relocated demo code |
| `>E000->FFFF` | Fixed diagnostic core | Automatic tests and LOAD recovery |
| `>E002` on writes | Six-bit LED latch | Direction decode separates writes from ROM reads |
| `>FFFC->FFFF` | LOAD vector | Workspace `>C000`, entry `>FF00` |

The ordinary TI 32K expansion also drives `>C000->FFFF` and must not be present
while the tester owns U7 SRAM and U3 ROM. The raster controller runs from the
tester's own U7 SRAM at `>D000->D537`; it does not require optional RAM at
`>A000`.

## W27C512 layout

The tested 16 KiB modification is direct mapping, not bank switching. The
65,536-byte programmer file is sparse:

| File offsets / CPU addresses | Content |
| --- | --- |
| `>6000->7FFF` | 8 KiB interactive extension |
| `>E000->FFFF` | 8 KiB automatic core |
| all other offsets | `>FF` |

The fixed core validates the extension signature, version, entry range, ABI,
and zero word sum before calling it. A missing or corrupt extension cannot
prevent the automatic tests, LED report, LOAD path, or fixed-core result page.

The extension begins with a standard TI-99/4A cartridge header. Its menu entry,
`HEXBUS DIAG 1.0`, executes `BLWP @>FFFC`, the same vector used by the physical
LOAD switch. A TI-99/4 does not use that cartridge menu and starts through LOAD.

## Automatic test coverage

| Target | Coverage |
| --- | --- |
| TMS9900 | Representative arithmetic, logic, shift, compare, and branch paths |
| Tester SRAM | `>C100->DFFF`, excluding active workspace/result storage |
| Scratchpad | `>8300->83FF`, save/test/restore |
| VRAM | All `>0000->3FFF` bytes with `00`, `FF`, `AA`, and `55` |
| Console CPU ROM | `>0000->1FFF`, forward and reverse reads |
| Diagnostic core | Complete `>E000->FFFF` zero word sum |
| System GROMs | GROM 0, 1, and 2, two 6 KiB reads each |
| LED latch | Six-output walk followed by settled PASS/FAIL groups |

The VRAM test is destructive. A failure or power interruption cannot promise
that scratchpad state will be restored.

## Firmware identity and read health

Read health and firmware identity are deliberately separate. Two reads that do
not agree are a diagnostic failure. A stable custom, replacement, or mixed ROM
set is reported as information and is not colored or labeled as failed.

| Profile | CPU ROM word sum | GROM 0 byte sum | GROM 1 | GROM 2 |
| --- | ---: | ---: | ---: | ---: |
| TI-99/4 (1979) | `>F1BB` | `>B16C` | `>1B7B` | `>9EC3` |
| TI-99/4A (1981) | `>7D8C` | `>5574` | `>1B99` | `>9ADC` |
| TI-99/4QI V2.2 (1983) | `>7D8C` | `>31D7` | `>1B99` | `>9ADC` |

The CPU value is the modulo-65536 sum of 4096 big-endian words. Each GROM value
is the modulo-65536 sum of 6144 bytes. These compact runtime identifiers are not
catalog-file CRC or SHA hashes.

## Keyboard and joystick ownership

The diagnostic does not call the console ROM keyboard vector at `>000E` and
does not call a GROM routine. It scans the TMS9901 directly, using separate
translation tables for the five-column TI-99/4 keyboard and six-column
TI-99/4A keyboard. Unknown or GROMless recovery systems default to the /4A
table so menu input remains available.

The TI-99/4 uses joystick selector columns 5 and 6. The TI-99/4A and QI use
columns 6 and 7. The page reports modifier state separately from translated
characters, recognizes two-key chords plus Alpha Lock, and never executes QUIT
or other console actions while the diagnostic is active.

## Video and sprite contract

The TI-99/4 skips the Graphics-II bitmap stage because its original TMS9918
does not support that mode. Text, character, Multicolor, sprite, and raster
tests remain available. Operator-facing screens say `VDP`; they do not infer a
specific VDP model from display behavior.

The sprite exercise writes five same-scanline entries to the sprite attribute
table at `>0300`, using pattern table `>1800`. Sprites 0 and 1 overlap for the
collision condition; sprites 2 and 3 are separate; sprite 4 exercises the
four-per-line limit. The expected original-family display is three visible
groups, with collision and fifth-sprite flags set. Replacement VDPs may differ,
so the result page reports flags as observations rather than pass/fail claims.

Every return from a video exercise blanks the display, restores all eight UI
registers, rebuilds the font, colors, frame, and sprite terminator, and only
then enables display. This ownership boundary prevents demo sprites or table
selections from corrupting later pages.

## Beta 0.7 qualification

The exact public programmer image passed the static acceptance checks and the
59-case internal emulator regression suite. It was then exercised on stock
TI-99/4A, TI-99/4QI V2.2, GROMless TI-99/4A LOAD recovery, and a TI-99/4 fitted
with a Pico9918. This is a public beta because the sample of original and
replacement VDP hardware remains limited.
