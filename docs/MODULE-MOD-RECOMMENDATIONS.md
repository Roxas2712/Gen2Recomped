# Mods before starting a cartridge

Contributions by Roxas2712. The existing cartridge detail page now includes
installed mods for that edition and a bounded set of recommendations, with
publisher previews or the existing local category illustrations. More cards
can be expanded without leaving the page. Activation uses the normal master
and generation controls, including existing experimental confirmations.

Recommendations use existing ModCompass and user-added indexes. Exact edition
claims take precedence over merely sharing a generation; generation/family
tokens use ModTargets. No target is inferred from a title or Pokémon content.
Explicit incompatible API/engine ranges, experimental/prerelease releases and
unavailable sources are excluded. The live, expiring operator Mod of the Week
leads when it matches; then complete compatible manifests take precedence,
followed by catalogue order. There are no invented ratings or popularity data.
This is metadata-based selection, not a claim of completed gameplay testing.

The installed list and manual imports remain available to guests. Online
recommendations, previews and new direct installations require a signed-in
account. No account page opens merely from drawing the module page. Actual
installation still uses the existing original-repository check, confirmation,
bounded download, archive/manifest validator and provenance storage. Downloads
show status and can be cancelled. Completed packages move into Installed on
refresh; they are not silently enabled by the recommendation panel.

The approved game/account is retained through confirmation and download.
Switching account before commit cancels the staged download. The optional
`expectGame` archive gate validates the real ZIP manifest's edition,
generation, API and engine before replacing installed files. Existing manual
imports and ordinary update callers retain their prior behavior. Game startup
retains existing static preflight; no mod entry code executes in the panel.

Native Pinball and X/Y retain their own formats/installers. GBA hardware or
Pokémon generation alone never makes an RPG Lua package a native-game mod.
Those pages explain the format difference rather than offering invalid ZIPs.

Changed implementation: `src/mods/GameRecommendations.lua`,
`src/import/LauncherGameMods.lua`, installer gate in `LauncherMods.lua`, bounded
resolver and account binding in `LauncherCommunity.lua`, weekly lease use in
`LauncherPresentation.lua`, registration in `RomImporter.lua`, and reviewed
German labels in `LauncherCatalog.lua`.

Validation includes generation/edition filtering, account/edition
changes across confirmation, guest visibility and install policy, bounded
offscreen work, stale/clipped input, generation activation and controls at
280/420/780/1400 pixels. Existing catalogue, community, index, mod-target,
account-header and scrolling regressions also run. The actual LÖVE launcher
renderer is captured at 1440 and 720 pixels using a labelled synthetic offline
catalogue. Thirteen real ZIP/filesystem checks per isolated QA profile cover
successful installation, wrong edition/generation/API/engine, preservation of
an old package on rejection and unchanged manual import behavior. These are
real local archive tests, not a production download or account-login test.

Run the renderer/archive fixture with the project's guarded QA runtime:

```sh
python3 tools/qualify_game_mods_page.py --love /path/to/love --label module-cards
```

Pure suites are `tests/engine/game_recommendations.lua` and
`tests/engine/game_mods_page.lua`; use the existing guarded Lua test runner.
