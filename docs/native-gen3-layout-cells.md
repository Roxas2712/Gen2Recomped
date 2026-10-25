# Native Gen3 grid writes and layout restoration

A Gen3 cell contains a metatile, two collision bits and four elevation bits.
The previous native `applyGen3Layout` copied the latter two only when artwork
changed relative to the imported base. Same-art blocking/height changes were
lost. Restoring the base also compared against the base instead of the live
map, leaving earlier metatile patches and coordinate seals active.

The native Map now applies all three components against the actual live grid.
`setGen3Cells` validates the complete batch before writing, composes duplicate
rows in input order and increments `gridRevision` once per changed batch.
It preserves explicit zero and bridge elevation 15, all collision bits and
unspecified fields. Changes dirty native rendering. Invalid and net no-op
batches do not change the grid, revision or redraw state. The ordinary native
block/shut/clear operations also share that revision; clearing restores height.

Packed layout strings supply all three original bit fields when separate
arrays are absent. Missing or invalid fields reject the entire layout before
mutation. Shared imported definitions retain their identity and data. The
native decoded artwork cache follows its actual packed source string.
`setmaplayoutindex` records a layout only after it successfully applies.

## Verification

The [source-bound receipt](qa/native-foundation/gen3-layout-cells.json) covers
source `5aa63a2d`. Its 246 native grid/restore tests include the actual Gen3 VM
and ScriptRunner. They pass independently on upstream main plus this patch;
the preceding source demonstrates the same-art and restore bugs. All 267
combined engine suites, three SDK suites and B30 pass. Existing Gen2 terrain,
native rendering and detached map/source query regressions pass separately.

FireRed and Emerald each pass a separate Apple M3 hardware-GPU test on Metal
and OpenGL, VSync 1. Actual native floor pixels change to the requested
metatile and return to the original pixels after the native layout command.
Same-art collision/height changes preserve the GPU artwork and the native
mover query rejects newly blocked cells. FireRed's actual start menu remains
usable. Native map return and all 16 fresh owned-window proofs pass.

Emerald additionally loads actual Sootopolis and uses the imported layouts 8
and 357. Their source records differ in 645 artwork cells, 28 collision values
and one elevation value. Both renderers pass full comparison of all 3,600 cell
triples after base, alternate and restored layout commands. The native city
window is visually inspected. An initial QA viewpoint assumption was wrong:
the changed passable cells were water. The corrected driver stands on nearby
unchanged land; the failed attempt remains separate and no product workaround
was introduced.

The fresh unsaved QA maps bypass the introduction, and explicit native
commands/warps do not establish story progression. The proof called `resized`
shows Sootopolis or a native menu, not a window resize. Windows/macOS QA
payloads match committed source and each other; PE/DLL and strict macOS
signature checks pass. Windows hardware is not tested. Packages are unpublished.

## Native map work still open

This is a correction to the shared native grid, not a completed replacement
for Gen1's `src.core.game3.map`. That module still needs actual current-map
records, layout handles, connection placement/residency, player/field handoffs
and atlas lifecycle. Dimension/tileset changes beyond the existing same-sized
grid operation also remain open. Original OASC and its First/Third rendering
are not accepted on this fork by these tests. No mod port was resumed; protected
Gen1/player installations and the public preview were left untouched.
