# Portable asset packs

Mods may declare `required_assets` and `optional_assets` arrays:

```json
{"required_assets":[{"importer":"lttp","pack":"sprites","version":">=1.0.0"}],
 "optional_assets":[{"importer":"lttp","pack":"music"}]}
```

Identities are lowercase letters, numbers, `_` and `-`. Requirements must be
dense arrays, unique across both lists; versions use the existing dependency
range grammar. Unknown optional packs stay unavailable. Missing, incompatible
or incomplete required packs stop the mod before its entry executes and block
hard dependents. The manager reports `missing_assets` and stages a restart once
the requirement is satisfied. The launcher displays the missing pack identity.

`mod.packs` provides `list`, `info(importer, pack)`, `entries(importer, pack)`,
`entry(importer, pack, entryId)`, `read(importer, pack, entryId)` and
`metadata(importer, pack, entryId)`. Calls return data or `nil, reason`.
Enumerated entries are sorted; nested metadata is detached from the stored
descriptor. Undeclared packs cannot be read through this API.

## Installing an existing extracted pack

Copy a portable pack directory, including its `pack.lua` and referenced files,
to `imports/asset_packs/<importer>/<pack>/` in the active game-data folder.
Select **Install asset packs from inbox** in the launcher's Mods panel. This
directory flow works with phone file sharing, Android storage and Switch MTP,
without requiring a desktop file picker or a shell command. It preserves the
original inbox files and reports independent failures within a batch.

The current catalogue recognizes `gen5_bw/battle_sprites`, `pmd_red/sprites`,
and `lttp/sprites`, `lttp/tiles`, `lttp/palettes`, `lttp/sfx`, `lttp/music`.
The final two are catalogue placeholders; no audio extraction is claimed.

A format-1 `pack.lua` returns a literal table with `format`, `importer`, `pack`,
`kind`, `version`, `source` (cartridge `md5`, optional `name`/`size`) and keyed
`entries`. Each entry records `file`, `size` and optional display/sprite fields.
`metadata={file="animation.lua",size=123}` references another literal table.
The supported kinds are sprite, tileset, palette, font, sfx, music and sample;
their file extensions are checked. No cartridge bytes or extracted assets are
included in the repository or tests.

Reads are bounded to 8 MiB per descriptor, metadata file or asset. File sizes
are checked before allocation. Data files support literal tables, arrays,
strings, booleans and finite numbers; they are parsed without executing Lua,
with byte, nesting and node limits. Paths cannot leave their pack directory.

The installer yields after each entry, writes content-addressed objects,
verifies staged bytes and atomically replaces `pack.lua` only after copying all
referenced data. Failed writes, truncated writes, failed replacements and
abandoned jobs leave the previous descriptor and its assets usable. Identical
objects are reused. Unreferenced objects after an interrupted install are
retained; the installer never deletes user source directories or guesses which
old assets are safe to remove. Concurrent installations into one destination
are not offered by the launcher.

## Scope and remaining work

This implements the portable pack producer/consumer lifecycle for **existing
extracted packs**. Native cartridge-to-pack extraction for the three catalogue
families, background extraction workers, image/animation parity and physical
device gameplay remain open. A working pack contract does not establish that
an entire mod initializes or is playable. New engine changes also need a fresh
test release before they are present in distributed phone/console packages.

Validation: `luajit tests/engine/asset_pack_contracts.lua` exercises actual mod
loading, dependent recovery, required/optional semantics, detached metadata,
bounded reads, atomic failure recovery, inbox batching and launcher job paths.
The platform flags in this ROM-free test exercise the shared control flow;
they are not physical-device launch or gameplay evidence.
