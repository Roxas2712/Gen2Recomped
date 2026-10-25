# Native Gen2 follower predicate

`src.world.gen2.Follower` resolves to the existing native optional companion
controller. `setShouldSpawn(fn)` replaces its Gen2 default predicate and
returns the preceding function; nil/false leave it in place. `current(world)`
returns the actual companion in the native NPC/update/draw lists. The setter
receives the original game/world handles and preserves Lua truthiness.

The native controller continues to own interpolation, passability, the buffered
trail, connection carry and rebasing. The public `world.follower.spawn` hook
still wraps the default and may deny it. The legacy predicate applies only to
Gen2: Yellow's controller and the optional GBA hook retain their own defaults.

The predicate is stored as a function on the engine module table. The existing
ModSeams journal can therefore restore it on failed entry or the real loader
teardown, instead of retaining an unloaded mod in a closure. This is a native
predicate/lifecycle surface, not a new species-art or field-action protocol.

## Verification

- `tests/engine/gen2_follower_predicate.lua`: 159 checks with actual mod loading,
  native NPCs, movement, connection carry/rebase, public hook precedence,
  unload, entry rollback and unrelated map-object preservation. Gold, Silver,
  Crystal and Prism are exercised; Red/Yellow/FireRed verify generation
  isolation without cartridge data or a game installation.
- Existing portable follower suite: 3,238 checks across SDK modes and host
  versions; API3 entry compatibility: 103; unified callbacks: 1,816.
- The test deliberately calls `Loader.teardown()` for lifecycle acceptance.
  The SDK fixture's `release()` only restores buses and is not a mod unload.

These CPU checks do not establish that the unchanged supplied package's
follower art, ownership choices, First/Third Person rendering or every story
transition is correct. That live integration remains a separate gate. The
published desktop refresh from `0acb23b7` predates this feature.
