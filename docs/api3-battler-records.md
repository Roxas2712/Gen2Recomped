# API 3 battler records

API 3 exposes each represented Pokémon field directly on a battler and under
`battler.mon`, matching Gen1Recomp's callback boundary. For example,
`ctx.user.hp` and `ctx.user.mon.hp` both address that Pokémon. `stats` and
`moves` initially share the exact public tables. Native Pokémon, stat tables
and move slots retain their engine ownership and identities.
Separate battler wrappers retain independent snapshots, including a bound
battler returned by a hook, while sharing the same public `mon` record.

Changed top-level fields take precedence over conflicting nested edits.
Unchanged flattened fields do not overwrite nested edits. Clearing flattened
`item` or `status` with nil clears the native value. Replacing a nested table
makes the original flat table a detached snapshot; changing that old table
cannot replace the new nested record. Existing validation and atomic commit
rules still apply. Battler metadata, diagnostic native snapshots and the
bound `mon` identity remain read-only.

Native GBA battler IDs are the engine's actual local slots, 0–3. Guest peers
keep their local IDs; they are not global network identities. Previous or
fainted actors retain their recorded position. An absent position is not
invented. Other generations retain their existing ID representation.
The Gen-2 reference passes a Pokémon rather than a separate actor; its
optional `id`/`side` therefore come from that Pokémon and may be absent.
They are not inferred from host-only actor metadata.

## Callback snapshots

Before `next()`, the boundary validates and commits authored edits. API 3
then retains the caller's public snapshots, as Gen1Recomp does. An unchanged
snapshot does not overwrite a downstream mod's committed edits or native
changes when the outer callback completes. Explicit post-next edits still
commit. Repeated next calls retain their existing cached-result behavior.

The explicit EXP-share helper refreshes bound Pokémon after its native
operation; flattened battler/context snapshots remain with their caller.
Event notifications remain detached observations; edits to a faint-event
record cannot revive the native Pokémon. API 2 keeps its nested-only battler
shape and automatic downstream refresh behavior.

## Link compatibility

When a link-affecting mod is enabled, the default full fingerprint includes callback
record ABI revision 1. An older peer with identical content and mod versions
cannot silently enter a battle with different callback semantics. The
hellos also announce `modCallbackRevision` explicitly, so a mod's custom
`link.fingerprint` result cannot erase this runtime gate.
The explicit revision is captured from the loaded mod set before invoking
that hook, including when it edits its metadata argument. Ordinary
vanilla and non-link-mod fingerprints, native command/party revisions and
per-Pokémon trade records retain their existing representations.

## Validation scope

The engine regression covers native write-through, shared identities,
conflicts, helper/snapshot behavior, invalid-transaction atomicity and API-2
controls. A separate linked battle executes public stat edits on both peer
roles and compares actual per-turn state components. Shared workers run the
same consumer through each engine's actual damage hooks and faint producer.
Their raw calculation and RNG observations remain separate from the callback
contract: this change does not complete native chance opcodes, Explosion
faint ordering, other battle commands or whole-mod gameplay acceptance.

Run the shared comparison with `tools/battler_records_contract.py`, supplying
`--reference-root`, `--lua` and a new `--output` directory. A local maintained
QA helper can be selected with `--qa-tools-root` and `--qa-project-root`.
The standard matrix has 24 isolated workers and 216 paired cases: Red, Gold
and all five GBA editions, including actual right-hand GBA doubles. A false
`native_math_equal` or `gba_full_raw_rng_equal` remains visible independently
of callback success. The retained Red/Gold calculation differences and the
classified R/S trailing chance opcode still require native-owner work.
