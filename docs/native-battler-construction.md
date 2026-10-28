# Native battler data and presentation construction

The frozen Gen1 Gen2 battle model can construct its combat data without a
rendering runtime. The shared native controller in this fork constructed
sprites and animation players in the same function as its battler data.
That coupling prevents a plain-Lua constructor from sharing the native
battler representation.

`src/battle/Battler.lua` extracts the existing data construction. It retains
the original party Pokemon, move slots, stats, registry views, merged badge
rules, sleep count, generation-specific toxic initialization and form
personal records. Stage and badge tables remain local to each battler.
It allocates no sprite, picture animation, procedural animation or screen.
It retains the existing held-item and Gen2 model bindings.

`BattleState.makeBattler` uses this same factory and then performs its
existing picture and animation construction. Wild/trainer/link battles and
switches still reach that native constructor; no parallel turn simulator
or replacement artwork is introduced. Original engine authors' rights and
licences remain effective; see `NOTICE.md`. The extraction/integration and
tests by Roxas2712 are subject to `LICENSE-ROXAS2712.md`.

Validation on implementation commit `8025abc7`:

- `tests/engine/battler_data.lua`: 691 checks, in a fresh plain-Lua process
  with no LÖVE stub and presentation modules explicitly rejected. Covers all
  18 registered editions, live identities, save/registry immutability,
  transient HUD state, badge defaults and alternate-form personal records.
- `tests/engine/battler_native_construction.lua`: 972 checks through actual
  wild construction and switches across all 18 editions. Calls the real
  sprite selector and animation factories and verifies that hydration uses
  the original constructed tables and retains their data fields.
- Existing model calculation/completion, RNG link/checkpoint, party scope,
  held-item and round-clock suites: 252, 210, 57, 540, 8982 and 400 checks
  respectively, all passing.

This is a prerequisite for a standalone native model constructor, not an
implementation of Gen1's complete `Battle.new`/turn-execution contract.
Standalone model construction, writable source fields, full visual parity,
unchanged-mod GPU checks and final Windows/macOS release qualification
remain open. No mod, Gen1 installation or player profile is modified.
