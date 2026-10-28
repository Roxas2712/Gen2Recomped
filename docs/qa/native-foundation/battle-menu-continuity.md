# Native battle menu continuity and trainer party rows

The source-facing swap observation is a detached `{cursor = index-1}` record,
matching the zero-based drawing protocol. `_swapIndex` exposes the native
one-based number; the native `moveSwapIndex`, input handling, move/PP records
and command owner are unchanged. Mutating a returned record cannot change the
native selection.

Public party-bar painting and native HUDs share one existing native row
renderer: icon packing, opposite-edge geometry, arrival timing and first-paint
stamp. Public decorators borrow each native row once; held draws do not start
a clock, native failures cannot be swallowed/replayed, and callbacks restore
graphics state. Positions, opacity, hidden icons and per-icon offsets are
presentation only. Bars and icon sheets may have different texel densities
while keeping their imported logical dimensions. Unsupported extended sheets
are diagnosed rather than advertised.

Fork source `1830bd24b6`, including main `0f49e5c2` at merge `77a13eeb`, passes
47 CPU groups including491 continuity/density checks. Eight additional groups
on the same frozen bytes pass3014 checks for native Gen2 models, healthboxes,
modal admission, stat growth and level-up drawing. Older-public composition
`d50e49cc03` passes30 CPU groups with the same491 new checks. Its native
controller body receives checked narrow changes, not the newer fork body.

GPU runs `fb6791647c` (fork) and `d9100003e8` (public) each pass4322 checks
across1440 constructed frames on Metal and on OpenGL: both rows, six arrival
ages, five editions, widths240/320, DPI1/2, independently varied image density,
custom positions/opacity/slots/offsets and unchanged native clocks.

Actual unchanged Origami1.0.9 run `74566232b9-firered` uses earlier source
`95a8db3301`: real trainer constructor, paper/native/terrarium/native/paper
switches, native move-swap/restore/cancel input, unchanged HP/PP and cleanup.
A separate current-main run `c98bf7d9bc-firered` uses `1830bd24b6` and repeats
the trainer/menu path in one scene with raw HUD/font diagnostics. These are
bounded FireRed checks, not five-edition artwork/full-game/window/FPS acceptance.
An earlier observer failure before the first scene was an owned diagnostic bug;
its failed evidence is preserved and the observer was repaired.

The apparent mirrored menu text was tested against the imported bitmap:
normal orientation matches with0.162 mean RGB error, while mirrored variants
produce21.97–38.40. Primitive asymmetric font/HD/small-face and canvas-slice
probes also pass. Low contrast and the selected wide/flat menu fit remain
presentation concerns; no global flip or private-mod change was made.

Managed QA keeps20GiB free and uses separate identities. Player saves and
private reference code are untouched.
