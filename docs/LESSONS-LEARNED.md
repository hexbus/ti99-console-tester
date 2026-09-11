<!-- SPDX-License-Identifier: CC-BY-4.0 -->
# Beta 0.7 lessons learned

This postmortem records the failures that materially shaped the public beta.
It is written for maintainers who need to understand why apparently simpler
changes can break real recovery hardware.

## A diagnostic cannot depend on the part it diagnoses

The first keyboard page used the console ROM keyboard service. It worked on a
healthy /4A but failed the intended recovery case: a machine with missing or
damaged GROMs could start through LOAD and then lose input. The final firmware
owns the TMS9901 scan, translation, modifiers, Alpha Lock, joysticks, debounce,
VDP access, PSG output, and navigation. The build rejects any executable call
to the console keyboard vector.

Firmware identity follows the same principle. Stable replacement ROM/GROM data
is descriptive, not a failure. Only an unstable read path is diagnostic.

## The /4 and /4A are different keyboards

The 40-key /4 is not a shortened /4A matrix. It uses five keyboard columns and
SHIFT for the printed direction/function overlay. The /4A adds its own sixth
column, FCTN, CTRL, Alpha Lock, and two unpopulated contacts. Separate fixed
tables prevent plausible-looking but incorrect translations.

Modifier state and the translated character are separate facts. Treating every
Control chord as CTRL-A, or inferring Alpha Lock from a joystick row, produced
misleading displays. The final page reports the raw chord and readable result,
including direction names, FCTN punctuation, and AUX-1/AUX-2.

## Expose uncertain wiring before naming it

Surviving diagrams disagreed about the TI-99/4 joystick selectors. A temporary
diagnostic displayed all candidate columns; physical testing established
joystick 1 on column 5 and joystick 2 on column 6. The /4A family remains on
columns 6 and 7. Raw evidence settled the question before the friendly labels
were frozen.

## A VDP page must own all VDP state

The VDP demo changes the name, pattern, color, and sprite table selections. An
early return path redrew text without first restoring every register, so later
pages such as Credits and the VRAM chip map inherited demo colors, sprites, or
tables. The text had been written to the intended VRAM addresses; the VDP was
simply fetching a different layout.

The correction established one common boundary: blank, program the UI state,
rebuild the font/colors/frame/sprite terminator, reassert all eight registers,
then reveal the page. The regression is tested as a sequence of pages after the
VDP demo, not as isolated screenshots.

## Timing-sensitive code needs its scheduler

The MegaDemo raster effect appeared slow, turbo-fast, jagged, silent, or frozen
when its inner loop was called without the original frame boundary. Software
delays could slow music while leaving scanline work badly aligned. The working
adapter waits for a fresh VDP interrupt, preserves the caller's return link,
and calls the original raster controller exactly once per display frame. The
approved PSG bytes remain unchanged.

The lesson is broader than this demo: transplant timing code with its event
source, state, workspace, and return convention. Do not tune unrelated delays
until two broken clocks happen to look close.

## Runtime placement is part of compatibility

An early demo build ran from optional expansion RAM at `>A000`. That worked in
a development environment but froze on the standalone tester, which cannot
assume a 32 KiB expansion and conflicts with a normal expansion at higher
addresses. The final controller is relocated as a unit to tester U7 SRAM at
`>D000`.

## Sprite status is not visible sprite count

The fifth-sprite status flag reports a scanline limit; it does not say that a
fifth object was displayed. Overlapping entries can also make several sprites
look like one. The UI now reports collision and fifth-sprite flags as `SET` or
`NOT SET` and asks the operator to inspect shapes, sizes, and colors. The open
Pico9918 observation is documented without being mislabeled as a native
TMS9918 failure.

## Freeze bytes, not filenames

Repeatedly reusing a development filename made it too easy to test the wrong
image. The public build now has a TI-compatible release alias, a manifest,
SHA-256 sums, and a source snapshot. Comment-only cleanup is accepted only when
the resulting programmer image remains byte-identical to the validated build.

The public repository deliberately excludes old betas, disassemblies, ROM
dumps, emulator loaders, and private harnesses. Those materials are useful for
development archaeology but make a poor build contract for new contributors.
