# Native checkpoint facade

All mod API levels expose `mod.checkpoints:inspect(game)`, `capture(game)`,
`restore(game, checkpoint)`, `resume(game, checkpoint)` and
`ensureNormalSave(game, checkpoint)`. Call `inspect` before offering a capture.
Refused operations return their reason instead of inventing a substitute state.

This implementation is independently written around the native controller and
save services. It currently admits settled Gen-1/2 overworld control with canonical
static native actors and stationary native spinners. Wandering, followers, scripted actor placement, extra actors,
strength/encounter overrides and multiplayer fail closed until their continuations
are qualified. Active
screens, scripts, transitions, movement and effects are refused. Battle and
later-generation reconstruction are **not qualified**; inspect reports
`unsupported_battle` or `unsupported_runtime`. Providing the facade does not
establish complete checkpoint compatibility for every consumer.

Format 1 is detached plain data: `kind = "overworld"`, `identity` containing
`engineVersion`, `gameVersion`, `playthroughId`, canonical `save` progress,
`runtime.overworld = {map, x, y, facing, surfing}`, and `rng.love`. Do not store
controller objects or functions in it. Global options are excluded. Legacy
overworld records without RNG remain readable and retain the current RNG.

Restore validates identity, installed content, coordinates, data shape and RNG
encoding before reconstruction. It builds fresh native maps and actors under a
private transaction, suppresses normal entry/load events, then compares a full
recapture. A failed build restores the original save, controller fields, player,
map cache, palette, stack ownership and RNG. Existing objects/resources remain
owned by the rollback snapshot until commit. Checkpoints never contain those
private transaction tokens.

Saved mod progress in `save.modData` rewinds with progress. The mod-save service
is rebound to it. Current options and unknown mod-owned controller fields retain
their identity; separately persisted mod storage is not rewound. Only a committed
restore/resume emits `checkpoint.restored` with `{game, kind}`. Mods can refresh
runtime references from that event.

`resume` requires the native title and its existing selected playthrough. It
preserves the original title state if reconstruction fails and never writes
normal progress. `ensureNormalSave` is separate: it verifies the exact current
checkpoint, returns `true, "already_exists"` without changing existing progress,
or uses the real game's normal save lifecycle to create the first save. A
conflicting destination is refused. Injected test filesystems support reads and
existing-save checks; they cannot redirect the real game's normal write.

CPU qualification uses the real loader, Game singleton, controller, map cache,
state stack, save lifecycle and owned synthetic content in Red/Gold, at API
levels 1/2/3. It does not establish GPU, battle, later-generation or full-story
acceptance. FrameProfile before/after and ARM timings: not measured. This is an
additive compatibility service; no performance switch applies.

The earlier static-only qualification passed 424/424 engine suites on the
composed fork, all 3 SDK suites and all quick tiers, plus 678 focused checkpoint assertions. `tools/check_native_checkpoint_rng.py`
exercises the actual host RNG with the native loader/controller/map-cache
transactions at API 1/2/3 in Red and Gold. LÖVE 11.5 and 12 each pass 444
assertions: exact 64-value continuation, failed-rebuild RNG/ownership rollback
and invalid-state refusal before reconstruction. Graphics are substituted and
content is synthetic; this does not extend qualification to battle, later
generations, dynamic actors or full gameplay. The launcher uses the shared
20 GiB QA reserve and owned profiles. An older public stack can provide the
shared guard with `--qa-tools /path/to/fork/tools`.

## Stationary spinner continuation (M4 follow-up)

The four native `SPIN_CW`, `SPIN_CCW`, `SPIN_SLOW` and `SPIN_FAST` modes are
admitted at their installed cells, in the local cast and connected neighbour
casts. Optional `runtime.spinners` records contain the stable native object ID,
movement mode, installed cell, facing and remaining turn timer. These are plain
semantic values; no NPC, sprite, controller or callback is serialized. Static-only
format-1 records retain their original shape.

Validation binds the records to installed native object definitions and rejects
unknown fields, malformed directions/timers, changed modes/cells and unknown
objects. Reconstruction restores the values on newly built native NPCs before
verification. A missing record, changed visible cast or failed partial apply
rolls back original actor, map-cache, save and RNG ownership. Legacy static-only
records cannot silently reset a spinner. Stale pooled spinners outside the live
local/neighbour casts remain refused. Hooks stay quiet until the existing single
`checkpoint.restored` event after commit.

The focused CPU suite checks facade access at API 1/2/3, snapshot isolation,
malformed and missing records, partial-apply rollback and title resume. The native
LÖVE runner additionally compares every facing/timer and RNG continuation over
384 updates of all four actual NPC modes, for Red/Gold at all three API levels.
It uses owned synthetic maps and substituted graphics; it does not qualify a full
story playthrough, wandering actors, followers, battles or later generations.
See `docs/qa/checkpoint-spinners-m4.json` for the recorded acceptance and native
host results. FrameProfile and ARM performance are not measured; this additive
compatibility work has no performance switch.
