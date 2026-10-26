# ROM language pack integration

The modules in this directory derive from Uni-Language Ascendant's local
Gen2Recomped adapter, written by Roxas2712 in October 2026. They retain that
project's GPL-3.0 licence and existing third-party notices. Original changes to
these derived modules and `src/mods/Localization.lua` are provided under GPL-3.0.
This statement does not change licences on other engine modules.

Source: https://github.com/Roxas2712/uni-language-ascendant

The address metadata in `addresses/` derives from Gen1Recomp's matching public
symbol metadata (GPL-3.0). It contains addresses and extraction descriptions,
not ROM text, cartridge graphics, saves or compiled language caches.

The fork bundles the original compilers, profiles, fonts, menu and intro assets
under `mods/UNI_LANGUAGE_NATIVE/`. They retain the mod's own GPL and
bundled-font/asset notices; `SOURCE.json` records source provenance. The native
entry and manifest are adapted for launcher-owned setup. Font subsets are
extended from a pinned Noto source under SIL OFL 1.1. Private cartridge inputs
and generated language caches are never bundled.
