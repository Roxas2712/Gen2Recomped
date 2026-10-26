# Eingebundener Quellcode

`vendor/src/` enthält Import- und Text-Routinen aus Gen1Recomp von
BOIS CLUB GAMES, LLC, Quellstand `1925fa9f97661f1e2d0922f7c6eb9546d262fd29`.
Die Dateien unterliegen den Bedingungen in `LICENSE.MD`. Sie werden als private
Mod-Module geladen; es werden keine installierten Engine-Dateien ersetzt.

Fünf Routinen enthalten die bereits im lokalen deutschen Importprototyp
verwendeten Anpassungen:

- `rs/extract_common_ui.lua`: bekannte Cursorlänge trotz größerer Symbolspanne.
- `rs/extract_pokedex_detail.lua`: deutschen Cry-Meter-Tilemap-Ausschnitt wählen.
- `rs/extract_credits.lua`: editionsabhängige Anzahl der Abspannseiten und
  Palettenfarbe der Überschriften.
- `rse/credits_extract.lua`: eigene deutsche Schlussbild-Tilemap verwenden.
- `rse/extract_naming_rse.lua`: Tastaturzeilen und Spalten aus den ROM-Tabellen
  bestimmen.

Die Profile enthalten ausschließlich Adressen, Größen, symbolische Bezeichner
und Formatparameter. `tools/export_assets.lua` im Entwicklungsprojekt zeichnet
die benötigten Metadaten während einer Extraktion der überprüften ROMs auf.

`tileset.lua`, `metatile.lua` und `native_pack.lua` erzeugen zusätzlich die
Welt-Atlanten. Die Profile enthalten hierfür nur Adressen und Paarzuordnungen,
keine Grafikdaten.


Die Anzeigeadapter unter `gb/runtime/`, `gb/adapters/` und die Hilfsfunktionen
unter `gb/shared/` basieren auf der vom Nutzer bereitgestellten lokalen
Translation German Universal 0.2.0 (Roxas2712). Die früheren extrahierten
Sprachkataloge und PNG-Dateien werden nicht verteilt. Die neue Kompilation
rekonstruiert diese Inhalte aus der privaten ROM anhand der Adressrezepte.
Metrische Pokédex-Maße sind separate numerische Anzeigemetadaten; insbesondere
bleiben die US-Gewichte für Gen2-Kampfmechanik erhalten.

Die Gelb-Titelanordnung wurde zusätzlich mit dem zu dieser ROM passenden
Disassembly https://github.com/Brianum/pokeyellow-de abgeglichen. Das Paket
enthält daraus keine Bilder oder ROM-Daten.

Die Menüs verwenden umbenannte Glyphen-Teilmengen von Noto Sans CJK Regular
unter SIL OFL 1.1. Herkunft: https://github.com/notofonts/noto-cjk .
Lizenz und Copyright stehen in `fonts/OFL.txt`; `fonts/SOURCE.txt` beschreibt
die Änderung. Diese Schriftlizenz gilt unabhängig von der Mod-Quellcodelizenz.

Das einmalige Intro unter `intro/` wurde unverändert aus dem vom Nutzer
bereitgestellten Origami Ascendant übernommen (Origami-Innenraeume,
`gen3/integrated/ascendant_startup`). Die fünf Bild-/Klangdateien stimmen mit
dessen `ASSET-SHA256.json` überein. Herkunftshinweise stehen in `intro/SOURCE.txt`.
Die neue Ablaufsteuerung und editionsübergreifende Erststartmarkierung liegen
in `intro.lua` und `startup.lua`.

## Emerald FR / IT / ES (1.4.0)

The new profiles contain address metadata only. Developer tools in
`tools/*emerald_languages.py` derive relocation candidates from the existing
DE symbols, normalize ARM/Thumb code and pointer structures, and validate
indexed tables against the exact user-provided revision-0 ROMs. Pokédex
text addresses use national dex indices; keyboard widths and compressed
palette headers are explicitly checked. Unresolved text keys retain the US
registry entry. This is not an independent full decompilation comparison.

`latin_glyphs.lua` extends the synchronous text decoder with the Latin font
indices already represented by upstream `FrlgFont.LATIN_GLYPHS`, plus localized
ordinal/PC/Pokémelle font cells. Decoder changes are restored after extraction.
The runtime does not include source ROMs or extracted game asset packs. The accompanying QA document contains screenshots from local gameplay tests.

### Text corrections in 1.4.1

`script_emerald_texts.py` decodes pointer operands using the upstream Emerald
opcode schema instead of treating arbitrary 0x08 bytes as pointer boundaries.
Seed patterns must be unique in both ROMs; matching control-flow references
propagate the mapping. `boundary_emerald_texts.py` verifies text runs against
both adjacent script/data boundaries. `players_emerald_texts.py` validates the
four indexed dynamic player-count strings. The audit JSON remains development
material, outside the distributed archive. Live tests compare every added or
changed registry key to decoded bytes from the exact input ROM on cold/warm load.

## European preview

The new `european.lua` adapters and the EU metadata builders are newly written
GPL-covered additions. They do not copy a separate translation mod runtime.
The supplemental UI catalog in `translations/european/gb-ui.json` started with
70 authored phrases. Preview 2 adds machine-assisted drafts of public, English
engine UI literals (Google Translate), with manual terminology, placeholder,
font and fixed-field corrections in `gb-ui-overrides.tsv`. No private ROM text
was sent to that service. The checked-in catalog builds offline; no translation
service is used by the mod. This is supplemental interface text, separate from
the retail text recipes.
The retail alphabets are factual encoding mappings cross-checked with
PKHeX's StringConverter2 and the exact Spanish Crystal disassembly.

Development sources (private checkouts and byte-identical builds are excluded
from the package):

- https://github.com/CompuMaxx/pokefirered-europe · e184c5cf898cd29efebd33bc1bfe5994277e21ab
- https://github.com/pret/pokegold · ef0201d8daf47e8b3ea1518eacf890f37d4cd5e8
- https://github.com/pret/pokecrystal · 3bc8daa4173e96a7f4011dad3922eb6fa5dad5c6
- https://github.com/einstein95/pokered-es · 6caaf44d56f87db76cbf72c54afd5ec4af8c2fa3
- https://github.com/erosunica/pokecrystal-es · 923900505b6914b89bd5aef618eadbd35e263bab
- https://github.com/jherediagu/traduccion_es · 2cc5ee443d478a7dd47277433a11e51c9e76dc59
  (factual GB table addresses and encodings only; no runtime or authored
  translation catalog is copied). Yellow adds audited far-pointer references
  and contiguous text-bank metadata under `tools/data/`.

No cartridge text, artwork or music payloads from those development sources are
distributed. The player supplies the exact private retail cartridge images.
## PT-BR profiles and authored additions

PT-BR profiles import the user’s exact private translation ROM. Source projects,
versions, patch hashes and resulting ROM identities are documented in
`tools/ptbr_sources.json` in the repository. They include hydhyro’s Gen1 projects,
the separately credited Gold/Silver/Crystal translations, OJ Abreu’s Ruby source,
Zambrakas’s Emerald translation and the referenced FireRed/LeafGreen project.
No source ROM or fanpatch is distributed with this mod.

Sapphire supplements, move/ability display vocabulary, scene corrections and
new pixel lettering are supplied as mod-authored data. Source hashes identify
where corrections apply; numeric gameplay IDs remain unchanged. Original
translation attribution is retained rather than assigned to this mod.

Three additional private extractor changes support these profiles:

- `extract_intro.lua` retains the cartridge's black backing beneath the blinking
  title prompt instead of exposing the unused background band.
- `pokedex_chrome_extract.lua` accepts an explicitly scoped entry-layout override
  for a translated ROM whose Pokédex structure differs from the base revision.
- `rs/extract_storage.lua` supplies the PC transition bar path relative to the
  storage asset directory, as required by the native PC renderer.

These changes are confined to the mod's private importer copies. The installed
engine files remain unchanged.


## Asian Gen2 profiles

Korean symbol/reference work uses [Narishma-gb/pokegold-kr](https://github.com/Narishma-gb/pokegold-kr) at `c90f31dadef17f033a8f1bdada701b26cef18241`. Both locally rebuilt outputs were checked against the exact supplied retail SHA-1 identities. No ROM, extracted font bitmap, or complete extracted cartridge script is distributed. Profiles contain offsets and character maps; source bytes are read from the user's verified import.

Japanese character encoding follows the explicit Japanese charmap in the pinned local [pret/pokecrystal](https://github.com/pret/pokecrystal) reference. Japanese target addresses are a separate bounded map/script/CPU-reference checkpoint, not addresses borrowed from the incomplete [pokekuristaru](https://github.com/PikalaxALT/pokekuristaru) tree. All catalogued dialogue and named text slots are covered. Japanese Crystal includes 152 authored US-compatibility translations; Korean Gold/Silver include 17 each. Their provenance is listed in ASIAN-QA.json. Engine UI/battle templates are separately authored translations, distinct from cartridge-derived dialogue.

## Dual-host adapter

`fork/lz3.lua` vendors the LZ3 decoder from GPLv3 Gen1Recomp commit
`1925fa9f97661f1e2d0922f7c6eb9546d262fd29`, `src/import/Rom.lua`.
`fork/addresses/` contains address/identifier metadata derived from that same
upstream commit's generated GBA symbol/text tables. Neither contains ROM bytes
or decoded cartridge dialogue. The Gen2Recomped adapter is independently written
against its interfaces; no Gen2Recomped engine implementation is redistributed.

The additional `*_assets.lua` and `*_world.lua` files contain US address and
layout metadata from the same GPL upstream. The GBA adapter reads the installed
Gen2Recomped asset decoder into a private runtime instance; that decoder is
not copied into this repository or the distributed ZIP. Native fonts, menu
images and world graphics are generated locally from verified user inputs.
The six-dot Braille alphabet follows pret/pokefirered `include/characters.h`
and the GPL upstream importer.

### Fork display bridge 1.8.1-rc.7

`fork/gbc_roof_colors.lua` contains only the canonical 5-bit G/S/C RoofPals
numeric display metadata (27 map groups, day/night pairs), checked against
`pret/pokegold` and `pret/pokecrystal`, `gfx/tilesets/roofs.pal`.
`fork/world_palettes.lua` supplies missing per-map render metadata to older
fork imports. It does not contain host renderer code or modify ROM caches.
`fork/type_badges.lua` independently decodes localized type sprites from the
user's ROM using the existing address profiles and installed reader API.
Its output is checked against all 23 native Gen1 English type sprite frames.
PT-BR uses the existing authored names and abbreviations.

### Fork PC label bridge 1.8.1-rc.8

`fork/pc_labels.lua` contains byte offsets/lengths for six digest-validated German GB/GBC inputs. It decodes the user's own ROM at import time; no extracted ROM text or host implementation is distributed. Existing native profile labels take priority. Qualified PC commands are separate from bank withdrawal/deposit verbs. Other profiles reuse their existing RELEASE/PRINT display labels.

### Classic item-list overlay 1.8.1-rc.9

`fork/classic_item_box.lua` is independently written against the installed list/stack interfaces. The layout contract follows Gen1Recomp `1925fa9` and the classic LIST_MENU_BOX geometry; no source-available Gen2 host renderer implementation is included. Native item handlers remain installed. The contribution candidate contains only this independent adapter, tests and a minimal integration point.
