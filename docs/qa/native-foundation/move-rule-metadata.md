# Native move and critical-rule observations

Contributions by Roxas2712 — https://github.com/Roxas2712.
See LICENSE-ROXAS2712.md for the contribution terms and specific integration
permission for Cedric / UNDERdecoded. Existing notices and rights remain intact.

`battle.moves.get` now publishes the actual imported move index as both `id`
and `numId`, with `nativeId` retaining the native registry key. Numeric strings
and the existing `{id=...}` / `{move=...}` forms resolve through BattleIds.
The effect field projects the validated cartridge `gen3Effect` byte, including
zero; `nativeEffect` retains the native dispatch name. Different cartridge effects
can share that name, so an old cache without the original byte is never reverse
guessed. Invalid present bytes are rejected with a diagnostic. Native records and
effect dispatch stay unchanged.

The query also preserves native flags, percentage secondary chance, the existing
native probability, contact/critical properties and multi-hit metadata. Nested
flag/hit tables are detached, including explicit false values. A native hit
producer is described as present rather than invoked or exposed as another move
execution path. Each query reads the current registry; no new cross-frame move
cache hides live native edits or catalogue replacement.

`battle.rules.crit.CHANCE` returns a detached zero-indexed denominator table from
the same private constant used by native Damage. Mutating it cannot alter native
critical rolls. This is GBA metadata only: it does not provide an action executor,
input suspension, animation event producer, RNG owner or complete gameplay
profile. Optional action commands still need those native phase contracts before
they can be enabled.

Current-main integration retains both the Gen2 typed queue admission/completion
and existing GBA switch/capture/streak/voiceover hooks. Qualification checks those
owners together, including GBA effect/Substitute timing and native Gen2 event
checkpoint reconstruction. The older-public composition keeps its existing
critical calculation and RNG origin; the portable fixture checks its own stage
inputs and denominator span without substituting a later native controller.

Frozen current-main source `90363e8026` passes 61 CPU groups, including 630 new
move/rule checks, 801 typed-queue checks, 27 typed-checkpoint checks, 13,778 GBA
effect checks, 6,338 Substitute presentation checks and 104,512 Substitute fade
checks. Older-public source `f4b45ce538` separately passes 32 CPU groups with the
same 630 move/rule observations. These are metadata and native phase regressions,
not complete action-command, full-game, visual or sustained-FPS acceptance.
QA uses isolated owned profiles and at least 20 GiB free; player saves and private
runtime files remain untouched.
