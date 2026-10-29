# Source GSC PP operations over native Pokemon

The source `src.battle.gen2.Mon` API exposes `ppUpsOf`, `maxPpOf`,
`partyMoves`, `restoreAllPp` and `repairMoves`. These were absent from the
native adapter, including `maxPpOf` used by the unchanged VASC move-learning
presentation. The adapter now translates those signatures to the existing
native Gen2 PP authority. It returns the actual party move list (or the
source-authored pre-Transform snapshot), and edits the same native slots.

Native GSC healing shares the restore operation. Actual save validation
repairs known moves after the existing species/move ownership checks, including
party, sparse boxes, both breeding slots and a pending egg. A valid legacy
stored maximum infers the bounded PP-Up count; current PP is clamped without
restoring depleted PP. Unknown definitions remain untouched by repair and
retain the source fallback for explicit restore. Other generations keep their
existing healing and PP formula.

The existing Gen2 arithmetic and its provenance remain intact. The new
integration and tests are contributions by Roxas2712; see NOTICE.md and
LICENSE-ROXAS2712.md. This does not provide the remaining experience, growth,
caught-data, source constructor or standalone battle/turn APIs.

Qualified selected source `43f697d8` passes **6642 new SDK/native checks**:
each public method, all base PP values 1..64 with all four PP-Up counts,
malformed legacy maxima, unchanged slot identity, actual healing, real save
encode/decode/validation and non-GSC guards. The first attempt's test setup
incorrectly assumed new-game boxes already existed; the test now initializes
them through the actual `Boxes.load/ensure` boundary. Production code did not
change to accommodate that test error.

The same selected run also passes existing PP852, native fields177, stat
refresh238, party/item1017, battle checkpoint1387 and battler construction972
checks. Receipt: `native-selected-suites-1793246635548135000/receipt.json`.
The exact new fixture run against predecessor main `d822aba8` fails25 real
method-presence probes (five methods across five GSC editions), as expected;
its failed receipt is retained, not presented as a passing run.

Exact composed head `d2555abf` passes950/950engine and4/4SDK suites and
every available official ROM-free tier. All75latest exact-head CI checks
succeed or are skipped; the first macOS transport job was cancelled at its
five-minute limit and one identical-head job rerun passed. Strict merge
`4a28411d` has the identical qualified tree `a5d704af`. Upstream PR401
independently passes6642API/92real item-link checks and five older native
regression groups. No GPU, unchanged-mod
move-learning interaction or packaged-release acceptance is claimed yet.
