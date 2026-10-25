# Native GBA Substitute doll art work in progress

This development branch extends the native Substitute command/controller work.
It imports the doll from the player's cartridge and uses its native 64x64 OBJ
geometry, including each double-battle slot and the controller's live offsets.
Existing caches need a reimport to populate the new art metadata. The previous
draw path remains available while that metadata is absent.

## Cartridge contract

The discovery helper identifies one verified loader literal pool: DMA3's
register/control pair, matching graphics-buffer literals, two distinct 2048-byte
LZ sheets and a valid 32-byte BGR555 palette. Missing, ambiguous, unmapped or
malformed candidates are refused. Symbols are recorded in the two supported
English manifests, each checked against its exact cartridge SHA-1.

The asset stage validates every blob before writing either sheet. A versioned
`constants.gen3SubstituteArt` record names only successfully extracted images.
The animation-pack RGB555 contract retains the high five bits of each channel,
including RGB behind transparent palette index zero. No cartridge images are
included in this branch.

## Verified evidence

- Eight discovery rejection/acceptance tests, including ambiguous loaders,
  invalid palette, mismatched buffer, oversized/truncated inputs and duplicate
  sheets.
- 59 owned import/placement/render checks: 4bpp nibble order, separate facings,
  native dimensions, rejection before partial output, all six battler slots,
  widened native field, live offsets and graphics-color preservation through
  the actual battle draw path.
- Actual targeted FireRed/Emerald stage imports into a separate CPU QA output
  directory. Every RGBA channel in all four native sheets matches the existing
  read-only Gen1 imports: **16,384 pixels, zero differences**, including
  transparent RGB. No ordinary cache, save or game process is modified.
- The structural locator uniquely resolves complete art in five existing
  cartridges: BPRE, BPEE, BPRD, BPED and BPGE, revision zero. The extra three
  locator checks do not claim support for additional game profiles.

These checks establish decoded artwork and draw commands. They are not final
scene screenshots or whole-battle graphical acceptance. General/status playback
for Substitute fade, Focus Band and poison remains open in the broader command
matrix; its 1,344 differing observations are retained. Mirror Move history,
linked-role and actual public-submission gates also remain open before a PR.

Raw local QA is retained in `tmp/substitute-art-qa/`. Run the owned checks with:

```sh
nice -n 19 python3 tests/tools/test_gba_substitute_art.py
nice -n 19 /path/to/pinned/luajit tests/engine/gen3_substitute_art.lua
```

For an actual targeted import, supply the matching manifest/cartridge and an
existing separate QA directory:

```sh
nice -n 19 /path/to/pinned/luajit \
  tools/enemy-action-contract-check/imported-substitute-art.lua \
  tools/rom_manifest_firered.json /private/firered.gba /private/qa-output
```
