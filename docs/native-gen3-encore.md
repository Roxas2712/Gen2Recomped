# Native GBA Encore

This branch stacks on #218. Gen1 is an unchanged read-only reference.

Encore records its target's last known move and original slot. It rejects
Struggle, Encore, Mirror Move, unknown/removed moves, exhausted slots and an
already-active Encore after the native accuracy check. A successful command
draws `0..3` and stores three to six residual phases. Known authored moves do
not require a cartridge index. Existing custom handlers and older-generation
policies retain their execution paths.

Turn planning uses the forced move's priority while preserving a chosen
target. An Encore applied after planning also changes the queued action,
recomputing its target with native bounded draws and redirection. Execution
spends the actual learned slot's PP, preserves called-move PP rules and emits
the actual move through public events. Forced FIGHT returns a native move
instance rather than an unrecognized nested descriptor.

Actual residual processing cancels Encore on expiry, depleted PP or a changed
original slot. It does not transfer through Baton Pass. Link state components
include move, slot and duration. Native command revision 4 refuses older battle
rules before party exchange; the native party codec revision stays unchanged.
The raw fixture changes from `c2a03195bc4588f9` to `8be423c61a4477a2`, audited
with the unchanged #218 hasher and only the explicit revision token.

Focused commands:

```sh
LUA=/absolute/path/to/pinned/luajit
"$LUA" tests/engine/gen3_encore.lua
"$LUA" tests/engine/gen3_encore_continuation.lua
"$LUA" tests/engine/gen3_encore_link.lua
"$LUA" tests/engine/gen3_battle_protocol.lua
python3 tools/enemy-action-contract-check/check.py \
  --gen1 /absolute/path/to/clean-reference --gen2 . --lua "$LUA" \
  --report /absolute/path/to/report.json
```

The shared matrix retains every bounded RNG call, PP/HP for all battlers,
move/slot/timer state and public move events, including their actual target.
The reference's `expEncore*` fields and numeric move IDs are mapped explicitly
to the host's native fields and fixture registry IDs. Failed/raw reports remain
under `tmp/encore-qa/`; the checker never edits source code or filters calls.

Development acceptance is in progress. Full regression, clean-commit engine
comparisons, imported-record smoke, combined-fork acceptance and publication
remain to be verified. These CPU fixtures do not certify a complete playthrough,
GPU/pixel equality, global RNG/VBlank scheduling or every other native producer.
