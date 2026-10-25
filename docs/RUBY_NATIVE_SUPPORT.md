# Ruby native cartridge support

USA Rev 0 SHA-1: `f28b6ffc97847e94a6c21a63cacf633ee5c8df1e`. This adds an independent `ruby/`
import cache, `_ruby` saves and an ALPHA launcher entry. It does not alias
Emerald's cache, map data or cartridge hash.

## Cartridge contracts

`tools/gen3_rs_manifest.py` combines structural table checks with matching
pret/pokeruby ELF symbol identities. Every allocated ROM section in the ELF
must match the supplied cartridge bytes before any symbol is used. Matching
reference source: pret/pokeruby
`5784633ce4ef7ade1a7f2d2d0c288e3d5e6cdd7f`; both RS matching builds pass their
checksum comparisons. The Emerald reference is also byte-verified and is used
only to identify canonical special functions.

The generated manifest supplies 394 maps, 694 trainers, 349 items, 468 song
slots, 138 movement actions, its own pocket numbering and canonical type ids
for the cartridge's abbreviated type names. RS's raw 4bpp normal font and
mapped small healthbox font are decoded separately. Its three compressed
trainer back sheets are validated, decompressed and matched to their owners.
The 1bpp braille face uses the cartridge's own tile map, paired character
halves and MSB-first field blitter. All 64 patterns must match six independent
raised-dot masks. The six RS window/text header bytes and 32-pixel line pitch
are preserved; Emerald keeps its existing centered window contract.

Native script special ids are mapped to the engine's existing handlers by
function identity. Extractor readers use the inverse map: a missing identity
returns no function rather than probing an unrelated native slot. 197 of the
342 specials are mapped; this is not a claim that every story feature works.

Mauville's three RS switches are read from the verified ROM coordinate table
and checked against its map events. The shared beam rules retain RS's own
positions; five renamed Mauville/Petalburg specials map by verified function
identity. Petalburg's door frames/delays are checked against its own ROM.
The generator requires the pinned clean matching source for C-layout metadata.

The save layout is read from the cartridge's fourteen `sSaveBlockChunks`
records, which use RAM pointers and sizes. RS's 15040-byte SaveBlock1 and
2192-byte SaveBlock2 differ from Emerald. The inventory/money encryption key
is explicitly absent; Pokemon game-of-origin remains Ruby. Flags, vars,
bag capacities and storage boundaries are checked, and all 24 substructure
orders are taken from the matching source. Only metadata and hashes are
committed; no cartridge, extracted image, map, audio or speech files are.

The RS Pokédex entry is 36 bytes, with two description pointers. The
manifest now declares that layout, independently checked against the matching
ELF table length and the cartridge's Bulbasaur dimensions. Reading Emerald's
32-byte stride corrupted sizes and size-comparison poses for all 386 dex
entries. A version-specific cache revision rebuilds only stale RS caches;
FireRed, LeafGreen and Emerald markers retain their previous values.

`tests/gen3_dex_entry_stride.lua <cartridge> <manifest>` runs the real extractor
and checks all 386 height/weight rows and all four affine pose fields against
independent raw ROM reads. The old 32-byte negative control reproduces 386
corrupted RS species. FireRed, LeafGreen and Emerald control cartridges pass
their own 36/36/32-byte layouts. Both RS manifest generators reproduce the
committed metadata after matching-ELF byte verification. Fresh native RS imports
also confirm the corrected sentinel sizes and the RS-only completion marker.
No cartridge data is written or included by the regression test.

## Validation and reproduction

Candidate `6d74f51` passed the native rendered driver with all mods off:

- Fresh import and Birch speech/naming reach the actual moving truck.
- Real directional input takes the dynamic truck warp; the normal Mom script
  reaches the new house.
- Native save/reload retains the player and the Ruby version and creates
  no Emerald save in the fresh QA identity.
- The actual Route 101 bag interaction opens starter selection, records the
  chosen species in var `4023`, runs the first Poochyena battle and reaches
  Birch's lab through the script's warp.
- Roxanne's real map interaction and native battle return to the field with
  the Stone Badge and TM39. A level 100 Mewtwo is an intentional party fixture
  for this separate arena test, not evidence of a full story playthrough.
- All 22 braille walls decode without unknown cells. The actual Sealed
  Chamber sign opens the ABC wall at its cartridge text coordinates; B closes
  the wall and resumes the native runner. Its rendered view was inspected.
- The captured field/first-battle/healthbox/reward views were inspected locally.

Candidate `c5675e4` additionally passes `rs_gyms_native_driver.lua`: real
walking activates an RS floor switch, its beam picture/passability and saved
re-entry state agree, and Wattson's actual battle awards the Dynamo Badge and
TM34 before disabling all three switches. With a deliberate strong party and
story-state fixture, Randall's actual battle runs every one of the five door
frames in Petalburg and resumes the native script. Both views were inspected.
`rs_gym_puzzles.lua` adds 23 checks for the five aliases, RS switch coordinates,
beam collision, Emerald fallback and Petalburg door writes.

The run used macOS LÖVE 12/Metal with a QA-only renderer configuration, a fresh
own save identity and a migration marker created before boot. Physical
iPhone/iPad, link play and full story/post-game have not been certified.

`tests/engine/ruby_registration.lua` verifies edition identity, type ids
and native/canonical special address spaces. `ruby_save_layout.lua`
roundtrips patterned nonzero save blocks through multiple sector rotations and
checks plain RS inventory encryption and game-of-origin. `rs_braille.lua`
checks mapped 1bpp tiles, dot identities, header geometry and rejection of a
corrupted font (13/13). All five suites pass. The engine
suite is 69/79 passing; the same ten failures reproduce on the unmodified
baseline (64/74).

Reproduce using `tools/run_gen3_native_smoke.py ruby --rom YOUR_ROM
--love YOUR_LOVE12_BINARY --lock YOUR_SHARED_QA_LOCK --driver
tests/ruby_native_driver.lua --speed 8`. The helper snapshots committed
sources and rejects cache reuse if extraction inputs changed.

The generic summary fallback right-aligns each stat value within its own
column. Previously a value beginning at x=120 overlapped the next label at
x=132. The 15-check `summary_fallback_columns.lua` exercises worst-case
three-digit stats and full HP pairs; actual native summary/IV views were
inspected after the change. Extracted Emerald/FRLG window art keeps its own
unchanged layout.

Remaining alpha scope includes the original RS title/intro backdrop (the
engine currently uses its fallback title), several UI art/minigame stages,
and unmapped native specials. Generic `scenes.lua`/`summary_info.png` cache
warnings remain disclosed. This is playable native support with concrete
opening/battle tests, not a complete feature-parity certification.

RS item effects use the cartridge's own `gItemEffectTable`: 163 pointers,
starting with item 13. The generator verifies all 163 pointers against the
matching ELF and C table, including null entries. The previous import used
Emerald's address/count and produced two unrelated records for Ruby instead
of the 63 real effects. `stageOverrides.ITEM_EFFECTS` now supplies the correct
address and count; no item effects are hardcoded by name. The RS cache marker
is `rs-item-effects-layout-v2:` so affected old imports rebuild.

`tests/gen3_rs_item_effects.lua <cartridge> <manifest>` executes the actual
extractor and checks 163 entries / 441 raw effect fields, Potion/Protein/Rare
Candy sentinels and the failing old-address negative control. This is import
metadata evidence; it does not certify every item-use menu or broader story.

All Gen3 editions now dispatch completed walking steps to the existing native
`Gen3Friendship.step`, once per step. This also prevents the generic older
+2/+2/+1 fallback from being applied to Ruby. The independent regression
`tests/gen3_walking_friendship.lua` runs the actual controller branch for all
available Gen3 edition registrations, both coin outcomes and an egg across
256 steps each (all five in the combined sibling QA candidate).
This narrow step correction is not a full friendship/story acceptance.

A rejected HM replacement now returns to the native summary move chooser.
Previously the chooser closed before the refusal and left the underlying
learner non-selectable. The actual native menu/HM-reader regression covers
chooser reopen, unavailable-summary fallback, an already-selectable list,
retired-screen ownership and unchanged moves/PP. Presentation is stubbed in
that test; separate real native input/renderer follow-ups remain necessary.


### RS field message geometry candidate

The matching RS field printer calls establish text at tile (2,15), with
26 columns and four rows from the dialogue-frame code. A separate
`gen3FieldMessageWindow` record supplies the native field theme; it does not
become an Emerald battle-window scan anchor. The version-specific
`rs-field-window-v3` cache marker retains earlier dex/item-effect corrections
and requires an updated RS import. Other versions keep their cache markers.
The actual-cartridge extractor test passes the old-missing-record negative
and an unchanged native battle strip. The fresh native import now passes without mods: 240x160 field UI,
26 columns, the extracted 254-character font, two visible native text rows,
A completion and native choice input. An explicit 204-pixel test line wrapped
to four rows under the old 18-column budget and stays at two rows now. Actual
readyReport rejects the old v2 marker and accepts the fresh v3 cache. Frozen
engine source files remain unchanged. The native proof JSON records hashes;
original RS dialogue frame art, full UI and story acceptance remain open.

## Subsequent RS item-action candidate (native verification pending)

The matching-ELF generator now verifies all ten `sItemPopupMenuActions`
text/handler pointer pairs and the five fixed six-byte pocket rows. RS prints
these in column-major order; the extractor transposes the four-/six-cell lists
for the unchanged native row-major action menu. `REGISTER` retains its real RS
label and toggle; no Emerald DESELECT record is invented. The RS cache marker
advances to `rs-item-menu-v4:`; prior dex/item-effect/field corrections remain.
Other editions keep their markers.

Both cartridge CPU regressions pass ten labels/handler kinds, 22 independent
raw pocket positions, the actual native bag consumer's 22 cells, real grid
navigation/callback methods, registration eligibility, the missing-metadata
negative and an unknown-order rejection. Field-window and item-effect data
regressions remain separate. These are not rendered/input acceptance.

The fresh native no-mod Ruby run at source `35685f3` was aborted during import
when the unchanged **8 GiB** free-disk reserve was reached. It produced no
`edition-result.json`; no native UI failure or pass is inferred. Sapphire's
native action run has not started. The committed
`tests/gen3_rs_item_menu_driver.lua` still needs both fresh native runs for
USE, grid input, REGISTER toggle and quantity cancellation. Previous native
field-window evidence belongs to `91c6aec` and remains historical. No new
native/full-UI/story/mobile acceptance is claimed for this action candidate.
