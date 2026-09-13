<!-- SPDX-License-Identifier: CC-BY-4.0 -->
# Console Tester backlog

Public Beta 0.8 is frozen. The sprite-limit interpretation and Alpha-Lock/
joystick policy were completed and hardware-validated for this release; their
results are recorded in the changelog, operator manual, and technical
reference rather than left as open work.

## Compare js99er GigaCart decoding with MAME

**Status:** Deferred beyond Beta 0.8; not a Console Tester firmware blocker.

Rasmus added wildcard GigaCart handling to js99er. Compare that implementation
with MAME's separate GigaCart types and determine whether js99er should model
the same three decoding variants. If a behavioral difference is confirmed,
prepare a focused upstream diff and reproduction case for Rasmus.

Keep emulator source, private harnesses, and ROM sets outside this repository.
Only the resulting public documentation or upstream link belongs here.
