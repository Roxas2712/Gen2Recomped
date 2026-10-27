# Native battle ball artwork

`battle.ui.ballQuad(ballId, frame)` reads the existing imported 16×16 ball
atlas. IDs and frames are zero-based. An admitted native GBA battle is
required; unknown cells return no picture. The query cannot start a ball,
advance its timeline, consume RNG or mutate the native battle.

One source-owned image and at most 36 cached quads cover twelve styles and
three frames. The native asset cache retains its own image: releasing source
art cannot release native painter resources. Battle admission, dataset/save/
loader/edition replacement, asset invalidation and owner retirement determine
resource lifetime. Covered battles can still observe their own artwork.

The current composed fork had not integrated the native ball metadata already
offered with edition PRs #186/#187. Its Ruby/Sapphire manifests still used the
Emerald addresses. The existing verified native metadata now selects the
original sheet/palette/shared-open/particle tables, nine send-out opcode sites
and RS sound identities. The native extractor and timeline remain responsible
for decoding and animation. `rs-ball-art-v1` invalidates only the affected
edition caches; it does not migrate saves. The separate public edition offers
already contain these facts; the UI-art query does not replace those offers.

Address facts were cross-checked against the original cartridge bytes and
[pret/pokeruby](https://github.com/pret/pokeruby/tree/5784633ce4ef7ade1a7f2d2d0c288e3d5e6cdd7f),
`src/pokeball.c` and `src/battle_anim_special.c`. No alternate extractor or
foreign runtime body is included. The existing opcode checks remain strict;
RS retains its 39/30-frame player/opponent send-outs and caught jingle 371.

`tests/engine/native_battle_ball_art.lua` covers all cells, malformed requests,
sharing and retirement with actual native admissions in all five GBA editions.
`tools/native-ball-art` uses the actual importer and SHA1-verified local ROMs
with graphics disabled; it checks every decoded cell and records RGBA hashes.
Use a fresh owned QA identity and the project's managed storage launcher.

This is an artwork/query contract. It does not advertise presentation API v2
or establish map-battle/terrarium visuals, physical-window output or FPS.
The unchanged mod-owned drawing bridge still requires further native sprite,
particle and menu contracts. Keep those failures visible.

The focused public UI offer depends on the separately offered native edition
profiles for Ruby/Sapphire (#186/#187). Their profile/cache changes are not
duplicated in this UI branch. The all-edition ROM fixture requires those
profiles in the composed source.
