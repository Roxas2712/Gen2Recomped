# Additive interface work

Contributions by Roxas2712; see NOTICE.md and LICENSE-ROXAS2712.md.
Reference inspected: Gen1Recomp `2aec7650cb01845a4e98f1dbcf8a5c652990d984`.
The implementations in this change use the fork's native owners.

## Implemented first group

* Installer file copies and preservation readback use bounded 4 MiB native
  streams, including backups and private baseroms. Existing rollback and cache
  root selection remain in the install transaction. Old filesystem embedders
  without native streams retain their previous read/write interface.
* Unified definition records expose optional `battleScaleFront` and
  `battleScaleBack` in the existing 0.25..4 range. They reach the existing native
  renderer fields; no alternate sprite scale state is introduced.
* `mod.content.field:patch("emotes", {...})` accepts `shock`, `question`, `happy`,
  `sad`, `heart`, `bolt`, `sleep`, `fish` paths and a zero-byte-indexed `order`
  list (Lua array positions remain 1-based). Gen2 showemote and drawing read
  the merged field record. New imports extract native bubble art; the Gen2
  import marker requests refresh of older caches. Missing optional art keeps
  the existing fallback. Other generations' emote renderers remain their own.
* Gen3 event identity uses one effective modern flag and ribbon word. Explicit
  `modernFatefulEncounter` edits override bit 31; otherwise `gen3Ribbons`, then
  `ribbons`, then historical unencoded flags are read. Lower ribbon bits are
  retained. Link output derives both boolean wire aliases from that word;
  receive normalizes modern true/ribbon bit before publishing native aliases.
  The obsolete legacy wire flag cannot mark an otherwise unmarked ribbon word.
* Native Gen3 event scripts now edit/read the actual selected party member,
  resolving script-variable slot arguments. Native save decoding reads the
  previously omitted ribbon word; save export encodes modern edits into it.
  Native and compatibility battle observations share the same flag reader.
* Optional M4A cancellation callbacks propagate through the worker, effect prep,
  compressed cry decoder and cry mixer. Work checks at most 1024 samples apart,
  releases partial output/scratch and cannot publish partial warm-cache entries.
  Calls without cancellation keep the existing PCM and scheduling contracts.

Example API-3 entry:

```lua
mod.content.pokemon:patch("PIKACHU", {
  battleScaleFront = 0.75,
  battleScaleBack = 2.5,
})
mod.content.field:patch("emotes", {
  shock = mod.path .. "/assets/shock.png",
})
```

The new NAS tooling and its resource limits are documented in [NAS-QA.md](NAS-QA.md).
Headless validation does not establish native GPU, device-audio or Windows
behaviour. No hosted workflow is started by the NAS tooling.

## Additional Battle, Game3, Save and Link features

The optional API-3 `mod.features.gen1` surface now provides a detached source
GSC battle engine, native-owned Game3 load/script/prefetch sessions, explicit
Gen1 Save-5/Save-4 conversion, Link-3 party codecs and GB trade sessions, and
Game3 block/commit verification. See [the versioned contract and examples](GEN1-COMPATIBILITY-FEATURES.md).
Native Save-4/Link-2 remain the defaults. The additional [cable/relay feature](GEN1-CABLE-RELAY.md)
now supplies the native lobby, durable recovery and explicit common-kernel
synchronous battles. Mail blocks, a trade movie and the separate full
fishing/terrain-emote-sheet contract remain outside those added contracts.
