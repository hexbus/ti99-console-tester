<!-- SPDX-License-Identifier: CC-BY-4.0 -->
# Console Tester ROM modification guide

This single guide covers every current expansion of the SHIFT838/Geoff Trott
Console Tester V1: the working 16K diode adapter, permanent 16K LS21 version,
two clean 32K choices, homebrew 32K diode option, practical 40K maximum that
retains tester RAM, and the more difficult 48K and banked alternatives. Because
the tester is used by itself, the mappings prioritize dependable diagnostic ROM
space rather than coexistence with a cartridge, DSR, or ordinary 32K expansion.

## Read this first

The PCB artwork and photographs establish the intended routes; continuity on
the assembled board remains the final authority. Switch the console off before
inserting or removing the sidecar or EPROM, and make resistance/continuity
measurements only with the board disconnected.

Never directly join 74LS138 outputs: they are active-low push-pull outputs.
Combine them only with the LS21 or documented Schottky-diode network.

The current adapter has a 28-pin W27C512 with four pins lifted or folded clear
of the U3 socket:

| W27C512 pin | Signal | Connection |
| ---: | --- | --- |
| 1 | A15 | U2 pin 3, TI A0, address weight `>8000` |
| 20 | `/CE` | New combined ROM-select node |
| 26 | A13 | U2 pin 1, TI A2, address weight `>2000` |
| 27 | A14 | U2 pin 2, TI A1, address weight `>4000` |

All other pins remain in the socket: pin 28 is +5 V, pin 14 is ground, and pin
22 `/OE` retains the board's read-qualified path. From above, pin 1 is upper
left with the single notch at top. Prefer a turned-pin carrier to repeatedly
bending the W27C512's own legs.

## Board and decoder map

The photographed 2024 PCB contains:

| Reference | Fitted device | Relevant function |
| --- | --- | --- |
| U1 | SN74LS174AN | Six-bit indicator latch |
| U2 | 74LS138N | Eight active-low 8K address selects |
| U3 | 28-pin 27C64 socket | Original 8K diagnostic ROM |
| U4 | 74LS373N | Board latch/buffer |
| U5 | 74ALS02N | NOR logic |
| U6 | 74ALS00N | NAND logic |
| U7 | AS6C6264-55PCN | 8K tester SRAM at `>C000->DFFF` |

There is no LS21 on the photographed PCB; any LS21 in this guide is an added
part. U2 decodes TI A0-A2 as follows:

| U2 output | U2 pin | CPU range | Normal use in this project |
| --- | ---: | --- | --- |
| Y0 | 15 | `>0000->1FFF` | Console CPU ROM; never claim |
| Y1 | 14 | `>2000->3FFF` | Optional ROM window |
| Y2 | 13 | `>4000->5FFF` | Optional ROM window; normally DSR space |
| Y3 | 12 | `>6000->7FFF` | 16K diagnostic extension |
| Y4 | 11 | `>8000->9FFF` | Scratchpad/MMIO; never claim |
| Y5 | 10 | `>A000->BFFF` | Optional ROM window |
| Y6 | 9 | `>C000->DFFF` | Existing U7 tester SRAM |
| Y7 | 7 | `>E000->FFFF` | Fixed boot core and LOAD vector |

The W27C512 uses conventional address numbering while TI names the most
significant CPU address bit A0. The direct linear mapping is therefore:

```text
W27 A0  <- TI A15      byte weight >0001
...
W27 A12 <- TI A3       byte weight >1000
W27 A13 <- TI A2       byte weight >2000
W27 A14 <- TI A1       byte weight >4000
W27 A15 <- TI A0       byte weight >8000
```

Changing only A13-A15 does not add a CPU window. It makes W27 file offsets
match CPU addresses. The `/CE` decoder determines which 8K CPU windows are
actually visible.

## Options at a glance

| Configuration | Direct ROM | Added parts | Selected windows | Recommendation |
| --- | ---: | --- | --- | --- |
| Original/repeated W27 | 8K | none beyond carrier wiring | Y7 | Electrical bring-up only |
| W27 two-diode trial | 16K | 2 Schottky diodes, 2.2K | Y3, Y7 | Proven temporary setup |
| W27 + LS21 | 16K | 1 SN74LS21, bypass capacitor | Y3, Y7 | Permanent 16K version |
| W27 + LS21 | 32K | same LS21, one gate | Y1, Y3, Y5, Y7 | Clean W27 expansion |
| W27 four-diode trial | 32K | 4 Schottky diodes, 2.2K | Y1, Y3, Y5, Y7 | Homebrew/qualification only |
| 27C256 + LS21 | 32K | 1 SN74LS21, bypass capacitor | Y1, Y3, Y5, Y7 | Simplest dedicated 32K board |
| W27 + cascaded LS21 gates | 40K | same one LS21 package | Y1, Y2, Y3, Y5, Y7 | Maximum clean direct ROM with U7 |
| W27 + Y6 | 48K | decoder still fits one LS21 | Y1, Y2, Y3, Y5, Y6, Y7 | Experimental; requires U7/workspace redesign |

The 16K, 32K, and 40K configurations retain U7 SRAM and the diagnostic's
fail-safe workspace. The 40K configuration is still relatively clean: one
W27C512, one LS21 package, and additional decoder wires. The 48K configuration
is where the design becomes substantially more complicated because ROM and U7
would otherwise drive `>C000->DFFF` at the same time.

## Scenario 1: current temporary 16K W27C512 diode adapter

This is the physically proven public-beta configuration: Y3 and Y7 feed a
pulled-up `/CE` node through two Schottky diodes, exposing the extension at
`>6000` and the fixed core at `>E000` while retaining U7 SRAM at `>C000`.

The complete illustrated parts list, pin-by-pin wiring sequence, diode
orientation, continuity checklist, programming steps, and first-power test
now have one authoritative home in the
[v0.7 operator and modification manual](HEXBUS-DIAGNOSTIC-MANUAL.md#16-kib-w27c512-hobby-modification).
Use that procedure for the working two-diode build. The remaining scenarios
in this document are alternatives for permanent or larger-capacity boards.

## Scenario 2: permanent 16K W27C512 with one SN74LS21

The SN74LS21 contains two four-input positive-AND gates. Because U2 selections
are active low, ANDing Y3 and Y7 produces a low ROM `/CE` in either selected
range:

```text
/CE_ROM = Y3 AND Y7 AND HIGH AND HIGH
```

Wire the first gate:

| LS21 pin | Connection |
| ---: | --- |
| 1 | U2 pin 12/Y3, CPU `>6000->7FFF` |
| 2 | U2 pin 7/Y7, CPU `>E000->FFFF` |
| 4, 5 | Defined HIGH, directly to +5 V or through a shared 1K-4.7K pull-up |
| 6 | Lifted W27 pin 20 `/CE` |
| 7 | Ground |
| 14 | +5 V |
| 9, 10, 12, 13 | Ground unused second-gate inputs |
| 8 | Leave unused second-gate output open |
| 3, 11 | Package no-connect pins; leave open |

Fit a 0.1 uF ceramic capacitor directly between LS21 pins 14 and 7. The three
W27 high-address wires remain exactly as shown at the start of this guide.

## Scenario 3: 32K W27C512 with one LS21 gate

This is the clean way to keep the W27C512 and expose 32K. Use four decoder
outputs in the first LS21 gate:

```text
LS21 pin 1 <- U2 pin 14/Y1  >2000
LS21 pin 2 <- U2 pin 12/Y3  >6000
LS21 pin 4 <- U2 pin 10/Y5  >A000
LS21 pin 5 <- U2 pin  7/Y7  >E000
LS21 pin 6 -> lifted W27 pin 20 /CE
```

The W27 address wires stay unchanged, so the sparse 64K programmer file uses
the same offsets as CPU addresses:

| W27 file offsets | CPU range |
| --- | --- |
| `>2000->3FFF` | `>2000->3FFF` |
| `>6000->7FFF` | `>6000->7FFF` |
| `>A000->BFFF` | `>A000->BFFF` |
| `>E000->FFFF` | `>E000->FFFF` |

U7 remains at `>C000`, and DSR space at `>4000` remains unclaimed. The tester
must still be used without a normal 32K expansion or cartridge because those
devices contend with ranges already owned by the tester.

### Homebrew four-diode 32K variant

A temporary 32K W27 adapter can use four matched Schottky diodes instead of
the first LS21 gate. Keep the same common pulled-up `/CE` anode node used by
the working 16K circuit and add banded cathode branches to U2 Y1, Y3, Y5, and
Y7:

```text
                               +5 V
                                 |
                                2.2K
                                 |
lifted W27 pin 20 /CE -----------+---- common unbanded-anode node
                                 |
             +-------------------+-------------------+-------------------+
             |                   |                   |                   |
          diode               diode               diode               diode
             |                   |                   |                   |
      band to Y1/p14      band to Y3/p12      band to Y5/p10       band to Y7/p7
          >2000               >6000               >A000               >E000
```

Four branches add leakage and capacitance. Re-measure `/CE` HIGH and LOW in
every selected and unselected window and inspect edges with a scope. This is a
valid homebrew experiment, not the recommended production circuit.

## Scenario 4: dedicated 32K 27C256 with one LS21

If 32K is the final target, a JEDEC-pinout 27C256 is the simplest dedicated
solution. It needs only three isolated EPROM pins:

| 27C256 pin | Signal | Connection |
| ---: | --- | --- |
| 20 | `/CE` | LS21 pin 6 |
| 26 | A13 | U2 pin 2, TI A1 |
| 27 | A14 | U2 pin 3, TI A0 |

Pin 1 remains seated only after U3 socket pin 1 is verified as +5 V, because
the 27C256 requires VPP at VCC during reads. All other pins remain in the
socket.

Use the first LS21 gate:

| LS21 pin | Connection |
| ---: | --- |
| 1 | U2 pin 14/Y1, `>2000` |
| 2 | U2 pin 12/Y3, `>6000` |
| 4 | U2 pin 10/Y5, `>A000` |
| 5 | U2 pin 7/Y7, `>E000` |
| 6 | Lifted 27C256 pin 20 `/CE` |
| 7, 14 | Ground, +5 V respectively |

As with the 16K circuit, bypass pins 14 and 7 with 0.1 uF and tie every unused
TTL input to a defined level.

The 27C256 programmer file is a packed 32K image, not a sparse W27 image:

| 27C256 file offsets | Visible at CPU |
| --- | --- |
| `>0000->1FFF` | `>2000->3FFF` |
| `>2000->3FFF` | `>6000->7FFF` |
| `>4000->5FFF` | `>A000->BFFF` |
| `>6000->7FFF` | `>E000->FFFF` |

Never program a 64K W27C512 image unchanged into this layout. Generate and
verify a separately packed 32768-byte image.

## Scenario 5: 40K W27C512 with the same LS21 package

Forty kilobytes is the maximum directly visible ROM that retains U7 tester
SRAM. It occupies `>2000`, `>4000`, `>6000`, `>A000`, and `>E000`. Five
active-low inputs require both four-input gates inside the one LS21 package:

```text
gate 1:
  LS21 pin 1 <- U2 pin 14/Y1  >2000
  LS21 pin 2 <- U2 pin 13/Y2  >4000
  LS21 pin 4 <- U2 pin 12/Y3  >6000
  LS21 pin 5 <- U2 pin 10/Y5  >A000
  LS21 pin 6 -> X

gate 2:
  LS21 pin 9  <- X from pin 6
  LS21 pin 10 <- U2 pin 7/Y7   >E000
  LS21 pins 12 and 13 <- defined HIGH
  LS21 pin 8 -> lifted W27 pin 20 /CE
```

The W27 high-address wiring and same-offset 64K file layout remain unchanged.
This uses DSR space at `>4000`, which is acceptable for a standalone tester.
Validate the additional gate delay and all five `/CE` cases on hardware.

## Scenario 6: why direct 48K is different

Adding U2 Y6 would expose a sixth block at `>C000->DFFF`, but U7 already owns
that range. Selecting both devices would cause bus contention. A 48K version
must disable or remove U7 and rewrite the firmware so its LOAD workspace,
early RAM test, and fail-safe LED reporting no longer depend on `>C000`.

The decoder still fits in the existing LS21 cascade by replacing one of the
second gate's HIGH inputs with Y6, but that fact does not make the complete
48K conversion simple. Do not wire Y6 with the current firmware.

## Banked alternatives

Banking leaves the CPU map mostly intact and pages several physical 8K W27
blocks through one aperture. It needs a reset-defined latch and bank-aware
software, so it is not easier than the current direct 16K arrangement.

| Stored ROM | Bank bits | Typical added storage logic |
| ---: | ---: | --- |
| 16K | 1 | One 74LS74 section or one wider-latch bit |
| 32K | 2 | Two defined latch bits |
| 64K | 3 | 74LS378, 74LS174, or equivalent three-bit latch |

Execute the bank-change trampoline from U7 RAM, provide a known entry in every
bank, and retain a valid boot/LOAD vector in every possible power-up bank
unless the latch has a proven reset state. A bank latch must not interfere with
the existing LED-latch write at `>E002`.

## Programmer images and staged bring-up

For the current 16K W27 hardware, use these project outputs:

| File | Purpose |
| --- | --- |
| `build/ti99-sidecar-diag-w27c512.bin` | First electrical test: eight identical copies of the 8K core |
| `build/ti99-sidecar-diag-beta-0.7-16k-w27c512.bin` | Current sparse 16K build: extension at `>6000`, fixed core at `>E000` |
| `build/HEXDIAG07.BIN` | Byte-identical TI-safe short filename for the Beta 0.7 programmer image |

Select W27C512 in the programmer, erase and blank-check it, program the entire
65536-byte file, and run verify. Do not treat either raw 8K component image as
an already positioned 64K programmer file. Record the SHA-256 from
`build/manifest.json` for the exact build placed in a device.

Bring up any new circuit in stages:

1. Reconfirm the unmodified board with its known-working 27C64.
2. Check every lifted pin and wire with power off.
3. Use the repeated-core image first. Confirm boot, LOAD, LED walk, screen, and
   U7 RAM before executing from a new window.
4. Confirm `/OE` is inactive on writes, especially the LED write at `>E002`.
5. Probe `/CE` in each intended and unintended 8K range.
6. Program the correctly laid-out final image only after the electrical test
   passes.
7. For the current 16K build, `16K EXTENSION PRESENT` proves the A13-A15
   mapping, Y3/Y7 selection, extension signature, and full extension checksum.
   `CORRUPT` indicates a real programming, decoding, or ROM read-path fault.

Do not attach a cartridge, memory expansion, or another sidecar during initial
qualification.

## Unpowered verification checklist

For a W27C512 carrier, verify:

- W27 pins 1, 20, 26, and 27 do not contact their same-numbered U3 pads;
- W27 pin 1 reaches only U2 pin 3 among the three address pickups;
- W27 pin 27 reaches U2 pin 2;
- W27 pin 26 reaches U2 pin 1;
- W27 pin 20 reaches only the new `/CE` output/common node;
- W27 pin 22 remains connected to the original `/OE` path;
- W27 pins 28 and 14 reach +5 V and ground respectively;
- selected U2 outputs are not shorted to one another;
- no lifted contact can touch its former pad or an adjacent pin; and
- resistance between +5 V and ground does not indicate a short.

For an LS21 circuit, also verify pin 14 to +5 V, pin 7 to ground, the correct
gate output to lifted EPROM pin 20, defined levels on every unused input, and
the 0.1 uF bypass capacitor. For a diode circuit, verify diode polarity and the
2.2K path from the common `/CE` node to +5 V.

## Capacity decision

- Keep the working **16K diode** adapter for immediate firmware development.
- Use the **16K LS21** circuit for a permanent version of the proven map.
- Choose **32K W27C512** when retaining the existing device and direct file
  offsets matters.
- Choose **32K 27C256** for the smallest clean dedicated fixed-capacity board.
- Choose **40K W27C512** when one logic package and a few more wires are worth
  the extra space; it is the practical maximum without sacrificing U7.
- Treat **48K direct** and **banked ROM** as later redesigns, not incremental
  changes to the current firmware.

See the [technical reference](TECHNICAL-REFERENCE.md) for the board's base
memory use and firmware contract independent of the physical modification.
