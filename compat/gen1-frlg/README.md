# Native FR/LG title bridge

Based on the Pokemon Gen 1 Recompilation Project by BOIS CLUB GAMES, LLC
(https://github.com/bryanthaboi/gen1recomp).

Seven reference modules and their original LICENSE.MD are retained byte-exact
at the commit and hashes in provenance.json. Their GPLv3 license and additional
terms remain applicable; the host license does not replace them. No launcher,
ROM, derived asset, audio or save is included.

The bridge supplies the original title controller, background/OAM compositor,
palette effects and a private RNG. Its RNG is presentation/session-local;
the host continues to own new-game trainer IDs, gameplay RNG and save callbacks.
The framebuffer is 240 × 160 at dpiscale 1, so the original shader's screen
coordinates remain native even when the host scales its final viewport.

The cartridge importer adds split copyright/press-start layers, an opaque
border, vertical particle sheet and slash mask. Existing cached assets remain
available; the positive readiness contract requires frlg-native-title-v1.

The pinned boot module also provides the main-menu layout oracle for QA.
The independent host menu keeps OPTION/EXIT and mod callbacks, native 10-tile
CONTINUE geometry, scrolling extension rows and a read-only save snapshot.
