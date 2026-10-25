# Native GBA Nature Power caller

Development checkpoint stacked on #248. Gen1 is an unchanged, read-only
reference at `535a5ec088c1ae1bf4d91dd3e35a56f64cf46d91`.

## Implemented contract

Nature Power announces before its terrain-selected child. The child owns the
selected Nature Power PP slot, reduces it after its public event subscribers,
and uses its own target/Pressure rules. Ordinary called moves continue to own
no PP slot. Zero PP is admitted/refused before the parent script; changing PP
inside a later callback cannot rewrite that admission decision.

The native terrain table covers grass, long grass, sand, underwater, water,
pond, mountain, cave, building and plain. Explicit numeric/string terrain
inputs retain the reference's coercion and fallback. Cached host terrain names
use the existing GBA terrain identifiers. The new builtin is installed only for
GBA, including the ordinary Loader path and no-Loader native fallback.

Shared called-target dispatch preserves existing Sleep Talk targets and caller
provenance. Nature Power lends PP ownership only to the first child body, so
spread continuations do not spend it repeatedly. Choice Band and move-end
commands identify the native parent. Generic authored calls keep their existing
ownership path. This is a public-event/native-command change, not a claim of
complete graphical or full-mod acceptance.

Native command revision is 14; party codec remains 1. The independent unchanged
#248 hasher, with only revision 13 changed to 14, reproduces
`cb314093f24370e7`; legacy digest `e33d251961f2a41d` is retained.

## Checkpoint evidence

- **6,048 equal paired rows** across FireRed and Emerald, all single/double
  actors, fourteen terrain inputs, four held-item cases, ordinary/Pressure/zero
  PP, callback zero/refill, replaced/removed/reordered slots, and consecutive
  public event subscribers. Captured payloads, native/public PP, every held
  read, RNG, damage, actor state and retired PP are compared without filtering.
- Exact #248 production differs in **5,376** of the same rows. Both negative
  workers exit zero: these are behavioral differences, not fixture crashes.
- The direct engine suite passes **28,926** checks, including generation
  boundaries and event-visible child PP. Actual host/guest/spectator completes
  two native menu turns per profile with stateful held steering, **108** checks,
  matching event traces, PP and every paired state hash/component.
- The initial fixture lacked a descriptive Choice Band record on both sides;
  the reference's intrinsic fallback then exposed different public IDs. Both
  sides now receive identical owned item definitions. All failed/superseded raw
  observations remain in local QA; no production fallback or relaxed assertion
  hides them.

The fixture uses owned, controlled native-shaped child definitions to isolate
caller behavior; it does not certify the complete cartridge child catalog.
Full engine regression, other called-move contracts, final combined-fork gates,
actual imported Nature Power scenarios and broader public-content integration
remain pending. This checkpoint is not yet a published pull request or a new
stable combined testing snapshot. No ROMs, caches, normal saves or mod assets
are included.

## Reproduction

Use maintained LuaJIT at `a4c064539ea931274d407e1249b4bb575424a0f4`.

```sh
python3 tools/enemy-action-contract-check/check.py --gen1 /path/to/read-only-gen1 --lua /path/to/luajit --mode nature_power --report /tmp/nature-power-report.json
/path/to/luajit tests/engine/gen3_nature_power.lua
/path/to/luajit tests/engine/gen3_nature_power_link.lua
```
