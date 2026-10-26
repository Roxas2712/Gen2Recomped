# Native GBA follower presentation ownership

An imported follower can retain native `world.follower.spawn`/`input.step`
arguments while assigning its renderer to a native object view. Requiring
`src.world.game3.Follower` now records that importing mod as an actor callback
owner. Its callbacks execute with resource attribution; their `next` calls
execute outside that mod's ownership scope. Return values, native Game/world
identity, nested scopes and error cleanup remain intact. Unloading the mod
removes both callback ownership and the object presentation binding.

`Follower.current` observes the active native world, rejects foreign/retired
worlds and safely rejects incomplete NPC identity. It does not manufacture a
raw NPC fallback or a second follower loop. With no explicit world, the active
native StateStack takes precedence over a stale convenience pointer.

The external fixture now creates the actual NPC, map and player admitted by
the native object facade. It tests the mod's owned presentation rather than
expecting the facade to overwrite the native simulation sprite. The pinned
external mod/manifest/asset bytes remain unchanged and authenticated.

Validation on arm64 LuaJIT:

* 17 authenticated external fixture/edition runs pass, including the previously
  failing unchanged `mystery_dungeon_follower` on FireRed; malformed identity,
  foreign world, renderer stepping and unload cleanup are checked there.
* 13 focused ownership checks cover native argument identity, continuation
  ownership, nil-bearing returns, nested calls, failure and retirement.
* Existing native follower predicate: 3238 checks; Gen 2 setter lifecycle:
  159 checks, both pass.
* API-3 against pinned Gen1Recomp `535a5ec`: qualification recorded in the
  accompanying source-fingerprinted report.

This is a separate compatibility correction. Gen 1/2 palette-index changes
retain their own staged review and scene-acceptance requirements.
