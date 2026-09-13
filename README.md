<!-- SPDX-License-Identifier: CC-BY-4.0 -->
# TI-99 Console Tester Diagnostic

Public Beta 0.8 is a self-contained diagnostic BIOS for Geoff Trott's Console
Tester hardware. It supports the TI-99/4, TI-99/4A, TI-99/4QI V2.2, and a
TI-99/4A with missing or damaged GROMs. The LOAD switch can start the diagnostic
without relying on the console's title screen or keyboard service.

> **IMPORTANT: THE FULL DIAGNOSTIC REQUIRES A HARDWARE MODIFICATION.** Geoff
> Trott's original Console Tester is wired for a single 8 KiB EPROM at `>E000`.
> It must be modified to accept the additional 8 KiB diagnostic window at
> `>6000` before you install and use `HEXDIAG08.BIN`. Do not place the full
> 16 KiB diagnostic image into an unmodified board. Follow the illustrated
> [16 KiB hardware modification guide](docs/HARDWARE-MODIFICATION-GUIDE.md)
> before programming or installing the replacement device.

The fixed 8 KiB core performs automatic CPU, tester SRAM, scratchpad, VRAM,
console ROM/GROM read-path, diagnostic ROM, and LED checks. The optional second
8 KiB window adds readable results and interactive keyboard, joystick, video,
sound, VRAM, LED, and identification tests. The original TI-99/4 correctly
skips the unsupported Graphics-II bitmap stage.

> **BETA - USE WITH CAUTION.** The VRAM and memory tests are destructive. Power
> off before fitting or removing the tester, and do not run it with unsaved
> work. Verify every modification with the board unpowered before installing an
> EPROM.

## Download and program Beta 0.8

The current release is in [`release/beta-0.8`](release/beta-0.8/README.md).

- Program `HEXDIAG08.BIN` into a W27C512 for the tested 16 KiB modification.
- Use the repeated-core compatibility image first when bringing up an
  unmodified 8 KiB board or checking the original `>E000` decode.
- Verify the programmed device against `SHA256.TXT` before installation.

The 16 KiB programmer image is 65,536 bytes. It places the menu extension at
`>6000->7FFF`, the fail-safe core at `>E000->FFFF`, and fills unused space with
`>FF`. Do not program either raw 8 KiB component file as if it were the complete
W27C512 image.

## Build from source

Requirements:

- Windows PowerShell or PowerShell 7;
- Python 3; and
- [xdt99](https://github.com/endlos99/xdt99), normally checked out beside this
  repository.

Run `BUILD.CMD` to assemble the release. Run `VERIFY.CMD` to rebuild it and
check the headers, memory layout, vectors, fixed tables, checksums, release
aliases, and screen-text placement. Set `XAS99_PATH` if `xas99.py` is not in a
sibling `xdt99` directory.

The active assembly order is listed in [`FILES.TXT`](FILES.TXT). The sources
use short, TI-friendly basenames and retain `.a99` as their host-side suffix:

1. `src/MEGAU7.a99` - relocated raster controller for tester U7 SRAM;
2. `src/HEXDIAG.a99` - fixed 8 KiB core at `>E000`; and
3. `src/HEXEXT.a99` - optional 8 KiB extension at `>6000`.

See the [source and build guide](docs/SOURCE-BUILD-GUIDE.md) before changing
addresses or shared services. A distributable image must be made by
`build.ps1`; a raw assembler invocation does not patch the zero-sum words or
compose the W27C512 layout.

## Documentation

- [Operator manual](docs/HEXBUS-DIAGNOSTIC-MANUAL.md) - setup, startup, menus,
  lamp meanings, and troubleshooting
- [Hardware modification guide](docs/HARDWARE-MODIFICATION-GUIDE.md) - tested
  16 KiB wiring and 32K, 40K, and later redesign options
- [Source and build guide](docs/SOURCE-BUILD-GUIDE.md) - source map, ABI, build,
  verification, and release procedure
- [Assembly memory map](docs/MEMORY-MAP.md) - every checked AORG/XORG region,
  occupied range, and remaining headroom
- [Changelog](CHANGELOG.md) - functional, verification, and documentation
  changes in each public beta
- [Technical reference](docs/TECHNICAL-REFERENCE.md) - address map, tests,
  firmware profiles, and Beta 0.8 qualification
- [Lessons learned](docs/LESSONS-LEARNED.md) - causes and guards for the major
  keyboard, VDP, sprite, timing, and packaging faults
- [Provenance and licensing](docs/PROVENANCE.md) - original work, permitted
  third-party material, and attribution
- [Backlog](docs/BACKLOG.md) - investigations intentionally deferred beyond
  the frozen Beta 0.8 image

PDF copies are provided under `output/pdf/` for readers who prefer a printable
manual.

## Compatibility status

Beta 0.8 has been exercised on a stock TI-99/4A, a TI-99/4QI V2.2, a GROMless
TI-99/4A using LOAD recovery, and a TI-99/4 fitted with a Pico9918. The `/4`
joystick selectors are columns 5 and 6; the `/4A` family uses columns 6 and 7.
The sprite page shows three visible groups at the original four-sprites-per-line
limit. An F18A or Pico9918 configured for a higher limit may also show the
yellow fifth entry; that is a configuration difference, not a failure.

## Licensing and credit

Source code and build/test tooling are Apache-2.0. Original documentation and
the illustrated modification material are CC BY 4.0. MegaDemo-derived material
has its own permission and attribution boundary. The enhanced-VDP detector
adapts MIT-licensed code supplied by Troy Schrapel; see
[`LICENSE.md`](LICENSE.md), [`NOTICE`](NOTICE), and
[`docs/PROVENANCE.md`](docs/PROVENANCE.md).

Please credit **Jon Guidry (hexbus)** and point readers back to the canonical
project: [github.com/hexbus/ti99-console-tester](https://github.com/hexbus/ti99-console-tester).
