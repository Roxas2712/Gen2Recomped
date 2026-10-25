# Native GSC species-name compatibility

Retail Gold/Silver/Crystal imports store Pokémon under `SPECIES_001` through
`SPECIES_251`. The separate Gen1Recomp reference (`535a5ec0`) exposes symbolic
species identifiers such as `EEVEE` and `CHIKORITA`. Mods querying the latter
could miss an existing native species and its extracted front image.

`Gen2SpeciesNames` publishes live symbolic lookups only for verified native
slots in the declared species order. The native row, its identity and its
iteration count are unchanged. Display names are not identity evidence.
Explicit authored symbolic rows and authored lookup metatables retain
precedence. Other games and expanded hacks do not infer these aliases.

The real Pokémon registry uses the same native address for reads, patches,
full replacements, list replacements, removal, conflict preferences and
rollback. New Pokémon requested by a symbolic name store the native species
ID. Existing named save records remain readable without rewriting saves.
Deleted native rows cannot be resurrected by a stale alias. Registry list
replacement metadata follows the same canonical address as its operation.

The ROM-free suite `tests/engine/gen2_species_names.lua` passes 145 checks,
including actual API2 loader success/failure and actual Pokémon creation.
The added list-replacement regression first reproduces the nil operation-list
crash and then passes with the corrected canonical lookup. CI runs the suite
alongside the existing composed engine tests.

This fixes a demonstrated name-resolution gap, not every missing overworld
image. The supplied unchanged Johto package contains a runtime-sheet manifest
but lacks the referenced runtime PNGs; valid native front images and generated
small species images were independently inspected.

The exact `b9aa8f2e` Windows/macOS packages are runtime-qualified on all four
platforms and share an identical payload. With the full unchanged supplied
Johto package and actual Crystal Rev0, OpenGL passes 85 checks and Metal 77:
named/native resolver queries (including the previously missing Growlithe and
Slowpoke), actual ambient sprite/pose bindings, both First/Third outside and in
a Pokémon Center, and four fresh OS-window proofs per backend. The differing
counts follow the mod's declared random one-to-two Center residents. All eight
windows were inspected; individual actors may be outside their camera frustum.
This is binding/selected-scene acceptance, not every species' on-screen art.
See the [scoped receipt](qa/native-foundation/johto-native-species-names.json).

CI passes 367/367 composed engine suites, SDK 3/3 and all quick tiers. The earlier
local quick run stopped at the 20 GiB disk guard and is not used as a pass.
Introduction, map and one-party setup are explicit QA staging. The originals
remain unchanged; only owned QA profiles were used. Complete native story,
PC/mail/capture, field-action protocols, model/effect parity and physical
Windows/Intel GPU gameplay remain open. Existing Metal warnings still obscure
part of some windows. No private assets, ROM data or saves are distributed.

The [existing 20261025.1 release](https://github.com/Roxas2712/Gen2Recomped/releases/tag/native-preview-20261025.1)
now contains these exact qualified Windows/macOS binaries. All six remote assets,
the manifest and release notes were verified; the original tag was retained.
The scoped fix is merged in fork PR27 and offered independently in upstream
[PR261](https://github.com/UNDERdecoded/Gen2Recomped/pull/261).
