# Additional Battle, Game3, Save and Link QA

Contributions by Roxas2712. Reference: `2aec7650cb01845a4e98f1dbcf8a5c652990d984`.

All testing was sequential on the NAS, in the isolated CPU-7 container with
2 GiB RAM, no extra swap, nice 15 and no network. No local tests or GitHub
workflow ran. The selected successful runs cover 17 suites and 200671 explicit
checks (including the pinned source battle assertions). The report aggregates
individual successful suite results from their respective frozen source
snapshots, not one claimed full CI run. Detailed source hashes and logs are
retained in the private evidence bundle `gen1-battle-save-link-20261029`.

| Suite | Checks | NAS snapshot |
| --- | ---: | --- |
| `gen1_gsc_simulation` | 1914 | `source-1793307652678238000` |
| `gen1_world_session` | 130 | `source-1793308228800019000` |
| `gen1_save5` | 39 | `source-1793307652678238000` |
| `gen1_link3` | 103 | `source-1793308228800019000` |
| `api3_compat` | 124 | `source-1793308228800019000` |
| `gen3_party_codec` | 194540 | `source-1793307652678238000` |
| `gen3_party_transport` | 307 | `source-1793307652678238000` |
| `gen2_battle_model_contract` | 252 | `source-1793307652678238000` |
| `gen2_battle_live_view` | 366 | `source-1793307862325444000` |
| `gen2_battle_queue_view` | 303 | `source-1793307862325444000` |
| `native_map_world_admission` | 70 | `source-1793307862325444000` |
| `native_session_runtime` | 642 | `source-1793308228800019000` |
| `native_session_callbacks` | 52 | `source-1793307862325444000` |
| `native_session_persistent_world` | 175 | `source-1793307862325444000` |
| `unified_content` | 482 | `source-1793308228800019000` |
| `dataset_views` | 104 | `source-1793308228800019000` |
| `gate_registries` | 1068 | `source-1793307862325444000` |

The new suites exercise the actual pinned GSC engine, detached factory ownership,
native world admission/load/prefetch and mod retirement, Save-5 with the actual
source parser, classic/GBA wire output against the actual pinned Protocol,
GB trade commitment/cancellation, metadata rejection, Game3 ordered-seat digest,
stale/duplicate commit and swapped offers. Native regressions cover party codecs,
battles, scripts/sessions, API-3 entry and registry/dataset ownership.

The NAS starter now includes the small tracked test PNGs: omitting them made
headless image dimensions fall back to 8x8 and incorrectly failed the existing
faint-drawing assertion. The unchanged native assertion passes with its fixtures.

These headless checks do not establish live two-application networking, room/cable
UI, relay persistence/recovery, mail transport, native GPU or device behaviour.
The implemented contracts and remaining integration limits are documented in
[GEN1-COMPATIBILITY-FEATURES.md](GEN1-COMPATIBILITY-FEATURES.md).
