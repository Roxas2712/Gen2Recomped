# Release 1.8.0 — integration scope

Uni-Language Ascendant retains 41 localized profiles across eleven editions, plus English and ten independent menu languages. It adds ASCENDANT → UNI-LANGUAGE, exact-ROM import from the running game, an in-process language handoff and interrupted-switch recovery.

## Final runtime

`LIVE-SWITCH-QA.json` records 21 isolated handoff test processes. They cover every supported profile and English returns, actual nurse scripts, player/party/inventory/progression comparisons, preserved mod data, ten menu-language choices with Japanese/Korean/Chinese rendering captures, disabled rows, validated ROM import, rollback and repeated switches. Six additional processes test interrupted progress through three complete stop/relaunch/recovery pairs, one per generation. A separate first-profile check exercises the actual intro/picker, resumed movement, menu locale and a subsequent handoff.

The exact Ascendant versions and combinations are recorded in that report. Red uses the KASC shared root; Gold uses the fallback collector with KASC and VASC loaded; VASC without KASC also uses the fallback collector; Origami Gen3 receives a language entry in its own menu. Normal save files are not written by the handoff. Existing saved state is transferred before normal load notifications let other mods rebind.

Retired LuaJIT traces are flushed at the handoff boundary to stop old language closures accumulating. Repeated German/English samples compare equivalent warmed states. These are scoped Lua heap and texture-memory observations, not process-RSS or universal performance certification.

## Translation regression baseline

The full 113-process regression passed before the final handoff/profile and native-menu cleanup. Its exact runtime hash and individual source hashes are preserved in the repository's `docs/Regression-Baseline-1.8.json`. `MERGE-QA.json` distinguishes that baseline from the final runtime and records the changed startup/session and overlay files. It does not claim that the 113 processes were rerun after the cleanup.

The baseline covers European GBA cold/warm starts, English/disabled starts, European GB/GBC catalog/font checks, all eleven PT-BR cold/warm payload comparisons against committed 1.5.2, six German GB payload checks, eleven language-picker checks and 28 Asian Gen2 dialogue/gameplay/menu/graphics/cache checks. All 41 profiles start. The native Asian source mappings, authored US compatibility texts and regional limits remain documented separately in `ASIAN-PREVIEW.md`.

Fresh final-runtime unit checks include 85 Python tests, 19 Lua groups, all Lua syntax, binary-cache integrity/lazy assets and bounded engine UI source audits. The install/update/uninstall/reinstall check verifies the new files, profile/intro/import preservation, recovery-backup lifecycle and a separate save sentinel.

## Limits

The game language changes after a loading pause, rather than instantly replacing the active registries. Large mod combinations take longer. Switch only from settled offline overworld play. Tests use prepared saves but do not inject displayed dialogue. There is no claim of full-story playthroughs, independent native-speaker certification, arbitrary-mod compatibility, Windows/Linux/mobile native-picker QA or two-device multiplayer switching.
