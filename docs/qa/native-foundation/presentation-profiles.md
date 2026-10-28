# Native presentation profile queries

Rendering adapters select their edition family, proportional font and RS sprite layout through `profile.forSession`. These facts now come from the native version registry and existing font module. Queries do not bootstrap another game or choose another cache, save, importer or rules engine. Other generations and unknown editions are rejected rather than redirected to a GBA fallback.

Profiles and nested font/UI records are immutable and reused while their version facts remain unchanged. Replacing a native registry record or changing its label/layout invalidates the cached projection. The cache holds edition metadata only, not a game/session/save. This surface deliberately does not advertise a full gameplay, extractor or screen profile.

Fork source `7372419961` on main `e6020353` passes37 groups, including266 profile checks across all five GBA editions, real native proportional-font measurements, coordinate/battle/Gen2 regressions and both process/mounted-session shutdown contracts. Exact older-public composition `e05a1f91ac` passes24 groups with the same266 checks, retaining its older native controllers. The initial fixture also caught a non-string-ID boolean guard; corrected before qualification.

The unchanged adapter's CPU audit `14c959a524` now draws both battlers and the captured-actor fallback in all five editions; the previous missing-profile failures are gone. Its full UI reaches a synthetic fixture's absent `gText_BattleMenu` record. This is a fixture limit, not a new actual-game failure or visual acceptance. The remaining colour-effect and complete device/provider interfaces stay separate. Reference mods and player saves remain unchanged; managed QA enforces20GiB free reserve.

Contributions by Roxas2712. Existing native code and third-party rights retain their provenance. See NOTICE.md and LICENSE-ROXAS2712.md for Cedric / UNDERdecoded integration permission and visible-credit requirements.
