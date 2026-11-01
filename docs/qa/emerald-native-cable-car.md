# Emerald native cable car

Contributions by Roxas2712. See `LICENSE-ROXAS2712.md`.

Emerald previously took the cable-car destination warp directly. Ruby/Sapphire
already ran the original ride. Emerald now has its own ROM-derived layers,
palettes, OAM and complete actor picture arrays, including the original fourth
Zigzagoon entry.
The existing pinned GBA cable-car machine supplies movement, parallax, weather and
fades; its original licence and provenance remain unchanged.

The script suspends before the ride and resumes after arrival. The completed
black scene stays underneath the warp, which avoids a departing-station flash.
Ruby/Sapphire retain their existing provider. The Emerald cache readiness check
requires the edition's own manifest and all twelve resources; old or incomplete
caches require re-import. No ROM bytes or generated game assets are distributed.

The contract test covers edition ownership, damaged/missing assets, both ride
directions and deferred arrival callbacks across Hoenn. The prepared native
driver checks both genders and directions, non-skippable rides, the original
music's PCM, draw-time save/RNG preservation and real station scripts. Such
fixtures do not count as ordinary campaign progress. The ordinary Emerald
campaign continues separately from its witnessed normal saves.

Original references: [ride and weather sequence](https://github.com/pret/pokeemerald/blob/master/src/cable_car.c),
[actor identities](https://github.com/pret/pokeemerald/blob/master/include/constants/event_objects.h).

Native qualification: Emerald runtime `11a3fa3b05bc33485a0627d069d6034034d37797`
passed all four view cases and both real station-script rides, with 18 final
renderer captures. Each ride completed at native frame 629; music 425 produced
nonzero PCM. Draw preserved save/RNG, and the actual up/down station prompts,
cancellation and return squares passed. The corresponding Sapphire regression
passed at `c8c9fc30d18126a127a32bcb9f130e84eec2bdbc`, also with 18 captures and
both real station flows. Both parents exited 0 with frozen sources unchanged.
These are prepared fixtures, with no ordinary story credit. Focused contracts
passed 113 new cache/arrival checks and 185 existing portable-travel checks.

The separate ordinary Emerald campaign at
`5c0cc94f794ebff9d782eb5fd2808d906234949b` completed the original cable-car
ride, Maxie battle, Jagged Pass and Flannery battle, including the Heat Badge,
TM50 and May's Go-Goggles gift. It retained normal purchases, healing and
battle outcomes, then wrote normal SAVE40 on Route 111. Its 968-command native
parent passed with exit 0 and frozen source unchanged. This is campaign
evidence through four badges, not a completed Emerald story.
