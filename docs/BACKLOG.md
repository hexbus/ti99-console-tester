<!-- SPDX-License-Identifier: CC-BY-4.0 -->
# Console Tester backlog

This file records work considered after Public Beta 0.7. These items are not
part of the current source-cleanup pass and must not silently change the
hardware-validated Beta 0.7 program image.

## Investigate one missing visible sprite on TI-99/4

**Status:** Open; observation needs isolation by VDP implementation.

**Observed:** On the tested TI-99/4, one of the three intended visible sprite
groups did not appear during the TMS9918-family sprite exercise. That console
currently contains a Pico9918, so this is not yet evidence of native TMS9918
behavior.

The exercise creates five same-scanline sprite entries. Sprites 0 and 1 overlap
to stimulate collision, sprites 2 and 3 are separate, and sprite 4 stimulates
the fifth-sprite condition. Suppression of sprite 4 is expected on an original
VDP; only two visible groups, rather than the intended three, is the unresolved
observation.

**Investigation:**

1. Use the `VDSPRT` reproduction contract in `src/HEXEXT.a99`: SAT `>0300`,
   pattern table `>1800`, five entries at Y=79, and R1 stages `>E0`, `>E2`,
   and `>E3`.
2. Reproduce separately on a genuine TMS9918, a Pico9918, a TMS9918A, and an
   F18A when available.
3. Distinguish sprite-limit behavior from overlap, early-clock, coordinate,
   pattern, and replacement-VDP compatibility effects.
4. Confirm that the /4 still skips Graphics-II bitmap tests.

**Acceptance criteria:**

- The intended three visible groups are present where the VDP supports the
  original behavior, or the screen clearly documents an implementation-specific
  difference.
- Collision and fifth-sprite status remain observations, not misleading
  pass/fail claims.
- No stale sprite or table data corrupts the following page.
- The /4, /4A, QI/V2.2, and GROMless recovery paths remain functional.

## Revisit Alpha Lock and joystick policy on QI consoles

**Status:** Open; current Beta 0.7 behavior remains frozen.

**Observed:** The current page asks the operator to release Alpha Lock and
blocks joystick testing while it is down. That is appropriate protection for
the original /4A wiring, where Alpha Lock interferes with joystick Up, but users
report that the QI motherboard corrects that interference. The same restriction
is therefore unnecessarily severe on a QI console.

**Required profiles:**

| Console profile | Question to resolve |
| --- | --- |
| Stock TI-99/4 | Preserve verified joystick selectors 5 and 6 and appropriate /4 keyboard messaging |
| Stock TI-99/4A | Prevent Alpha Lock from being mistaken for joystick Up and explain why release is requested |
| TI-99/4QI / V2.2 | Permit useful joystick testing with Alpha Lock down if hardware validation confirms isolation |
| GROMless, custom, or unknown /4A-family console | Remain useful without assuming firmware identity; prefer an accurate caution/raw display over a false hard block |

Firmware checksums may identify a stock V2.2 set, but firmware identity alone
may not prove motherboard wiring on a modified console. The investigation must
separate what is detected from ROM/GROM contents, what can be probed electrically
through the TMS9901, and what must be presented as operator guidance.

**Acceptance criteria:**

- Joystick Up never creates a false `RELEASE ALPHA LOCK` warning.
- A confirmed QI can exercise both joysticks with Alpha Lock down if physical
  tests confirm that this is safe and unambiguous.
- An original /4A still receives clear guidance when Alpha Lock masks a valid
  joystick direction.
- Unknown/GROMless systems retain direct keyboard and joystick visibility and
  are not made unusable by an uncertain model classification.
- Messaging states the detected profile and the limitation in plain language,
  without asking users to understand the TMS9901 circuit.
- Holding 0 continues to return to the menu, and no FCTN/CTRL combination is
  dispatched as a console action.
