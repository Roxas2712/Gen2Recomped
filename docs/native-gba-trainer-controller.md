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

## Native received-hit history

`Gen3HitHistory` produces the native numeric fields `expLastHitById`,
`expLastLandedMove` and `expLastHitByType` on the actual recipient. They have
separate owners: direct HP damage updates the attacker before
`battle.damage_dealt`; successful move-end bookkeeping records the resulting
move number and effective type after move-end items. Substitute hits update
landed history without replacing the HP attacker. Endure's zero HP loss is
still a direct hit. Misses, immunities and generic authored `ctx.damage` HP
loss preserve prior history. Global `lastAttacker`, `g4HitBy` and Mirror Move
history continue to serve their different existing purposes.

Weather Ball's replacement move view now reaches native accuracy, events,
post-hit effects and received-hit history without editing the imported row.
R/S multi-hit scripts record history between strikes and write `0xFFFF` on a
failed reached multi-hit script; FR/LG/E retain successful earlier Triple Kick
history after a later miss. Ordinary replacement and Baton Pass construct new
recipients without transferring received-hit history.

Public cold checkpoints retain numeric zero and validate the three unsigned
fields before replacing the save/controller. GBA link command revision **22**
adds role-normalized received-hit history to the fatal active-state component;
previous GBA command revisions cannot enter lockstep. Other-generation
fingerprints and the native party codec are unchanged.

Run the producer contract with a clean read-only Gen1 checkout:

```
python3 tools/gen3_hit_history_contract.py --reference-root /path/to/Gen1Recomp \
  --lua /path/to/luajit --qa-tools-root /path/to/current/tools --output /path/to/new/report
```

Move number and effective type are captured as scalar command state, so a
callback editing the dataset for the next action cannot rewrite an earlier
hit. Authored type-copy modifiers can change the effective type without
rewriting the imported numeric tag.

The contract retains raw HP, Substitute and RNG traces separately from its
history/event comparison. Those raw traces are diagnostic evidence, **not a
passing damage/RNG parity claim**. R/S variance and effect-chance command
ordering, Weather Ball's native damage-multiplier placement, zero-power
normal-script RNG, and Hidden Power's native IV/type producer remain separate
work. Default switch-before-item AI and complete original-mod gameplay are
also still unqualified; this change does not enable the GBA readiness flag.

Qualification for this history slice: all **540 paired cases** (27 action
profiles × four slot layouts × five editions) agree across 40 isolated workers;
**12 focused suites / 57,637 checks** pass, including real cold continuations,
preflight rejection, linked roles and existing registered trainer brains.
Inputs and logs were independently rehashed. The raw-trace diagnostic still
finds **260 differing case traces**: these are retained in the report and are
not converted into a claim of complete battle parity. R/S per-hit held-item
phase scheduling and disobedience producers also need separate qualification.
