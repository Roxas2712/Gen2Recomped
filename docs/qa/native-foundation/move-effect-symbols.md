# Canonical native move-effect symbols

Contributions by Roxas2712 — https://github.com/Roxas2712.
See LICENSE-ROXAS2712.md for the contribution terms and specific integration
permission for Cedric / UNDERdecoded. Existing notices and rights remain intact.

`Gen3EffectCatalog` provides constant-time ID/name queries and detached snapshots
for all 214 GBA dispatch slots, including unused slots. The canonical identifier
facts come from [the pinned public constant header](https://github.com/pret/pokefirered/blob/ce6406d8c2eaf46d543c8a2606de0c3cb1951982/include/constants/battle_move_effects.h)
(SHA-256 `fa15e285903818cc3cc7ecb2ca32c11d8317b14d261ca2d1caf44e614b53828a`).
The exact header is retained separately as a factual test fixture. Runtime storage
uses one compact ordered list and two lookup tables built once, with no session,
save, importer or combat bootstrap.

`battle.effect_ids` returns its own snapshot, so decorating source constants
cannot mutate native authority. `battle.moves.get(...).effectSymbol` identifies
the current imported raw byte. Unknown custom bytes remain usable and unnamed;
old records without the byte are never reverse-guessed from native dispatch
names. Native move records, cache formats and effect execution stay unchanged.
Publishing an identifier does not implement an absent effect, action readiness
gate, executor or animation event producer.

Frozen fork `27e2bc33e1`, refreshed with main `e6dbce6a`, passes 64 CPU groups,
including 4,531 symbol/snapshot/imported-query checks and the merged optional
image failure/retry checks. Independent older-public composition `f4e264523f`
passes 34 groups with the same 4,531 symbol checks; its native controllers and
asset owner remain separate. Unchanged-mod run `e4a3201258-firered` completes the
real trainer, five view changes and native move-swap/restore/cancel with exit 0
and idle cleanup. No full action-command, all-edition gameplay, complete visual
or sustained-FPS acceptance follows. QA keeps isolated profiles and at least
20 GiB free; player saves and private runtime files remain untouched.
