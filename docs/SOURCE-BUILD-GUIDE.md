<!-- SPDX-License-Identifier: CC-BY-4.0 -->
# Beta 0.7 source and build guide

This guide is for anyone who wants to read, assemble, verify, or modify the
TI-99/4 and TI-99/4A Console Tester diagnostic. The checked-in assembly is the
source of truth. Generated files under `build/` should never be edited by hand.

## Source files

The active source names deliberately use short 8.3-style host filenames. The
basename also fits comfortably in the TI file system if the source is moved to
a TI disk; `.a99` remains the host-side assembly suffix.

- `src/HEXDIAG.a99` assembles the fixed 8 KiB core at `>E000->FFFF`.
  It contains the LOAD vector, automatic tests, text services, direct keyboard
  scanner, and extension ABI.
- `src/HEXEXT.a99` assembles the optional 8 KiB extension at `>6000->7FFF`.
  It contains the menu, interactive diagnostics, VDP/PSG demonstrations, and
  LED guide.
- `src/MEGAU7.a99` assembles the attributed MegaDemo raster controller that is
  copied to tester U7 SRAM and runs at `>D000->D537`.

The approved Beta 0.7 music stream is represented by the documented `MDPSG`
table in the fixed core. No extracted ROM dump or opaque runtime player is
required to assemble the public release.

## Requirements

- Windows PowerShell or PowerShell 7
- Python 3 available as `python`
- xdt99, including `xas99.py`

By default, the build expects xdt99 in a sibling directory:

```text
parent-directory/
|-- ti sidecar diag/
`-- xdt99/
    `-- xas99.py
```

If xdt99 is elsewhere, set `XAS99_PATH` to the full path of `xas99.py` before
running the build.

## One-command release build

On Windows, double-click `BUILD.CMD`, or run the canonical PowerShell driver
from the repository root:

```powershell
powershell -ExecutionPolicy Bypass -File .\build.ps1
```

`FILES.TXT` is the compact source manifest. `build.ps1` is the executable
master list: it names and assembles the three active source files in dependency
order. The traditional assembler listings are generated under `build/` as
`.lst` files; they are output for review and debugging, not build inputs.

The build script performs more than assembly. It also:

1. assembles the relocated MegaDemo payload and checks its size and entry
   vectors;
2. assembles the fixed core and extension as separate 8 KiB banks;
3. verifies headers, signatures, entry ranges, ABI version, and fixed vectors;
4. patches each bank's reserved checksum word to make its 16-bit word sum zero;
5. builds the sparse 64 KiB W27C512 programmer image;
6. writes a machine-readable manifest and short aliases such as
   `build/HEXDIAG07.BIN`.

For that reason, a raw assembler invocation is useful for development but is
not a complete release build.

## Verification

Run the static acceptance checks after every source change:

```powershell
powershell -ExecutionPolicy Bypass -File .\test.ps1
```

`VERIFY.CMD` is the double-clickable wrapper for the same verification command.

The tests reject accidental changes to the ROM layout, LOAD vector, extension
ABI, keyboard tables, VBlank gate, checksums, W27C512 composition, and other
release contracts. A final public build must also be exercised on
representative physical systems because raster timing, Alpha Lock sharing,
joystick selectors, LEDs, and the LOAD interrupt are hardware-facing tests.

## Assembler conventions

The source uses xdt99's TMS9900 syntax and the following conventions:

- hexadecimal values begin with `>`;
- byte values normally occupy the high byte of a register because `MOVB` and
  memory-mapped byte devices use that position;
- `BL` writes its return address to `R11`; a routine that performs nested calls
  must save the link in a named register or tester-SRAM cell;
- VDP control and data-port accesses retain conservative delay instructions
  required by real TMS9918-family hardware;
- `AORG` defines physical ROM addresses, while `XORG` in `MEGAU7.a99` defines
  the SRAM execution address of the relocated payload;
- all labels are eight characters or fewer, and source basenames are short so
  they remain practical on vintage and cross-development filesystems.

Comments above major routines document their purpose, inputs, outputs, saved
return link, and any hardware rule that must not be optimized away. Internal
loop labels are intentionally short and local to their surrounding routine.

## Fixed-core extension ABI

The extension never calls arbitrary labels in the fixed bank. It sets `R8` to
a documented service selector and calls the gateway at `>FE00`. The gateway
uses a branch for dispatch so the extension's `R11` return link survives.

The core advertises ABI version 1.1 beside the gateway marker. The extension
declares the same required version in its private header. If a change moves a
shared state cell, changes a selector's register contract, moves an exported
asset, or alters the gateway address, update the ABI deliberately and teach the
build and tests about the new version. Do not silently make the banks
incompatible.

## Release discipline

Before publishing another beta:

1. build and run the complete test suite;
2. confirm the programmer image is exactly 65,536 bytes;
3. record SHA-256 hashes for the release artifacts;
4. compare the intended bank layout with `docs/TECHNICAL-REFERENCE.md`;
5. test the LOAD path as well as the TI-99/4A cartridge-menu path; and
6. preserve the released source and binaries together under `release/`.

The Beta 0.7 behavior is hardware-validated. Comment-only cleanup should
assemble to byte-identical banks. Any machine-code difference is a functional
change and deserves a new test and an explicit release note.
