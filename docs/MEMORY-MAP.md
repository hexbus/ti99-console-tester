<!-- SPDX-License-Identifier: CC-BY-4.0 -->
# Assembly memory map

This is the authoritative map of every absolute-origin block in Public Beta
0.8. Addresses in the **End** column are inclusive. The build
does not trust `AORG` by itself: `build.ps1` reads the start and end labels from
the assembler listings and fails if a block moves, grows into the next block,
or if an unreviewed `AORG` is added.

The same measured regions are written to `build/manifest.json` after every
successful build. That generated copy uses end-exclusive addresses so its byte
counts can be checked directly.

## Direct-mapped 16 KiB image

| CPU address | Size | Owner |
|---|---:|---|
| `>6000->7FFF` | 8 KiB | Interactive extension ROM |
| `>C000->CFFF` | 4 KiB | Tester U7 SRAM workspace and diagnostic state |
| `>D000->D537` | 1,336 bytes | Relocated raster-effect runtime in tester U7 SRAM |
| `>D538->DFFF` | 2,760 bytes | Unused upper U7 SRAM |
| `>E000->FFFF` | 8 KiB | Automatic/fail-safe core ROM |

The W27C512 programmer image stores the extension at physical file offset
`>6000`, the core at `>E000`, and `>FF` everywhere else.

## Fixed core: `src/HEXDIAG.a99`

| Start | End | Used | Free before next block | Contents |
|---:|---:|---:|---:|---|
| `>E000` | `>F0AD` | 4,270 | 82 | Header, automatic tests, services, text, and private 96-character font |
| `>F100` | `>F229` | 298 | 0 | Exact MegaDemo PSG phrase |
| `>F22A` | `>F3F1` | 456 | 340 | Enhanced-VDP detector and shared extension strings |
| `>F546` | `>F861` | 796 | 20 | VDP assets and keyboard-matrix helpers |
| `>F876` | `>FDAD` | 1,336 | 0 | Byte-exact relocated U7 runtime image |
| `>FDAE` | `>FDF6` | 73 | 1 | GROM-result formatter and labels |
| `>FDF8` | `>FDFB` | 4 | 4 | Extension ABI marker and version |
| `>FE00` | `>FEF7` | 248 | 8 | Extension service gateway |
| `>FF00` | `>FF19` | 26 | 222 | LOAD entry |
| `>FFF8` | `>FFFF` | 8 | 0 | Image marker, checksum word, workspace and LOAD vectors |

The private ASCII 32-127 font currently occupies `>EDAE->F0AD` inside the
first region. It is checked separately as exactly 768 bytes. This guard exists
because a former backward `AORG >F070` silently replaced the glyphs for
lower-case `x`, `y`, `z`, `{`, `|`, `}`, `~`, and character 127.

## Extension: `src/HEXEXT.a99`

| Start | End | Used | Free before next block | Contents |
|---:|---:|---:|---:|---|
| `>6000` | `>7EEF` | 7,920 | 16 | Header, menus, interactive code, strings, and data |
| `>7F00` | `>7F2F` | 48 | 0 | TI-99/4A/QI keyboard matrix table |
| `>7F30` | `>7F57` | 40 | 0 | TI-99/4 keyboard matrix table |
| `>7F58` | `>7F7F` | 40 | 0 | TI-99/4 SHIFT/function translation table |
| `>7F80` | `>7FBF` | 64 | 62 | TI-99/4A SHIFT/function translation table |
| `>7FFE` | `>7FFF` | 2 | 0 | Extension checksum correction word |

The build requires the variable extension to end no later than `>7EEF`,
preserving at least 16 bytes of deliberate headroom before `>7F00`. The current
build ends at `>7EEF`, leaving 16 bytes. This guard exists because variable text
once reached `>7F00` and silently replaced the first keyboard-table byte and a
string terminator.

## Relocated U7 image: `src/MEGAU7.a99`

`MEGAU7.a99` is relocatable assembler output with `XORG >D000`, rather than a
ROM `AORG`. Its listing must report `MSTART=>D000` and `MEND=>D538`, exactly
1,336 bytes. The core embeds that exact binary at `>F876->FDAD`; both lengths
are checked, so the runtime and embedded copy cannot drift apart.

## Enforced origin inventory

The core contains ten reviewed `AORG` directives:

```text
>E000 >F100 >F22A >F546 >F876 >FDAE >FDF8 >FE00 >FF00 >FFF8
```

The extension contains five:

```text
>6000 >7F00 >7F30 >7F80 >7FFE
```

The checker rejects a changed count, changed address, repeated address, or
backward address before it evaluates region sizes. This makes adding a new
fixed block an explicit map change instead of an invisible overwrite.
