# Native GBA map identities

Source: `26d854cddb6fbf3e538beee3a0edc032ef63ab36`.
Upstream: [#234](https://github.com/UNDERdecoded/Gen2Recomped/pull/234),
head `1e591de13bc989ecf7262404627a16c934b7dfce`, based on
[#211](https://github.com/UNDERdecoded/Gen2Recomped/pull/211).

The public map catalogue supplies observed names for physical group/number
slots. FireRed/LeafGreen have 425 slots each, Emerald 518, and Ruby/Sapphire
394 each: 2,156 profile slots. Public names include the reference engine's
legacy `SEVII_*` identities. The table records public API observations from
the clean Gen1 reference `535a5ec088c1ae1bf4d91dd3e35a56f64cf46d91`;
no reference implementation, private mod code, ROM grids or assets were copied.
`tools/gba-map-check` reproduces and checks those observations.

`Gen3MapNames.publish` binds a public name to the actual existing native
definition only when its native key, header group/number and selected edition
agree. The definition, its `id`, grid and native storage key stay unchanged.
Maps sharing a layout keep distinct identities and runtime owners. Unknown
slots do not acquire guessed names. A spelling conversion is available as
metadata but never proves that a physical map exists.

Native identity helpers, map-content registry operations, MapLoader cache,
eviction and native VM writes resolve the same physical owner. Registry edits
through public/native names compose at the native address; replacement keeps
the physical id/group/number. Publication preserves independent authored
conflicts and explicit deletions, handles legitimate replacements and later
native registrations, and refuses to relabel one edition's resident table for
another. Gen1/Gen2 boots do not load this catalogue through the new hooks.

## Verification

- One unchanged consumer runs on both actual native engines for all five
  metadata profiles: 27,213 assertions per engine over all 2,156 slots.
  Canonical names, source symbols, constants where exposed by the reference,
  slot keys, reverse lookup, unknown names and spelling conversion agree.
  Extra edition arguments select catalogue metadata in this fork; they do
  not enable playable LeafGreen, Ruby or Sapphire profiles.
- 132 native ownership/registry/VM/cache/tombstone checks pass both in the
  composition and independently on proposal #211 plus this change. The
  preceding source lacks the new native module and fails the same test.
  A second functional control retains the new catalogue/publication code but
  reverts only the native identity hooks: runtime-name resolution and shared
  Map ownership fail. Passing requires actual native integration, not just a
  dictionary containing two names.
- All 425 maps from the own FireRed import and all 518 from the own Emerald
  import bind to their expected public names. Exact native definition and
  packed source identities are retained. No imported native slot was unknown.
- Source `26d854cd` passes all 269 engine suites, three SDK suites and B30.
- Windows/macOS QA payloads are identical. All 1,037 packaged source files
  match committed input except the declared engine-version stamp. Windows
  PE64/eleven AMD64 DLL and strict macOS signature checks pass. Windows
  hardware execution remains untested; these packages are unpublished.

Separate FireRed and Emerald hardware-GPU runs pass on Metal and OpenGL,
VSync 1, with sixteen fresh owned-window proofs. Public names address the
actual resident native Map and renderer. Public-address entry/return retain
native runtime keys; the real `captureSave` method emits the native key into
an in-memory snapshot. No player save file is read or written. Native layout
edits, actual ScriptRunner changes and GPU floor restoration remain valid.
Stock Sootopolis public-address entry and layouts 8 → 357 → 8 additionally
compare all 3,600 native cell triples and layout observations on both backends.
The `resized` proof phase shows Sootopolis or the native FireRed menu; it does
not accept window resizing. These are explicit fresh unsaved QA entries,
bypassing the introduction, not story or First/Third Person acceptance.

Failed preparatory attempts are retained. The first observation worker used
the wrong working directory; the corrected capture runs in the clean reference.
The first standalone patch expected an adjacent environment hook absent from
its base; only the intended Game hook was inserted at that base's actual
location. The missing local Windows runtime archive was downloaded again from
the same unexpired official artifact and verified against the pinned digest.
Initial Emerald GPU drivers incorrectly expected map entry to update the save
snapshot immediately. The corrected driver explicitly invokes native save
capture in memory. Product source stayed unchanged; failed runs/proofs remain.

## Remaining engine work

`src.core.game3.map` is still absent. The unchanged original OASC fixture
loader was rechecked on this source and still stops there. Native definitions
continue to use native IDs; the original Game3 definition/current-map protocol,
player/atlas/loading/neighbour lifecycles and wider renderer/field/battle
interfaces remain unfinished. The catalogue implements identity readers, not
the reference's tileset/pointer/ROM registration pipeline. This checkpoint
does not establish full original OASC/VASC2 compatibility or a parity percentage.

The mod port remains paused. Protected Gen1/player installations, source mods
and the existing public preview are unchanged. No private code/assets, ROMs,
extracted grids or saves are committed or packaged.

[Sanitized source-bound receipt](qa/native-foundation/gen3-map-identities.json).
