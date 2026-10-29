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

Qualification is pending for this candidate. Its new SDK/native regression
exercises each public method, all base PP values 1..64 with all four PP-Up
counts, malformed legacy maxima, unchanged slot identity, actual healing,
real save encode/decode/validation and non-GSC guards. No GPU, unchanged-mod
move-learning interaction or packaged-release acceptance is claimed yet.
