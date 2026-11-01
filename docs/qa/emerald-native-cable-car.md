# Emerald native cable car

Contributions by Roxas2712. See `LICENSE-ROXAS2712.md`.

Emerald previously took the cable-car destination warp directly. Ruby/Sapphire
already ran the original ride. Emerald now has its own ROM-derived layers,
palettes, OAM and complete actor picture arrays, including its Zigzagoon passer-by.
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
campaign continues separately from its normal lower-station SAVE33.

Original references: [ride and weather sequence](https://github.com/pret/pokeemerald/blob/master/src/cable_car.c),
[actor identities](https://github.com/pret/pokeemerald/blob/master/include/constants/event_objects.h).
