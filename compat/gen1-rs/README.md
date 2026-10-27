# Native Hoenn presentation bridge

The shared bridge now also hosts Emerald's original movie and Rayquaza title.
Twelve additional byte-exact reference sources supply Emerald's own symbols,
song/species enums, scenery and extractors. Including the original RS main
menu and the healthbox comparison oracle, the provenance inventory now contains
178 files. The existing GBA
machine, PPU and isolated RNG are reused.
`Gen3EmeraldPresentation` verifies the exact Emerald cartridge, writes four
complete native manifests and supplies that edition's song and cry identities.
`emerald-native-boot-v1` invalidates only Emerald's old approximate boot cache.
The common host lifecycle measures the title song's end with the existing
M4A synthesizer and preserves native warm attract restart, interruption and
host menu callbacks. No generated assets or cartridge bytes are vendored.
Native movie/title acceptance does not imply native parity for the remaining
Emerald menus, professor sequence or complete story.

Based on the Pokemon Gen 1 Recompilation Project by BOIS CLUB GAMES, LLC
(https://github.com/bryanthaboi/gen1recomp).

`reference/` contains byte-exact, individually hashed reference files from
Gen1Recomp `fb7b0366efcb85e703e9e6d5a8a24d01456a109b`. Their original GPLv3
license and additional terms are retained in `reference/LICENSE.MD`. No
Gen1Recomp launcher files are included. These reference files retain their
own license; the surrounding engine's license does not replace it.

`Loader.lua` supplies an isolated module cache and presentation RNG. The host
bridge connects the original RS movie/title state machines and graphics
extraction to the existing native importer, renderer, soundtrack synthesis,
input stack and save callbacks. Every image and audio program is decoded
locally from the user's exact verified Ruby or Sapphire cartridge. No ROM,
derived image/audio, cache or save is included in this source bundle.

The import matches song headers to the selected edition's own symbols and
reads the original twelve-entry fanfare table. It supplies title, both intro
themes, cycling/surfing, battle/victory and ordinary item/healing cues.
Only Ruby/Sapphire caches are invalidated by `rs-native-boot-v1`; Gen1, GSC,
FireRed, LeafGreen and Emerald keep their existing cache contracts.

The installed `rs-native-bag-v1` adapter imports the native eight-row RS bag,
both gender palettes, pocket graphics, outline cursors and twenty window
frames. RS intentionally has no item icons. Its reference renderer reads a
temporary view of host rows; inventory and item-action callbacks stay with
the host. A narrow font bridge uses the host's already imported RS font 3,
native advances, explicit ROM newlines and native palette. The original
extractor's text reader is bound to the host RS text decoder. Neither bridge
alters the pinned source files. Later adapters supply native party and YES/NO
flows. The native RS berry-tag controller now renders all 43 ROM records and pictures, retains the host pocket cursor and returns through the host bag; native bag TOSS also uses the original quantity/confirmation controller and five original text IRs. Other quantity and medicine paths still have additional parity work.
The adapter corrects the reference renderer's 48px text clip for the berry
grid's spanning CHECK TAG cell to its own native 96px cursor width; otherwise
the final G is lost. The pinned renderer itself remains byte-exact.

`tools/run_lua_contracts.py` runs the standalone adapter contracts, including
`tests/engine/rs_bag_contract.lua`. `tools/run_edition_native.py` runs
`tests/rs_bag_native_driver.lua` with an isolated profile and a verified
cartridge. All native checks use the shared QA storage guard.

`rs-native-summary-v1` adds the original four-page RS summary, including its
page/pane/fade controller, attack ordering, HM refusal, learning callbacks,
egg restrictions and party/PC navigation. The isolated host bridge retains
saved Pokemon objects, stable string move IDs and each slot's PP/PP Ups.
Native ROM extraction supplies the page layers, type/status/marking sprites,
closed ball icons, egg portrait, nature names, labels and map-section names.
RS `NAME_END` (FC 00) is a zero-operand town-name marker; the host decoder
accepts it only for explicit Ruby/Sapphire map-name reads, retaining strict
unknown-control rejection and the existing general text-scan boundaries.
Temporary presentation aliases cover imported trainer, secret ID, marking,
Pokerus, language, status-word and ball fields without rewriting saves.
The standalone `tests/engine/rs_summary_contract.lua` contract and
`tests/rs_summary_native_driver.lua` fixture exercise the summary adapter.
Use the common Lua-contract and native-edition runners described above.

`rs-native-party-v1` adds the native RS party panels, palette selection,
HP/status/item sprites, icon animation programs, original prompts, descriptors
and action menus. The host keeps switching, battle, medicine and item callbacks.
Field moves precede SUMMARY; eggs have their native restricted action list.
The item submenu clamps and returns to its parent cursor on B/CANCEL. Single,
double and team-selection navigation retain the native button/column behavior.
The summary returns to the last Pokemon selected there. Full two-tile native
font 4 cells are extracted independently; the host's eight-pixel small face
omits the top tile and cannot substitute for the original party font.
Team eligibility excludes eggs/fainted members and retains the caller's
eligibility rule. Chosen members keep their order descriptor without being
tested as their own duplicate. Long nickname runs are clipped only for display
at a same-line native descriptor field; saved names stay intact and the pinned
renderer stays byte-exact.

RS manifests now select the actual sized icon symbols. Structural discovery
previously selected a pointer 28 entries inside the icon table and supplied the
wrong artwork for all 411 species records. The native 440-entry table and six
palettes are validated; egg and 27 additional Unown forms have their own assets.
The party driver compares all 411 ordinary decoded icons and 28 extras to
independently selected native ROM tables. Transparent pixels' RGB values are
ignored only when both alpha values are zero. Original reference palette
rounding is retained for extra icons; host ordinary-icon palette flooring is
retained for existing assets. Mail reading/composition and some item-message
overlays still need separate native implementations; this is not all-flow parity.

`rs-native-map-v1` supplies the original RS wall/Fly map, its 88 section names,
420 cursor cells, layers, player/cursor sprites, fly markers, special section
and heal tables. The original controller keeps its four-frame cursor tasks,
grid limits, visited-town gates, fades and A/B return paths. A temporary host
view provides map types, flags, vars, saved warp coordinates and gender without
rewriting save data. Native Fly choices retain their map IDs and precise heal
coordinates, including the two player homes and separate League destination.
The original popup task retains its slide/queue/wait/erase behavior and the
script's hide flag. Frame composition restores opaque text drawing after a
transparent fill; the graphics scope also restores state after draw errors.

RS header movement/name policy is decoded separately from Emerald: the full
byte at +26 enables the popup, while map types and four exact header exceptions
govern cycling/running/escape. Region names are available before heal/Fly
metadata is generated. Song-name metadata comes from the same 365 native RS
song/effect header matches as the presentation bridge, rather than Emerald's
longer list. Obsolete generic scenes/summary-image requirements are removed
only for RS; native presentation and map readiness gates remain mandatory.
The Pokemon area map, secret-base owner naming, full Pokenav, field events,
whole flight/story progression and other generations remain separate work.

The RS main menu now delegates to the pinned `rs/main_menu.lua`: native
240x160 panels, selected-window dimming, saved player/time/dex/badge summary,
both gender inks, twenty frames, cursor clamping and palette fades. Its ROM
labels are required by `rs-native-main-menu-v1`. The adapter reads the active
host slot once on entry; CONTINUE, NEW GAME, OPTION, title cancel and EXIT
retain host callbacks. Host stable species IDs are counted once, with the
native regional/national gates. Custom mod rows and renamed labels retain
the host menu instead of being silently discarded. Native Mystery Events
remains a separate gameplay integration; this does not add an inert row.

The host retains its own save slots. Cartridge save-erasure
and RTC maintenance shortcuts are not ported: they return to a live title;
save management remains available in the launcher. This change does not
complete the remaining RS inventory overlays/Pokénav/field-art, event,
credits/endgame or full-story gaps, and is not a whole-game parity claim.

Native RS Birch and player naming now use the original reference controllers,
ROM text IR, Azurill release/cry/particles, gradient/platform, figure slides,
shrink/fades, keyboard pages, both avatar walk steps and all native font faces.
Their package cache, fonts, palettes and RNG stay private to the scene. The
host creates the opening world only after the selected name/gender is known.
The positive readiness gate also requires these exact-edition resources.
Both cartridge tests enter through NEW GAME with ordinary buttons, exercise
B/NO returns and custom/preset names, and end in the truck with an empty party.
An independent tile/LZ/palette decoder checks all 16,384 portrait pixels per
edition. Final GPU captures include both figures and the native keyboard.

Native checks use `tests/rs_boot_native_driver.lua` in disposable identities:
all three intro scenes, correct legendary/version, actual START/B/START,
nonzero PCM for five cues, and unchanged save contents except the independently
accounted native play clock. Failed early test runs are retained separately.

Native RS starter selection now uses the pinned bag/grass, Pokeball/hand,
portrait growth, labels and JA/NEIN controller. Its callback returns the host
species ID; the rescue script still grants the Pokemon and starts the first
battle. Three native portraits avoid substituting Emerald/host palette data.
RS start-menu row gates are separately verified against their exact
BuildStartMenuActions_Normal/FlagGet instructions: Pokédex 0x801 and PokéNav
0x802. Emerald's 0x861/0x862 fallbacks must not hide these RS rows.

The private RS save adapter uses the pinned save controller and native dex summary over host-owned flags, variables and species IDs. The host active slot and atomic writer remain authoritative. Native save/overwrite cancellation, false/raised-write failures and successful writes are verified in isolated profiles. Host IO uses the original short RS failure label so the message fits the dialogue window.
