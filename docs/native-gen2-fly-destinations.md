# Native GSC flight destinations

`src.world.gen2.FieldMoves` now exposes `FLYPOINTS`, `KANTO_FLYPOINT`,
`hasVisitedSpawn(save, spawn)` and `flyPoints(save, landmarks, region)` over
Gold/Silver/Crystal's actual native save flags and imported landing spots.
The destination and Gold flag constants follow the separate read-only
Gen1Recomp reference `535a5ec0`; existing upstream rights remain effective.

The map region boundary comes from the native Pallet header. Crystal inserts
the Battle Tower before Silver Cave; the former fixed Gold boundary put
Crystal’s Silver Cave cursor on the wrong regional painting.

Native `setflag` and `clearflag` keys take priority over older visited-map,
spawn-name or numeric-engine-flag fallback saves. Crystal's inserted flag row
is resolved through the same `Gen2Flags.scriptFlag` function as the native
script VM. No second save bit or write is introduced. A clear therefore
cannot be undone by a stale visited fallback. Registered map aliases retain
the native destination identity and landing coordinates.

The default query returns the visited Johto destinations. A Kanto request
switches regions only after Indigo is visited, matching the reference query.
The actual `TownMap` flight picker consumes this public query, so a mod's
wrapper can combine both regional lists. Selection still uses real imported
fly warps and the existing native flight/arrival owner. Unrecognized spawns
and absent landing spots cannot become selectable.

The GSC flag layout is deliberately not applied to Prism, Polished Crystal
or another generation. Their existing native picker paths remain in place.

## Verification and remaining work

`tests/engine/gen2_fly_destinations.lua` passes 149 checks: actual native VM
set/clear execution, Crystal/Gold/Silver flag numbering, explicit-clear
precedence, previous save fallbacks, exact registered aliases, regional gates,
actual `TownMap` A/B selection/cancellation and a real SDK-loaded query wrapper
with actual loader teardown. Existing field-state checks also pass (30).
The tests use generated-data and device fixtures, not a cartridge or player
profile. A CI contract runs these suites and the pixel regression below.

The retail G/S/C town-map graphics are LZ-compressed (see [Crystal’s graphics loader](https://github.com/pret/pokecrystal/blob/master/engine/pokegear/pokegear.asm)). The importer previously
treated them as raw 2bpp tiles, producing repeated horizontal dashes and broken
coastlines on both regional paintings. It now decompresses them before pixel
decoding, rejects undersized sheets, and invalidates only G/S/C import markers
so existing bad images rebuild. Explicit hack layout overrides remain intact.
The ROM-free pixel regression checks every pixel of both 160×144 regional
fixtures across G/S/C (36 checks), including distinct palette nibbles and
asymmetric tile patterns. The saturated original GBC palette is retained.

Source `8ab72ab8` also passes 362/362 composed engine suites, SDK 3/3 and
all quick tiers. Runtime qualification [40223059704](https://github.com/Roxas2712/Gen2Recomped/actions/runs/40223059704)
passes on Windows, Linux, Intel Mac and Apple Silicon, including the desktop
LÖVE host/thread/FFI gates. Source-bound Windows/macOS packages contain the same
payload; the universal Mac app and qualified runtime pass signature/digest gates.

That exact package, the unchanged supplied Johto mod and Crystal Rev0 pass
84 checks on each of OpenGL and Metal. Each run has four fresh OS-window
proofs of Johto/Kanto with First/Third Person selected, actual native VM flag
set/clear and picker A/B/D-pad input, two real native flights to Violet City
and exact imported arrivals at (31,26). Both complete 160×144 imported images
match a separate Python decoder of the read-only ROM, including all 23,040
pixels per region. All eight OS map images were inspected: the corrupt dashes
are gone. Metal’s pre-existing warning overlays still obscure the lower edge;
full UI presentation and oversized cursor behavior are not accepted here.

The introduction, map/party, visited flags and Hall-of-Fame presentation marker
are explicit QA setups. Native story unlock and Hall-of-Fame flag production,
party/badge admission, full field-action result protocols and the unchanged
package’s complete flight cinematic remain open. Existing question-mark actor
art, performance hitches and Metal warnings also remain open. Earlier `e8eaff6d`
flight logic passes had broken map art and do not qualify this correction.
See the [sanitized receipt](qa/native-foundation/johto-native-town-map.json).
No private mod, ROM, generated image or save is included.

The existing [20261025.1 test release](https://github.com/Roxas2712/Gen2Recomped/releases/tag/native-preview-20261025.1)
now contains this exact qualified binary source. All six asset digests were
verified after replacement; the tag and fixed preview identity stay unchanged.
The manifest distinguishes binary source `8ab72ab8` from automatic source
archives at the retained original tag.
