# In-game languages — Uni-Language Ascendant 1.8.0

Open **ASCENDANT → UNI-LANGUAGE** during settled offline overworld play.

- **Game language** loads an imported profile at your current location.
- **Menu language** changes the mod interface immediately, independently of the game.
- **Add language ROM** opens the desktop file picker. Platforms without a host file picker can use the launcher's mod Imports panel.
- **Required ROMs** shows the exact edition, revision and complete-file SHA-1, including the English base.
- **Back / B / Esc** returns to the previous screen or game. Touch and mouse controls include scrolling and Back.

Unsupported languages remain greyed out. A supported language without its ROM is also disabled and says “Import ROM first”. A ROM from another edition or an unsupported revision cannot enable a profile.

The shared menu entry uses the project name **UNI-LANGUAGE** and an ASCII help line so it remains readable in legacy host fonts. The language screen itself uses your selected menu language.

## What “switch” means

The application stays open, but the game session is rebuilt with the newly selected language and enabled mods. The current party, inventory, progression, position and mod save data are transferred in memory. This includes progress made since the last normal save. The switch does not overwrite the normal save file.

This has a loading pause. The first language compilation takes longer than a cached switch. Large Ascendant combinations reload noticeably more slowly than the language mod alone: large development scenarios took tens of seconds per switch on this shared Mac. See the per-run measurements and their limits. This is not a promise of instantaneous text replacement.

Finish dialogue, battles, movement and transitions before switching. Union/trade/online rooms are blocked. The feature changes language within an edition; it does not convert saves between games or generations.

## Ascendant integration

KASC collects the Languages entry through the shared Ascendant descriptor. Without KASC, the fallback hub collects language and VASC entries. Origami Gen3's existing Ascendant menu receives a Languages entry.

The report records the exact tested versions and combinations: Red + KASC + VASC, Gold + KASC + VASC, Red + VASC alone, and Emerald + Origami Gen3. Red uses KASC’s shared root; Gold uses the fallback hub with both mods loaded because that Gen2 session exposes no KASC menu collector. Other mod combinations are not universally certified. Other mods' independently authored story text is not automatically translated by selecting a different cartridge language.

## Recovery

Before teardown, the mod verifies a separate recovery backup in its personal profile. A failed target load attempts to restore the previous language. If the application closes mid-handoff, reopening the same edition offers **Recover interrupted switch**. Restore the backup or explicitly discard it after confirmation. Time spent outside the application is not added to the recovered played time.

Updates preserve the profile and backup. Uninstalling deletes them; reinstalling starts fresh. The normal game saves live separately.

## Evidence

[LIVE-SWITCH-QA.json](LIVE-SWITCH-QA.json) contains current runtime/test hashes, per-process outcomes and scoped memory/timing samples. It covers all 41 localized profiles plus English returns, actual nurse scripts, ten menu-language choices with Japanese/Korean/Chinese rendering captures, progress comparisons, import validation, rollback, fresh-process recovery and repeated switches. Prepared saves supply game state, not displayed dialogue.

The full translation regression baseline has a separate fingerprint in the repository's `docs/Regression-Baseline-1.8.json`. The final handoff/profile and native-menu cleanup and current checks are distinguished in [MERGE-QA.json](MERGE-QA.json). These checks do not claim full-story playthroughs or native-speaker certification. Lua heap and texture memory samples are not measurements of total process RSS.

[International guide, real screenshots and language matrix](https://roxas2712.github.io/uni-language-ascendant/) · [Exact ROM versions and SHA-1](https://roxas2712.github.io/uni-language-ascendant/roms.html)
