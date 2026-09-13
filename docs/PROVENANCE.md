<!-- SPDX-License-Identifier: CC-BY-4.0 -->
# Provenance, credits, and licensing boundary

## Original project work

The current diagnostic design, integration, testing, source cleanup, user
manual, and hardware-modification documentation are by **Jon Guidry (hexbus)**.
The canonical project is
[github.com/hexbus/ti99-console-tester](https://github.com/hexbus/ti99-console-tester).

Geoff Trott designed the original Console Tester hardware and software on which
this replacement diagnostic is intended to run. His original ROM is not
included in this repository. Texas Instruments names and part numbers are used
only to identify compatible systems and components.

## MegaDemo-derived material

The diagnostic contains a relocated raster controller and the 298-byte PSG
phrase used by the released Pyuuta/Tutor diagnostic. Jon reports that
Rasmus/ASMUSR wrote the green-line effect and knowingly approved its use in the
Pyuuta/Tutor and TI-99 diagnostic ROMs, including the music passage for this
diagnostic-hardware purpose.

The relevant source is isolated and attributed in `src/MEGAU7.a99`; the PSG
table is identified in `src/HEXDIAG.a99`. This material is not offered under
Apache-2.0 by this repository. Generated ROMs combine the project's original
Apache-2.0 code with this separately permitted, attributed material.

## Troy Schrapel enhanced-VDP detector

The enhanced-VDP identification section in `src/HEXDIAG.a99` adapts the
F18A/Pico9918 detector supplied by Troy Schrapel in his `pico9918tool` project.
It uses the published unlock sequence, six-byte GPU execution probe, and status
register identification masks. Troy supplied the code with permission under
the MIT License.

Copyright (c) 2024 Troy Schrapel. The complete MIT notice is preserved in
`LICENSES/MIT-Troy-Schrapel.txt` and must accompany copies or substantial
portions of that code.

## Community credits

The on-ROM credits recognize Geoff Trott, Jon Guidry, Jim F., Takeo N., Rasmus,
Tursi, Old CS1, the MegaDemo team, and the AtariAge TI-99 community. That list
records technical and testing contributions; it does not imply that every
person licensed every part of the repository.

## What is intentionally not distributed

The public tree contains no Texas Instruments firmware, MAME ROM set,
reference-ROM disassembly, Geoff Trott ROM dump, emulator package, or archived
development capture. External names and checksum values are retained only for
compatibility description and reproducible identification.

## License application

- Files marked `SPDX-License-Identifier: Apache-2.0` are covered by Apache 2.0.
- Files marked `SPDX-License-Identifier: CC-BY-4.0` are covered by CC BY 4.0.
- The separately permitted MegaDemo-derived material follows the boundary
  above and must retain its attribution.
- The enhanced-VDP detector retains Troy Schrapel's copyright and MIT notice.
- Redistributors must retain `NOTICE`, credit Jon Guidry (hexbus), and link to
  the canonical repository.
