# Automatic Gen3 terrain palette-program import

Normal Gen3 imports now run `extractTilesetPalettePrograms` immediately after
tile animation extraction. The existing `map_tilesets` cache gains complete
`paletteCycles` declarations for recognized terrain programs, with per-record
`paletteProgram` provenance/diagnostics and an aggregate `_romInfo.palettePrograms`
summary. No user save, launch configuration or installed player instance is
modified by this stage. Existing caches need a new ROM import; merely updating
the engine cannot create source palette bytes that were never extracted.

## Scope and source evidence

The initial audited profiles cover these existing supported dumps:

| Game | Exact SHA1 | Programs |
| --- | --- | --- |
| Emerald, BPEE rev 0 | `f3ae088181bf583e55daf962a92bb46f4f1d07b7` | 19 tile-only runtime callbacks; Battle Dome floor palette copy program |
| FireRed, BPRE rev 0 | `41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc` | six tile-only runtime callbacks; no terrain palette cycle is invented |

The offset/classification catalog is deliberately **source-pinned**, not
inferred from palette appearance or a tile's VRAM destination. It is recorded
in `tools/gen3_palette_program_profiles.json` and embedded in each manifest's
`terrainPalettePrograms`. `gen3_discover.py` preserves the exact matching
profile when regenerating the Emerald manifest. Unknown hashes get no profile.

Primary source audit:

- [Emerald source at 3ec4d98](https://github.com/pret/pokeemerald/blob/3ec4d98de95a2aeb12f3c738b3496d0b3a830793/src/tileset_anims.c)
  preserves the original runtime offsets in its function names. The Battle
  Dome timer calls the palette-copy helper every four ticks. That helper
  selects one of four pointers at flat offset `0x52487C`, copies 16 BGR555
  colours into absolute BG colour index 128 (palette 8), and separately handles
  fading and battle-transition task state.
- [FireRed assembly at d58bf398](https://github.com/pret/pokefirered/blob/d58bf398b2b83a326d23d14d531de7f45a1058bb/asm/tileset_anims.s)
  names the six timer routines and their initializer stores/addresses. They
  enqueue tile transfers; they do not perform terrain palette copies.

The new import extracts the **unfaded palette-frame program**. Cartridge
fade buffers, battle-transition callback substitution/countdown and map-local
counter reset phase are not reproduced by the current colour API. The frames
use the fork's existing shared terrain clock and remain independent of tile
picture selection. This is not a general GBA callback interpreter or a promise
to recognize arbitrary ROM hacks, other languages or other revisions.

## Authentication and bounded analysis

The automatic stage hashes its actual ROM bytes via `RomVerification.sha1`,
even when the application previously verified them. The digest must agree
with both the manifest and the palette-program profile before any initializer
or palette reads are attempted. The chosen launcher game or a plausible
header alone cannot authorize a profile. A missing hashing facility leaves
sources unavailable instead of trusting an unverified identity.

Each tileset's existing callback pointer is read from the imported header. A
zero pointer explicitly has no program. Otherwise a read-only analyzer walks
at most 64 Thumb instructions from the initializer and observes its single
callback-word assignment. Supported operations are literal/immediate loads,
simple shifts/moves/arithmetic, halfword counter accesses and RAM word stores,
ending at `bx lr`. No machine code executes and no RAM is read or written:
counter loads are unknown symbolic values, accepted only where they cannot
decide the callback pointer. Branches, calls, unknown instructions, ambiguous
stores, invalid addresses and unproved callback values decline.

A null installed callback is explicitly static. A recognized runtime pointer
must also belong to the tileset's primary/secondary bank. Only then does the
audited profile authorize an empty cycle declaration or a bounded frame-table
read. Frame count, cadence, phase, byte extent, alignment, bank ownership and
RGB555 validity are checked before publishing **any** frames. Conversion uses
the existing `RomGba.bgr555` floor rule, matching the source palette contract.

Runtime-offset classification is safe here because it is gated on the exact
full-file digest; it is not a structural proof for a different binary.
Changing the catalog for another build requires a new source audit and tests.

## Failure, cache lifetime and compatibility

Every analyzed record gets one of:

| Status | `paletteCycles` | Meaning |
| --- | --- | --- |
| `static` | explicit empty array | no palette animation in this recognized terrain callback |
| `animated` | complete RGB frame run | recognized unfaded palette program |
| `unavailable` | absent | unknown identity, initializer, runtime callback or invalid source; reason preserved |

A repeat import clears old declarations before reclassification. Failed
records cannot retain a previous successful cycle. Other valid records are
still imported, and a single cache write persists the complete result and
summary. The native renderer retains base colours for incomplete pairs;
`colorTileset()` declines with its existing explicit error. Base terrain and
the original `animatedTileset()` contract remain available.

No new public API, registry, event, permission, save field or mod manifest
version is added. Source addresses and diagnostics remain in the engine's
imported cache, not in the public graphics response. Palette bytes come from
the user's ROM at import and are never committed or packaged in the repo.

## Tests and acceptance

Three ROM-free Lua suites and six Python profile/checker tests cover:

- All audited program classifications for both games, both no-callback cases,
  unknown callbacks and complete independent BGR555 frame decoding.
- Actual synthetic primary/secondary headers through `extractTilesets`,
  including FireRed's swapped callback/attribute fields. Unrelated map/script
  behaviour derivations and image saving are omitted in that focused test.
- The real automatic stage, hashing its input bytes, normal stage ordering,
  one cache write and binary-frame round trips through `LuaWriter`.
- Identity failure before source reads, unknown instructions, callback
  pointer/bank errors, instruction limits, invalid recipes, palette bounds,
  missing/truncated frames and removal of stale success.
- A public-only mod loaded with APIs 1/2 for Emerald/FireRed, consuming the
  serialized imported cache. Complete decoded RGBA layers match independently
  selected palette pictures over all four frames and repeated cycles.
- Source/RNG/GPU/Game isolation, unchanged base API and resident-neighbor
  behaviour. Profile regeneration and exact-hash refusal are checked too.

The synthetic images contain original generated colours and small original
Thumb initializers; the hash function is explicitly injected for those tests.
They do not prove that a retail ROM was imported. Actual-ROM results, when
available, must be recorded separately with the observed digest and callback
coverage. No full-game, GPU, performance or First/Third Person acceptance is
implied by these import/data tests.

## Retail-ROM verification, 2026-10-24

Both supported retail dumps were actually checked, using the exact SHA1s
above. The read-only checker ran real map-layout/header extraction, tile-frame
extraction and palette-program import in memory, then passed the imported
sources through public API-1/2 consumers and the native CPU pixel decoder:

| Game | Source tilesets | Unknown programs | Representative pair | Complete RGBA comparisons |
| --- | --- | --- | --- | --- |
| Emerald | 72 static + 1 animated | 0 | Battle Dome, 119 metatiles including all 95 referencing palette 8 | 30,464 |
| FireRed | 63 static | 0 | outdoor pair, 47 representative metatiles | 12,032 |

Every comparison passes against colours independently decoded from the raw
ROM words. Emerald's floor pixels visibly change between tick 0 and tick 4
at an identical tile-animation picture, proving the new palette program is
actually used. FireRed has no invented palette cycle. Hashes checked again
afterward confirm both source files remained unchanged. The
[machine-readable report](qa/native-foundation/palette-program-import.json)
contains counts and identities, not source ROM bytes or local file paths.

Reproduce with LuaJIT and private paths to the supported dumps:

```sh
python3 tools/check_gen3_palette_programs.py --lua /path/to/luajit /path/to/emerald.gba /path/to/firered.gba
```

The Python wrapper hashes one file read and passes those exact bytes through
stdin to an isolated Lua process. It rejects unknown hashes before running
the extractor. The checker saves no images, caches or game state. Unrelated
map/script behaviour discovery is omitted; ROM layouts, headers, tiles,
palette bytes and program classification use the real stages. Pixel tests
use fixture world identity and controlled terrain ticks 0–31, not a running
retail map/session. These are real-ROM import and CPU pixel tests; they are
still not GPU, full-game, performance or camera-mode acceptance.
