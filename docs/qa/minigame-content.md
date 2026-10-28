# Local minigame content qualification — 28 October 2026

Contributions by Roxas2712. Branch: `codex/minigame-content-setup`.

| Check | Result |
| --- | --- |
| Content validation/publication/profile/consent | 33 passed |
| Mandatory entry gate and separate setup | 21 passed |
| Account profiles, scoped file handles and rename | 26 passed |
| Existing five-game rules, controls and reward budgets | 127 passed, 0 failed |
| Pokéwalker two-device persistence simulation | 29 passed |
| Launcher/catalogue integrity | 8,167 checks passed; 2,693 translations |
| German launcher source audit | 1,072 source strings / 27 views; none missing |
| Actual LÖVE at 360×800 | 41 checks passed |
| Actual LÖVE at 851×393 | 41 checks passed |

The LÖVE tests mount a real ZIP, parse a data-only manifest, decode real PNGs,
publish to a real named profile, restart with the selected pack and render
all five basic games without a single external image load. They also run the
real WalkerArt cache reader and byte-export path using generated cache
fixtures, prepare and install its front/walking sprites, and verify retirement
of cached images after switching profiles. Layout screenshots were inspected
in portrait and landscape; source notices scroll before confirmation.

The fixture pixels are independent test shapes. No user ROM, user save,
credential, external content download or live service is involved. This does
not qualify native Pinball duels, production OAuth, physical device transfer,
third-party asset licences, or the separately edited Slide/Warsheep games.
The existing LÖVE 12 deprecation notice from PackData's `newFile` API remains;
it did not fail reading or publication.

Evidence is local under `.local/qa/`:

* `minigame-content-checks-content-qualified/tests.log`
* `minigame-content-final-utf8/tests.log` — targeted final parser/gate rerun
* `minigame-content-render-content-qualified/report.json` and per-size logs
* `minigame-content-render-content-qualified/*-setup.png`, `*-review.png`,
  `*-installed.png`

Reproduction commands and format/deployment details: [MINIGAME-CONTENT.md](../../MINIGAME-CONTENT.md).
No server deployment or database migration is necessary. These client
changes require a new application build before they appear in an old demo.
