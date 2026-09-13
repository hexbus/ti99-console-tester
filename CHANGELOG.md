<!-- SPDX-License-Identifier: CC-BY-4.0 -->
# Changelog

## Public Beta 0.8 - September 2026

### Diagnostic behavior

- Added bounded F18A-compatible GPU detection and status-register
  identification for `TMS FAMILY`, `F18A`, `PICO9918`, and `F18A COMPAT`.
  Pico9918 firmware versions are intentionally not displayed because the F18A
  compatibility register is not the Pico firmware version.
- Revised the five-sprite page so the intentional red/white collision pair
  appears as one clean red object. Original four-sprites-per-line operation
  shows three visible groups; a higher configured limit may also show yellow.
- Made Alpha Lock an advisory instead of blocking joystick display. The `/4A`
  path keeps P5 low while Alpha Lock is released so both joystick Up inputs
  remain readable, and keeps it high while Alpha Lock is down to avoid a false
  Up indication. `/4` selectors remain columns 5 and 6.
- Restored the complete text-mode VDP state after every visual test and erased
  both the diagnostic and MegaDemo sprite tables before showing another page.

### Build and verification

- Added a checked map for every AORG/XORG region and rejects new, moved,
  backward, overlapping, or oversized blocks during the build.
- Moved shared strings out of the font and fixed keyboard-table ranges.
- Added byte-exact guards for the complete font, keyboard tables, enhanced-VDP
  transactions, sprite table, P5 joystick policy, checksums, and programmer
  image composition.
- Added a machine-readable verified region map to `build/manifest.json`.

### Documentation

- Added an assembly memory map and expanded source comments around hardware
  timing, VDP ownership, sprite limits, and the TMS9901 P5/INT7 relationship.
- Added a visual explanation of the expected sprite groups and clarified that
  yellow indicates the configured scanline limit rather than pass/fail status.
- Updated the operator, build, technical, hardware, and troubleshooting guides
  for the frozen 0.8 image.

### Qualification

The release image passed the complete static acceptance suite and was exercised
on a stock TI-99/4A, TI-99/4QI V2.2, GROMless TI-99/4A through LOAD recovery,
and TI-99/4 hardware fitted with a Pico9918. Observed VDP interfaces included
TMS family, F18A, and Pico9918. Original-limit TMS and Pico operation displayed
three sprite groups; an F18A configured above that limit displayed yellow as a
fourth group.

## Public Beta 0.7 - September 2026

- Established the self-contained 8 KiB automatic core and optional 8 KiB menu
  extension for the 16 KiB W27C512 hardware modification.
- Added direct keyboard and joystick scanning without relying on console GROM
  services, including TI-99/4 and TI-99/4A matrix tables.
- Added the automatic test summary, interactive diagnostics, LOAD recovery,
  release manifest, hashes, source build, and printable documentation.
