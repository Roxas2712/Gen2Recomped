# Native field constants and region atlas metadata

Contributions by Roxas2712 — https://github.com/Roxas2712.
See LICENSE-ROXAS2712.md for the specific integration permission for Cedric /
UNDERdecoded and applicable credit requirements. Existing rights remain intact.

The constant query now supports required lookups with explicit unknown-name and
retired-owner errors. Optional id/name/raw queries retain their behavior. A
provided session must be the current native facade session; copied, foreign and
retired sessions cannot bind the query. New required lookups hold weak owner
references and reject changed dataset/save/loader/edition cohorts. Returned enum
snapshots remain detached.

Only the known Hoenn Building TV Off/On label facts are added (2/3). They come
from the numeric definitions in the pinned public primary headers:
- https://github.com/pret/pokeemerald/blob/731ad5bfd6e6f265508d0efcca0ba42f9dcf5881/include/constants/metatile_labels.h
- https://github.com/pret/pokeruby/blob/5784633ce4ef7ade1a7f2d2d0c288e3d5e6cdd7f/include/constants/metatile_labels.h

There is no copied program implementation, cartridge payload or guessed FR/LG
namespace. These facts allow a source consumer to describe a speculative TV
layout; this query neither changes metatiles nor executes entry scripts. Actual
forecast adoption still requires matching the real native layout. Other missing
constant banks and ferry-state owners remain separate work.

The Hoenn region-map manifest reads the real native RS owner's detached imported
manifest when available. The generic native picker exposes its own logical cell
lookup without constructing another screen or loading artwork. Its imported
cell bank wins over rectangle fallback, exactly as in native navigation; absent
fallback cells use false and never invent a map-section ID. These are logical
picker cells, not a claim that a rectangle fallback reproduces missing cartridge
art. The manifest query does not move the cursor or write visits/save/RNG.

Frozen fork `63edafa7ab` (head561fb654, mainc5766c86) passes86 CPU groups,
including92 required-constant/session checks,305 region observation/atlas checks,
155 flight-boundary checks and existing3323 native world-action checks. Exact
older-public composition `ece2b98080` (head239d5270) passes48 groups over its own
older native bodies, including92 constants,305 atlas/region and155 flight checks.
Later RS native controller bodies are not overlaid onto that composition; real
RS metadata/art/controller acceptance remains conditional on its native owner.
An actual unchanged-mod Ruby atlas/map/flight probe is in progress.

The preceding FireRed flight source `10d00485d3`, actual run `591d5ee763`, reaches
native Pallet6,8 and a settled upright exterior. A readback-free240-frame Metal
sample averages17.99ms (55.6FPS), median16.67ms, p95 22.68ms, max224.60ms.
This does not resolve its cold-frame hitch or missing native landing-phase seam,
or establish sustained/all-map/OS-window acceptance.

Private mod/runtime files and player saves remain unchanged. Disposable QA keeps
20GiB free, above the requested8GiB floor.
