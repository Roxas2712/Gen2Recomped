# Native Gen2 PP selection and maximum

The Gen2 party-target ETHER, MAX ETHER, MYSTERYBERRY and PP UP route uses the native `Gen2MoveDeleter` screen from
Gen1Recomp 535a5ec0. It retains the actual party mon and moves. The ordinary
PP cursor stops at both ends; the native forget layout wraps. Only the
caller's normal choose/cancel continuation controls stack lifetime. The
move-list window preserves the party underneath, and B drops only that list.
Field PP selection also keeps its party parent until its existing result
flow closes it. No consumer files need changing.

`Gen2PP` owns Gen2's `ComputeMaxPP` arithmetic. Each PP Up adds
`min(floor(basePP / 5), 7)`, so a move with 40 base PP and three PP Ups has
61 maximum PP. Legacy slots with a valid stored `maxPp` infer their existing
bonus without a mutation during reads. PP Up refuses Sketch and a fourth
bonus. Shared maximum readers accept an explicit destination generation for
cross-game reconstruction, while other generations retain their existing
maximum rule.

Item restoration, PP Up, party healing, daycare retrieval, classic/wide battle
labels, summary, public party/battle/callback records, held-item restoration,
link reconstruction and Bank destination clamping use the common maximum.
The Bank passes the destination generation rather than borrowing the active
launcher's game.

The native move-list and forget-list layouts preserve reference provenance.
Sound uses the existing imported cue and actual Sound.play service; the
reference's unavailable Sound.resolve is not introduced.

Contracts exercise the real screen registry, native input, bounds and forget
wrapping, cartridge drawing coordinates, callback/cue lifetime and immutable
party reads; actual item effects, native maxima/legacy counters, healing,
link clamping and public party reads. The battle PACK suite additionally
requires its real ETHER route to open this controller. Qualification results,
including baseline failures and unchanged-client GPU acceptance, must be
recorded separately; the presence of contracts does not prove full parity.
