# Native mod contract fixes, 30 October 2026

Contributions by Roxas2712. Base: Gen2Recomped main
`5d873a82b` (includes native SAVE receipts from #400).
Reference contracts audited at Gen1Recomp `0be34bc76`.

## Implemented in this change

- **A01:** Unified Pokemon front/back scales and battle-theme records for Gen1
  and Gen2. The native battle scale resolver consumes the merged values. A
  shared battle-theme entry cues the selected song at transition, entry and
  checkpoint continuation; native victory/gym roles remain separate. Existing
  image-level scale precedence remains valid. Unsupported Unified Gen3+ fields
  are refused explicitly.
- **A02:** Recursive map-key validation and protected schema diagnostics.
  `extra` validators receive the operation mode as an additional argument.
- **A03:** Gen2 cry pitch/length accept 16-bit values without changing the Gen1
  schema. Each mounted loader/dataset selects its own contract. Cry patches also
  validate their effective value: a partial union must not bypass its range by
  accidentally matching the file-only variant.
- **A04:** `map.occupancy_allowed` surrounds the departed-S.S.-Anne dock ejection
  decision. The ship still disappears; only exact `true` permits staying.
  Context is a detached record; ordinary hook failure isolation applies.
- **A05:** API2 `mod.world:startWildBattle(nativeSpecies, level)` uses the
  existing native encounter admission/transition/completion machinery. Numeric
  level strings remain valid on API2; API3 keeps its stricter argument contract.
  Invalid requests never construct an enemy or mark it seen. Retired exports
  lose admission; native cleanup can still finish once after mod rollback.
- **A06:** Gen3 capabilities now advertise the existing native trainer decision
  hook and friendship-change producer. Other events are not advertised merely
  because their names are recognized.
- **A09:** `SessionLifecycle.endGameSession(game)` retires native overlay/world
  owners and playback while retaining the shared Game module and process
  workers. The launcher uses it before releasing the mounted loader. An
  explicit game reset remains supported. `Sound.stop()` without a name retires
  all effects/queued preparation; `Sound.stop(name)` keeps its existing scope.
- **A11:** `assets:image` validates/normalizes the same mod-relative paths as
  the other asset readers and resolves declared import aliases before caching.

## Compatibility boundaries retained

API2/native callbacks, content and script formats remain the default for
existing native Gen2 mods. These changes do not convert saved Pokemon or rewrite
installed mods. Unified writers still preserve native diagnostic snapshots and
reject values the selected generation cannot represent. Native state, RNG,
encounter construction, transitions and after-battle cleanup remain authoritative.

The complete reference battle-model constructor/turn/event protocol (A10) is
not implemented by pretending it is a screen API. Its existing unsupported
operations remain explicit. Additional Gen3 lifecycle events (A07), the complete
`field.emotes` projection (A08), installer jobs and the further UI/dataset audit
items require separate native-consumer changes and qualification.

## Validation

ROM-free tests use committed synthetic datasets and the real loader/registries,
world facade, native constructors or their admission seam, Story3 policy,
native scale resolver, synthesis request and session owner. No player profile,
ROM or installed mod is used or modified by these tests.

New/extended coverage:

- `mod_contract_priority`: composite keys, invalid validators, cry bounds and
  Crystal -> Red -> Gold loader isolation, actual synthesis request, native
  scale precedence and actual battle music selection.
- `unified_content`: merged battle metadata, failed-entry rollback and
  unsupported-generation refusal, alongside the existing native/Unified checks.
- `api2_wild_battle`: generations 1–3, invalid levels/species, API2/API3 mutual
  exclusion, cleanup/replay/refusal/stale-save cases, real native API2 mod entry
  with development guards, retained exports after rollback.
- `map_occupancy_contract`: default, allow, deny, malformed/throwing answers,
  mutated context and departed-ship removal.
- `mod_asset_image_paths`: normalized image identity, invalid relative/absolute
  paths and both portable-import spellings sharing one image cache entry.
- `session_game_teardown`: real native StateStack retirement, failed exit,
  process-worker preservation, shared Game identity and save preservation.

Existing regression coverage includes API3 entry/world battles/battler records,
Unified callbacks, datasets, Gen2 lifecycle callbacks, Gen3 trainer decisions,
Gen3 friendship, music ownership and mounted/process session teardown.

These are engine contract checks. They do not certify every published mod,
GPU appearance, end-to-end network download, Windows/macOS device behavior or
the unimplemented audit items. Hosted validation uses only the public
Roxas2712/Gen2Recomped repository and standard runners; no private CI dispatch.
