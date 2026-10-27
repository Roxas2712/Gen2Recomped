# Native GBA trainer controller compatibility

This development foundation aligns the API 3 trainer class and lower-hook path
with the observed Gen1 GBA controller in FireRed, LeafGreen, Ruby, Sapphire and
Emerald. The advertised shared capability remains limited to GSC until the
remaining GBA controller and gameplay work is qualified.

Registered class actions precede `battle.enemy_switch_or_item`. Successful
class actions spend one use for the actual party Pokemon. Registered brains
run after that seam, receive move-slot records and their native usable mask,
and choose a slot; invalid results fall through to native scoring. A throwing
registered brain recovers through the controller's first PP-bearing slot
without repeating the decision or spending another item. The host's explicit
`trainer.brain` full-action callback retains its existing behavior, including
error propagation; it is distinct from a registered GBA slot chooser.

Queued switches read the exact combined opposing-party slot at execution.
They do not repeat fresh-request ownership admission or coerce a changed slot.
This matters for class choices across two trainers, changes to a selected bench
member and original-result mutation. Fresh hook requests still pass the
existing health, active-slot and owning-bench checks during selection. Later
class and bag decisions follow the actual current occupant at that position.

Native checkpoints serialize class budgets as owned mon/use rows and rebuild
the per-mon map against restored party objects. Invalid or foreign rows fail
preflight. This does not extend checkpoint support to missing left battlers.
Trainer item prose remains reachable through ROM labels and the public strings
catalog, including catalog reloads, enemy-name prefixes and stat names.

## Reproduce the shared contract

Registered move brains receive the GBA move-view contract: canonical type
names, numeric `gen3Type` (including NORMAL zero), and power/type-derived
categories. Cartridge aliases such as FIGHT/ELECTR/PSYCHC and legacy
CURSE_TYPE/PSYCHIC_TYPE are normalized in the view. Imported type records
resolve other cartridge IDs by their numeric index. An explicit `gen3Type`
retains priority, and the importer-owned move records are not rewritten.

Run against a clean Gen1 checkout; it is only read, never modified:

```sh
python3 tools/gen3_trainer_contract.py \
  --reference-root /path/to/Gen1Recomp \
  --lua /path/to/luajit \
  --output /path/to/new/qa/output
```

Local runs use `tools/qa_storage.py`; `--qa-tools-root` can select the primary
checkout's QA tools. The runner pins input scopes, hashes every relevant source,
fixture and data file, preserves logs and compares typed records. The source
patch is retained with its SHA, and reports are published atomically. Each of
five editions and five controller modes covers 26 gate/brain cases, eight
actual switch/recovery cases, and 60 type-view/decision cases: 2,350 paired
observations from 150 native workers. `--family gates`, `--family switch` or
`--family types` selects a single family.

The type family covers all 18 standard GBA types, damaging and status moves,
six type encodings, PP masks and the observed category-based decision error.
Gen2 rows pass through the actual `extractMoves` stage and `RomGba` byte
reader, using controlled authored bytes and named inputs. This is a data-stage
and controller contract, not acceptance of a complete cartridge import.

The engine suites `gen3_trainer_gates`, `gen3_trainer_switch`,
`gen3_trainer_class_checkpoint`, `gen3_trainer_types` and `gen3_trainer_text` also run in the standard
quick tier. The switch projection compares selected global slots and actual
PP-slot ownership, rather than assuming both engines have the same internal
action representation. Nickname inputs are explicitly equal before comparison.

Remaining qualification includes autonomous native switching before item use,
full Loader entry/owner rollback and link routing, missing-flank checkpoints,
item presentation and original-mod gameplay. These tests do not establish
complete GBA mod compatibility or physical-device acceptance.
