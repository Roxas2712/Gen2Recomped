# Native checkpoint facade

All mod API levels expose `mod.checkpoints:inspect(game)`, `capture(game)`,
`restore(game, checkpoint)`, `resume(game, checkpoint)` and
`ensureNormalSave(game, checkpoint)`. Call `inspect` before offering a capture.
Refused operations return their reason instead of inventing a substitute state.

This implementation is independently written around the native controller and
save services. It currently admits settled Gen-1/2 overworld control. Active
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
