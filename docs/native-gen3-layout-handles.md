# Native Gen3 layout handles

Source: `8e41e6d4e811bc8647e1b7961e9c96d399493508`.
Upstream proposal: [#232](https://github.com/UNDERdecoded/Gen2Recomped/pull/232),
head `d4256597f3d0a9b53073620cc02e935a41f124b2`, based on
[#231](https://github.com/UNDERdecoded/Gen2Recomped/pull/231).

`Map:gen3Layout()` returns a stable layout handle over that actual native Map.
`src.core.game3.layout_native.fromDecoded` creates an authored layout using a
native Map as its grid owner. Cell queries, `applyOverride`, `setMetatiles`,
`stamp` and `clearOverrides` operate on the same artwork, collision and
elevation patches used by native movement and TileRenderer. There is no
second field simulation, player owner or update clock.

Native script writes, coordinate seals, bulk block replacement and whole-layout
swaps notify the same revision and override observation. Imported source rows
retain stable projection identity and follow replacement source bytes.
Decoded authored cells retain their actual supplied table identity. Source row
stride and cropped movement bounds remain distinct; authored border edits do
not enlarge those bounds. Changing an authored stride retains patch coordinates.
Retired handles and their maps are collectable under LuaJIT's Lua 5.1 semantics.

Imported `cells` and `overrides` are observation projections. Mutating those
raw projections is not implemented; runtime edits must use named mutators.
This is an explicit remaining difference from the Gen1 object's raw mutable
tables. Imported native map words are not SVML worker data. `workerPacked`
only returns an explicitly supplied immutable SVML source while the original
cell table, dimensions and standard readers are retained and no asset override
is active. Authored layouts without that source and ordinary `fromMap`
handles decline the packed-worker path. Worker border and COW artwork snapshots
are detached from the live movement grid.

## Verification

- 226 native ownership/layout checks pass in the composition and independently
  on proposal #231 plus this change. The preceding proposal lacks the module
  and fails the same consumer, rather than supplying a fake layout.
- The existing 246 native grid/VM/restoration checks pass independently too.
- One unchanged constructor/mutator consumer runs in separate processes on the
  clean public Gen1 reference `535a5ec088c1ae1bf4d91dd3e35a56f64cf46d91`
  and the fork for both FireRed and Emerald: 56 checks per game and engine,
  with three additional checks through Gen1's actual SVML importer. Results
  match, including crop/border semantics and detached worker data. This is
  equality for that consumer, not complete engine or raw-table equivalence.
- All 268 local engine suites, three SDK suites and B30 pass. Native public
  field/seam tests also pass with an actual Map fixture.
- Windows/macOS QA payloads are byte-identical. All 1,034 packaged source files
  match committed input except the declared engine-version stamp. Windows
  PE64/eleven AMD64 DLL checks and strict macOS signature checks pass. Windows
  hardware execution is not covered.

The hosted source checkpoint has 63 successful checks and two still running.
The macOS HTTP-worker check initially exceeded its 45-second process deadline;
its one rerun on unchanged code passed on all three platforms. The original
failure log and rerun receipt are retained. That isolated harness copies only
network modules and does not load Map or this layout module.

FireRed and Emerald each pass separate hardware-GPU runs on Metal and OpenGL
with VSync 1. Native layout writes change actual TileRenderer pixels; same-art
permission/height changes retain floor pixels and block actual movement.
Stamping, real `g3_set_metatile` ScriptRunner commands and clear operations
share the same native grid and restore actual GPU floor bytes. Map entry,
FireRed's native menu and return warp remain usable. Emerald additionally
checks all 3,600 live cell triples and their layout observations against stock
Sootopolis layouts 8, 357 and 8 again on both renderers. Sixteen fresh
owned-process/window captures validate presentation. The phase named `resized`
shows Sootopolis or the native FireRed menu; it does not test window resizing.
The FireRed Metal menu and Emerald OpenGL Sootopolis captures were also
inspected visually.

These are explicit fresh unsaved QA entries, bypassing the introduction, not
story progression, physical keyboard testing, full OASC rendering, or First/
Third Person acceptance. Initial failed QA attempts are retained: a missing
host PIL dependency before process launch, a shadowed test-driver variable,
an archive harness requesting a test absent on its base, and nondeterministic
selection between maps sharing layout 8. The final driver selects the verified
native Sootopolis ID explicitly; product source was unchanged for these repairs.

The unchanged original OASC fixture loader was rechecked on this source. It
still stops at missing `src.core.game3.map`. Canonical GBA map/tileset identities,
map loading/neighbors/player/atlas lifecycles and broader rendering/field and
battle protocols remain unfinished. The mod port stays paused. Protected
Gen1/player installations, source mods and the existing public preview were
not changed. QA packages are unpublished; no private code/assets, ROMs,
extracted data or saves are included in this proposal.

[Sanitized source-bound receipt](qa/native-foundation/gen3-layout-handles.json).
