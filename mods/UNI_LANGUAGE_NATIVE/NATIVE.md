# Native ROM language packs

This version installs directly in a Gen2Recomped fork exposing
`mod:supports("localization", "rom-language-v1")`. The ZIP contains the shared
language profiles, compiler recipes, fonts, menu and intro. It contains no
`fork/` conversion backend, cartridge inputs or generated language caches.

Install the ZIP through the mod manager. Import the exact English base game,
enable Uni-Language, then open ASCENDANT → UNI-LANGUAGE (or F8). Add the matching
language ROM and choose its language. GBA editions also need their exact
English base ROM once in the mod Imports panel or language menu.

The fork handles native text/name identities, fonts and graphics, optional
imports, language switching and error recovery. It preserves gameplay IDs and
mechanics. Switch from a settled offline overworld or the title screen; finish
dialogue, battles and movement first. A language switch does not write a normal
game save. Existing language profiles and imported inputs are retained.

The original Gen1Recomp path is still included. The native fork can target all
eleven declared editions. The package's accompanying QA receipt describes
exact real-ROM and language coverage; historical `*-QA.json` reports describe
their original versions and must not be treated as current native evidence.

Older Gen2 builds need the native language-pack engine update. No separate
Gen2 mod conversion or repackaging step is required.
