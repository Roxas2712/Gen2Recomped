# Native GBA Baton Pass continuation

This development branch stacks on #217 and the existing held-item phase work
in #165/#166. Gen1 remains an unchanged, read-only reference.

The native move selects a healthy, non-egg replacement from its owner's
party, transfers stages and the native Baton Pass volatiles, emits the public
switch event, and applies switch-in effects. NPC selection follows the native
type heuristic, including its bounded RNG call in doubles. Player selection
uses the actual generation-specific party screen and cannot be cancelled.
Queued attacks resolve against the new occupant rather than the retired donor.

Linked players transmit their actual mid-turn selection using a validated
turn/order/owner packet. Early reliable-ordered packets are buffered; identical
duplicates are idempotent, conflicting or invalid choices reach the controller
failure path. Spectators consume the same choices without opening a personal
picker. Disconnects remain serviced while the party screen owns input.
The picker uses clamped link-party copies rather than the persistent save party.

Native command revision 3 prevents older rules from entering a full GBA battle.
The raw fixture changes from `cf73a8e083fb8a54` to `c2a03195bc4588f9`, audited
with the unchanged #217 hasher and only the explicit revision token. Native
party revision 1 and older-generation fingerprint goldens remain unchanged.

Focused commands, using the maintained pinned LuaJIT described in the contract
workflow:

```sh
LUA=/absolute/path/to/luajit
"$LUA" tests/engine/gen3_baton_pass.lua
"$LUA" tests/engine/gen3_baton_pass_ui.lua
"$LUA" tests/engine/gen3_baton_pass_link.lua
"$LUA" tests/engine/gen3_baton_pass_packets.lua
"$LUA" tests/engine/gen3_battle_protocol.lua
"$LUA" tests/engine/ui_actions.lua
python3 tools/enemy-action-contract-check/check.py \
  --gen1 /absolute/path/to/clean-reference --gen2 . --lua "$LUA" \
  --report /absolute/path/to/report.json
```

The shared fixtures execute both real move resolvers and the real NPC selector.
They retain all RNG calls, PP/HP, stages, volatile state, seed-source identities
and public switch events. Reference names live on `mon.nickname`; reference
infatuation has a separate active flag and owner pointer, whereas the host's
pointer is the active state. These are explicit schema mappings. Original
failed comparison reports are retained locally.

This is work in progress: full feature regression, clean-commit comparisons,
imported-record smoke, combined-fork integration and PR publication are still
pending. CPU fixtures do not certify GPU animation, pixel equality, a complete
playthrough, global RNG/VBlank scheduling or all native side/volatile producers.
