<!-- SPDX-License-Identifier: CC-BY-4.0 -->
# TI-99 Console Tester Public Beta 0.8

This is the hardware-validated public beta for the 16 KiB W27C512
modification of Geoff Trott's TI-99/4 and TI-99/4A Console Tester.

## Which file to program

Program **`HEXDIAG08.BIN`** into the W27C512 used by the tested 16 KiB
modification. It is the complete 65,536-byte image with the extension at
`>6000->7FFF`, the fixed core at `>E000->FFFF`, and unused space filled with
`>FF`.

Use **`HEX8K08.BIN`** for the first electrical/compatibility check. It repeats
the fixed core in all eight physical W27C512 banks so A13, A14, and A15 cannot
select different contents.

`HEXCORE8.BIN` and `HEXEXT08.BIN` are the two raw 8 KiB component images for
developers. They are not complete W27C512 programmer files.

## Before installation

1. Read `MANUAL08.PDF` and `HARDWARE.PDF`.
2. Compare the selected file with `SHA256.TXT`.
3. Program the entire device and run the programmer's verify pass.
4. Check the modification with the board unpowered.
5. Begin with the repeated-core image if the decoder or wiring is unproven.

The VRAM and memory tests are destructive. Do not run the diagnostic with
unsaved machine state.

## What changed in Beta 0.8

Beta 0.8 identifies TMS-family, F18A, Pico9918, and other F18A-compatible video
interfaces; keeps both joystick ports visible while giving a clear Alpha-Lock
advisory; and fully restores VDP and sprite-table state after every visual test.
It also adds strict AORG/XORG collision checking and protects the full font and
keyboard tables against accidental overlays. See `CHANGES08.PDF` for details.

The sprite page contains five entries but normally shows three groups at the
original four-sprites-per-line limit: the overlapping red/white collision pair,
cyan, and light blue. Yellow appears as a fourth group only when an enhanced VDP
is configured above that limit. This is not a Pico9918 problem and is not a
pass/fail condition.

## Qualification

The `HEXDIAG08.BIN` bytes passed the complete static acceptance suite and were
exercised on a stock TI-99/4A, TI-99/4QI V2.2, a GROMless TI-99/4A through the
LOAD recovery path, and a TI-99/4 fitted with a Pico9918. Observed video
interfaces included TMS family, F18A, and Pico9918.

## License and credit

Source and build tooling are Apache-2.0. Original documentation and illustrated
modification material are CC BY 4.0. The attributed MegaDemo-derived material
has the separate permission boundary described in the repository's
`docs/PROVENANCE.md`. The enhanced-VDP detector adapts code supplied by Troy
Schrapel under the MIT License; the complete notice is in `TROY-MIT.TXT`.

Credit **Jon Guidry (hexbus)** and link to the original project:
[github.com/hexbus/ti99-console-tester](https://github.com/hexbus/ti99-console-tester).
