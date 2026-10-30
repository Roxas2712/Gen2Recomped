# Gen2 landmark coordinate boundary

Contributions by Roxas2712. Follow-up to the 30 October contract audit, based
on PR #407 for pristine registry folds.

Native API1/API2 landmark records retain their existing OAM coordinates.
Unified API2 and API3 records now read and write screen coordinates, matching
the source contract: native x is screen x + 8, native y is screen y + 16.
Screen ranges -8..247 and -16..239 map to hardware bytes 0..255. The native
registry schema and imported native table remain in OAM units.

The boundary validates authored screen values before conversion and validates
the effective native record before registration. Iteration and reads return
detached projected values. A patch now stores only authored fields, instead of
capturing another owner's coordinates in a full effective-row snapshot.

`gen2_landmark_content` passes 413 checks across Gold/Silver/Crystal, native
API1/API2, Unified API2 and API3. It covers negative/far edges, rejected ranges,
actual town-map/Pokegear drawing submissions, script name consumers, native
marker coordinates after owner preference, rollback and unsupported editions.
`dataset_views` (100), `unified_content` (501) and `mod_supports` (450) also pass.

The tests use synthetic imported data and real native consumers, with graphics
IO observed through the existing test boundary. No installed mod, ROM, player
profile or Gen1 instance is changed. Read-only cross-edition dataset projection
and visual/device qualification are separate follow-ups, not certified here.

Hosted follow-up: a macOS setup failed with DNS resolution while fetching the
public LÖVE runtime, before any engine test started. The setup now uses a
separate acquisition helper with three bounded attempts for transient
network/server/truncated-ZIP failures, validates ZIP contents, and publishes
only a completed archive. Permanent HTTP/certificate failures remain failures.
Six ROM-free Python tests cover this policy and preservation/cleanup. Actual
engine test failures are never retried by this helper.
