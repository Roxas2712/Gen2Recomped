# Portable native audio shutdown

An unchanged API-3 startup wrapper calls `src.core.game3.audio.stopAll()` before
its introductory presentation and native boot continuation. Gen2 lacked this
entrypoint, so a real newly imported FireRed session stopped at NEW GAME even
though package initialization and the engine suites passed.

`stopAll()` now ends the current native GBA music/fanfare, native effect players,
borrowed effect observations across source owners and the native cry wait. It
uses Music, Sound and the existing playback leases; polling remains an observer
and adds no audio clock. `stopCry()` exposes the corresponding selective native
operation. Both keep the reference's nil return and are harmless without an
admitted GBA game. A music-stop callback replacing the cohort cannot make the
remaining operation act on that new cohort. Ordinary stopSe and owner unload
keep their existing selective ownership.

The common contract runs the actual public methods on the pinned Gen1 reference
535a5ec and Gen2 with synthetic audio handles: music/effects/cry cessation,
selective cry stop, return shape, idempotence and later silence. Gen2 also drives
actual native playback/boot dispatch, cache reuse and source-owner retirement.
The reference fixture seeds its genuine player slots; it does not qualify its
cartridge import or play path. Actual unchanged-package graphics/gameplay checks
are separate evidence. The initial real failure and all failed QA starters are
retained, rather than relabelled as passes.

Contributions by Roxas2712. Existing source provenance and licence notices remain
in force; see NOTICE.md and LICENSE-ROXAS2712.md. Private mod code and game assets
are excluded from this contribution.
