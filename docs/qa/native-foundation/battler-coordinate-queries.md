# Native base battler coordinates

The rendering adapter queries `pic_coords.battlerCoords(double, id)` for its untransformed sprite anchors. The native engine already owns the imported singles/doubles layout and its canonical fallback anchors. This query reads those owners instead of adding another coordinate registry or using camera/animation offsets.

The result has `x/y` and indexed `1/2` fields and is detached from native records. It follows current datasets immediately, retains the explicitly requested layout independently of an animation's double/coordinate overrides, and rejects invalid slots, non-finite numbers and malformed records. Missing variant/slot data uses that variant's existing native anchor; it cannot accidentally select the other variant. No game is bootstrapped for a query, and other generations do not obtain a fabricated GBA owner.

Frozen fork source `37b9261a00` on main `56d27ead` passes35 groups, including995 coordinate checks across FireRed, LeafGreen, Emerald, Ruby and Sapphire. Tests cover imported/default coordinates, changed and partially absent datasets, invalid records, detached mutations, animation-override isolation and unchanged native HP/AP/frame/queue/RNG. Existing battle/animation, RS healthbox, Gen2 party/AP/map/PACK/live-view, checkpoint/suspend and native process/quit regressions pass. Exact older-public composition `f33d99d2af` passes23 groups including the same995 checks, without replacing its native controllers or adding the newer fork lifecycle/RS bodies.

This is an observational query contract. It does not qualify the remaining profile, caught-dex, substitute/stat-mask or complete presentation-provider interfaces, or extend previous graphical/performance results to this source. QA uses isolated identities and20GiB free reserve; player profiles and reference mods remain untouched.

Contributions by Roxas2712. Existing code and third-party rights retain their provenance. See NOTICE.md and LICENSE-ROXAS2712.md for Cedric / UNDERdecoded integration permission and visible-credit requirements.
