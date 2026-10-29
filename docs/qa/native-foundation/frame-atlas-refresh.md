# Refresh retained render atlases at the native clock

`src.core.game3.tileset_native.refresh(pair)` refreshes a named projection
through the current public `get` owner. It does not advance the native clock
or bind/reset the legacy animation singleton. Session replacement, structural
bank checks, foreign getters, cache replacements and GPU upload ownership stay
with the existing getter.

Consumers retaining `_pairs[pair]` across draws must explicitly refresh each
distinct visible projection before composition. A wet-ground sound query is
not an animation clock owner. Refresh capability is explicit; older providers
without this method retain their existing animation binding path.

The CPU/GPU resource oracle checks all five editions against independently
projected native animation frames, including unchanged simulation time,
unchanged legacy binding, foreign getter/cache ownership and byte-identical
uploaded pixels. Run `luajit tests/engine/native_atlas_resources.lua` with the
repository's test stubs. This contract makes no FPS claim.
