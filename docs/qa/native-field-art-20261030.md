# Native Gen2 field-art contract

Contributions by Roxas2712. Depends on the native mod contract fixes in #402.
This change accepts the existing `mod.content.field:patch("emotes", record)`
format and connects its values to native consumers. Installed mods remain
unchanged; the native Gen2 content/callback/script defaults remain valid.

Supported art keys: `shock`, `question`, `happy`, `sad`, `heart`, `bolt`, `sleep`,
`fish`, `grassRustle`, `jumpShadow`, `cutGrass`, `fishing`, `fishingFemale`,
and the ordered emote key list `order`.

Native script holds retain all eight emote identities. Bubble drawing uses the
selected asset at the native actor anchor. Grass rustle follows the native
walking phase; a ledge-hop shadow uses the Gen2 horizontal OBJ pair. The native
cut-grass animation uses four cropped leaf pieces instead of substituting the
generic smoke effect when a replacement sheet is available. Native progression,
RNG, script yield/resume, encounter results and field-move completion stay with
their original owners.

The fishing sheet format contains down/up/side 16x8 strips. Crystal's female
sheet is selected from the actual player gender, with male/native strip
fallbacks. SpriteRenderer crops the submitted pose and keeps native palette,
alpha and flip handling. Existing callers of `drawTile(path,x,y,flip)` retain
their whole-image behavior. Warm poses reuse their quads.

Image caches follow asset invalidation/release and path/order changes. Warm
frames perform no image reload or cache-signature allocation. Native player
poses refresh after an asset generation change, including a sprite pack that
becomes ready after the player was constructed. World-owned legacy image
holders are retired on cartridge/data changes. Missing art retains native
fallbacks; this change does not invent new ROM assets or rewrite old caches.

ROM-free validation uses a native API2 mod entry, real registry merge, script
handler, native effect/loose-tile renderer and actual crop submissions. Tests
cover all keys, male/female selection, custom order, world ownership, cache
invalidation, bounds refusal and unchanged Gen1 behavior, alongside existing
Crystal gender, fishing lifecycle and alpha/foreground regressions.

GPU appearance and exact visual parity of animation paths still require
separate device qualification. This is a native asset-consumer implementation,
not a promise that every old cache already contains every reference image.
