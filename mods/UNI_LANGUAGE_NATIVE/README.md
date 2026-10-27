Native fork setup: see [NATIVE.md](NATIVE.md). The native package no longer includes the old `fork/` conversion backend.

# Dual-host compatibility preview 1.8.1-rc.10 (development; language matrix pending)

This preview corrects FireRed/Emerald summary headers and controls, Emerald
move/category badges, localized PP labels and normal/detail views. The same
adapter uses all existing GBA language profiles. Current real-ROM checks cover
English and German; missing Spanish, French, Italian and PT-BR inputs remain
explicitly uncertified. Gen1Recomp's Lua runtime remains unchanged.

Gen1Recomp keeps the original runtime and import workflow. Gen2Recomped uses the
additional `fork/` adapter. Open ASCENDANT → UNI-LANGUAGE or press F8 to import a
language ROM in that host, then select the game language from settled play.

The fork adapter covers Red/Blue/Yellow/Gold/Silver/Crystal. FireRed and Emerald
now compile native localized fonts, menu/scene graphics, world render data,
Pokédex/ability/memo text and common battle templates. Add the exact English
USA 1.0 base ROM in the mod menu once as well as the language ROM.
Native GBC gift/return handlers and Asian layout controls are checked on Gold, Silver and Crystal. Asian control fixtures use bundled fonts; retail Japanese/Korean prose and cartridge-specific artwork still need their source ROMs. German live integration is tested separately. Other language profiles and mod
combinations are not fully certified on the fork.

The fork retains private inputs and preferences in its scoped modstorage folder
across updates and uninstall/reinstall. The original upstream behavior is
unchanged. No ROMs, private profiles or decoded caches are in this archive.

Historical upstream documentation follows.

# Uni-Language Ascendant

Standalone language mod for **Gen1Recomp**, based on the Pokémon Gen 1
Recompilation Project by BOIS CLUB GAMES, LLC
(https://github.com/bryanthaboi/gen1recomp).

## Release 1.8.0

Adds an in-game **ASCENDANT → UNI-LANGUAGE** menu, safe language handoffs and
interrupted-switch recovery. Retains PT-BR and the European expansion, plus **Japanese Crystal** and **Korean Gold/Silver**.
There are **41 localized profiles** across eleven editions, plus the English base.
The optimized binary cache, lazy graphics loading, disabled-language picker,
European menu/graphic translations and PT-BR corrections are included together.

| Editions | Game languages besides English |
| --- | --- |
| Red, Yellow | German, Brazilian Portuguese, Spanish |
| Blue, Ruby, Sapphire | German, Brazilian Portuguese |
| Gold | German, Brazilian Portuguese, Spanish, French, Italian, Korean |
| Emerald | German, Brazilian Portuguese, Spanish, French, Italian |
| Silver | German, Brazilian Portuguese, Spanish, French, Korean |
| LeafGreen | German, Brazilian Portuguese, Spanish, French |
| Crystal | German, Brazilian Portuguese, Spanish, Italian, Japanese |
| FireRed | German, Brazilian Portuguese, Spanish, Italian |

Ten independently selectable menu languages: English, German, French, Italian,
Spanish, Japanese, Korean, Simplified Chinese, Traditional Chinese and Brazilian
Portuguese. Menu support does not imply a game-language profile exists.
Unavailable game languages remain visible and disabled; missing imports and
unsupported profiles have distinct explanations.

## Install

1. Import the exact supported English US base game in Gen1Recomp.
2. Install `uni-language-ascendant-1.8.0.zip` through the mod
   manager and enable it for the desired game.
3. Import the exact language ROM under **Uni-Language Ascendant → Imports**.
4. Launch, select a menu language and then an available game language.

Available as a regular [GitHub release](https://github.com/Roxas2712/uni-language-ascendant/releases/tag/v1.8.0). The exact ROM versions and SHA-1
identities are listed in [the ROM checklist](ROM-Liste.html) and
the source catalog in the repository. File names do not identify a
revision. Sapphire PT-BR reuses the exact Ruby PT-BR source import with separate
Sapphire recipes and authored text. FRLG PT-BR fanpatch sources use revision 1.1;
the recompiler runtime uses its supported US 1.0 base. Do not interchange them.
Fan translation sources and patch identities in the repository retain
their attribution. No ROM, fanpatch, save or compilation cache is distributed.

**Updates preserve imported ROMs, preferences, intro state and saves.** The first
launch rebuilds the language cache once. Uninstalling deletes the mod profile;
reinstalling starts fresh. The intro runs once per profile. Back, Reset profile
and the ROM requirements view remain available. Missing saved imports fall back
to English. During settled offline play, open **ASCENDANT → UNI-LANGUAGE** to import
another supported language ROM and switch without closing the application.
The in-process handoff preserves unsaved progress and reloads the enabled mods.
The first compilation takes longer than a cached switch. Desktop uses a native
file picker; other platforms can import through the launcher. Menu language
changes immediately. Unavailable game languages remain greyed out.

Live switching, real nurse interactions, import validation, progress retention
and tested Ascendant combinations are documented in [Live-switch QA](LIVE-SWITCH.md).

## Verification

Fresh integration checks and exact payload fingerprints are recorded in
[MERGE-QA.json](MERGE-QA.json), with readable scope in
[MERGED-PREVIEW.md](MERGED-PREVIEW.md). They cover the combined payload.

Japanese and Korean scope, native ROM mappings and authored US-compatibility
translations are documented in [Asian Gen2 QA](ASIAN-PREVIEW.md).
All 508 previously unfilled Crystal slots are covered (356 additional native
mappings and 152 authored compatibility translations). Regional game mechanics
remain those of the US base. Native saved-name fonts need the source ROM retained.

The prior branches' evidence is retained with its original version:

- [European preview 5](EUROPE-PREVIEW.md) and [European QA](EUROPE-QA.json).
- [PT-BR gameplay report](PT-BR.html) and 1.5.1 QA in the repository.
- Cache optimization evidence in the repository and
  1.5.2 language-picker release checks in the repository.

Those historical reports are not fresh merged-version results. Scoped fixtures
prepare maps, inventory or Pokémon; they do not inject displayed dialogue.
No complete story playthrough, independent native-speaker certification,
Windows/Linux integration test or two-device multiplayer test is claimed.
The European UI source audit covers a defined set of engine strings; it is not
an assertion that every possible dialogue branch has been reviewed.

Remaining language profiles and exact future inputs are listed in
[Weitere-Sprachen.html](Weitere-Sprachen.html). Available profiles are filtered
out of that checklist automatically.

## License

GPLv3 applies. Existing source and attribution requirements are preserved;
see [LICENSE.MD](LICENSE.MD), [LICENSE-POLICY.md](LICENSE-POLICY.md) and
[VENDOR.md](VENDOR.md). Intro assets and bundled font notices remain included.
