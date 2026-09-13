<!-- SPDX-License-Identifier: CC-BY-4.0 -->
# Console Tester technical reference

This is the authoritative technical description of the released and
hardware-validated Public Beta 0.8 diagnostic.

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

Alpha Lock is advisory rather than a joystick lockout. Both joystick selectors
are always scanned and displayed. On the
/4A-family path, Alpha Lock down adds `JOYSTICKS: RELEASE ALPHA LOCK` because
the original /4A wiring can interfere with joystick Up. A QI may continue to
show valid Up input. The /4 path omits the message because it has no Alpha Lock.
The switch probe and joystick reads remain independent so joystick Up cannot by
itself create the advisory.

P5 state during the joystick reads is intentional. With Alpha Lock released,
the /4A-family path holds P5 low across both selector reads. Testing on a
GROMless /4A showed that restoring P5 high masked the shared INT7 Up input on
both joystick ports. With Alpha Lock down, P5 remains high so the switch cannot
be mistaken for Up. The TI-99/4 path also retains its normal P5-high state.

## Video and sprite contract

The TI-99/4 skips the Graphics-II bitmap stage because its original TMS9918
does not support that mode. Text, character, Multicolor, sprite, and raster
tests remain available. Operator-facing screens say `VDP`; they do not infer a
specific VDP model from display behavior.

The sprite exercise writes five same-scanline entries to the sprite attribute
table at `>0300`, using pattern table `>1800`. Red sprite 0 and white sprite 1
exactly overlap for the collision condition. Red has priority, so the pair
looks like one clean red object instead of a damaged composite. Cyan and
light-blue sprites 2 and 3 are separate. Yellow sprite 4 exercises the
four-per-line limit.

At the original four-sprites-per-scanline limit, the expected display is three
visible groups: the red collision pair, cyan, and light blue. Yellow is suppressed
and the fifth-sprite flag is set. An F18A or Pico9918 configured for an expanded
limit may display yellow. Collision and fifth-sprite flags remain observations,
not independent pass/fail claims.

Every return from a video exercise blanks the display and resets the VDP
control latch. It then erases both sprite attribute areas owned by the tester:
the diagnostic SAT at `>0300` and the MegaDemo timing SAT at `>3800`. After
restoring all eight UI registers, it rebuilds the font, colors, and frame,
terminates both SATs again, and only then enables display. This ownership
boundary prevents demo sprites or table selections from corrupting later pages.

## Enhanced VDP identification

The startup screen identifies an enhanced programming interface without
claiming that software can distinguish every original TMS
die. A legacy result is deliberately shown as `TMS FAMILY`, not specifically
`TMS9918` or `TMS9918A`.

The probe follows Troy Schrapel's published F18A/Pico9918 method:

1. Disable display interrupts in VDP register 1, then write `>1C` twice to
   enhanced register 57 to request unlock.
2. Restore register 1 and place the six-byte GPU program
   `04 E0 3F 00 03 40` at VRAM `>3F00`. This is `CLR @>3F00; IDLE`.
3. Start the GPU at `>3F00`, wait for at most one bounded frame interval, and
   read that VRAM byte. A legacy TMS VDP only stores the bytes, leaving `>04`;
   a compatible GPU executes them and changes the byte to zero.
4. Only after that positive execution proof, read enhanced status register 1
   for the implementation signature. Restore the status selector to register 0.
5. Reset and relock the enhanced interface through register 50, then restore
   all eight legacy registers before the destructive VRAM test and normal UI.

Status 1 masked with `>E8` equal to `>E8` identifies Pico9918. Otherwise,
status 1 masked with `>E0` equal to `>E0` identifies a genuine F18A. Another
GPU-compatible response is displayed conservatively as `F18A COMPAT`. The
method and original CVBasic example are documented in [Troy Schrapel's
AtariAge post](https://forums.atariage.com/topic/374821-detect-f18a-pico9918-9918-9938-and-other-revisions/#findComment-5564615)
and the [Pico9918 project](https://github.com/visrealm/pico9918).

The diagnostic deliberately does not display status register 14 as a device
firmware version. On both F18A and Pico9918 it reports the F18A-compatibility
version. Reading a Pico9918's complete firmware and hardware versions requires
the Pico9918 configuration-register interface and is outside this identity test.

The two register-57 writes are intentionally emitted as complete direct VDP
control-port transactions. The shared register helper byte-swaps its input as
part of normal use, so reusing one loaded value for two helper calls would not
send two identical writes and would silently prevent the unlock.

## Beta 0.8 qualification

The exact public programmer image passed the complete static acceptance suite,
including checks of all 16 AORG/XORG regions, both ROM checksums, the full font,
keyboard tables, VDP probe transactions, sprite table, and W27C512 composition.
It was then exercised on stock TI-99/4A, TI-99/4QI V2.2, GROMless TI-99/4A LOAD
recovery, and a TI-99/4 fitted with a Pico9918. VDP observations included a
TMS9918-family device, an F18A, and a Pico9918. This remains a public beta
because the sample of original and replacement hardware is necessarily limited.
