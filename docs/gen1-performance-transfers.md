# Gen1 performance transfers

This change follows the ideas in Gen1Recomp
[`7e2307f58c`](https://github.com/bryanthaboi/gen1recomp/commit/7e2307f58cf73af8974bb311570f190eb90e565f)
and [`cd0ea18371`](https://github.com/bryanthaboi/gen1recomp/commit/cd0ea1837167756311ae9167a0b239e480898cfa),
adapted to the fork's native world, audio and battle owners. Existing source
licences and credits remain applicable; the atlas pixel rules retain Cedric's
provenance. New integration contributions are by Roxas2712; see NOTICE.md and
LICENSE-ROXAS2712.md.

## GB images and RED++ atlases

`OverworldState.prefetchAssets` hints the next nonresident connected ring and
prioritizes a warp destination. It reads map and sprite definitions without
instantiating maps/NPCs, executing scripts or advancing gameplay. GBA and later
generations retain their existing streaming paths.

`GbAssetPrefetch` shares the existing BuildWorker pool and IdleStream budget.
It holds at most 64 queued hints and two submitted jobs, with 16 MiB covering
ready CPU pixels plus reserved result bytes. Each decoded image is at most
4 MiB; compressed files have a separate 4 MiB limit. Worker input/temporary
buffers and the existing native image/shared-decode caches are additional.
A five-second timeout stops speculative resubmission until invalidation.

Only ordinary PNGs are eligible. Native mod resolution and exact private-edition
read paths are captured on the main thread. Custom pixel readers/constructors
and shade functions retain synchronous ownership; CacheFs's own path-only
constructor wrappers are recognized. Mutable readers receive clones. Worker
callbacks retain CPU data; actual GPU creation remains at native demand sites.

RED++ plans copy concrete palette rows, borrowed-tile colors and aliases. Native
admission recomputes the signature, rejecting stale palettes before upload.
The worker transport contains each distinct palette once, with numeric palette
indices for tiles and aliases. Stock selectors snapshot each shared row once
per plan; admission builds only the validation signature, without copying RGB
tables again. Custom selectors still resolve and validate every tile, including
selectors that edit a shared row during traversal. The memo lasts for one call,
so palette, tile-group and alias changes before admission still reject stale
output.
Misses, errors, unsupported inputs, disabled workers and unfinished hints use
the original synchronous paths. Normal asset invalidation/session retirement
cancels pending work and releases ready pixels. File edits follow the existing
asset invalidation contract.

The accepted native process-exit owner also shuts down the shared BuildWorker
pool. Mounted-game retirement only cancels its owned hints, so another
cartridge can continue using the pool in the same process.

## Audio priorities

The existing P6 chip worker first handles bounded hints for common effects,
active/team cries, move pitch/tempo variants and imported GSC animation SFX.
Animation scanning has a 1024-instruction budget and never executes the VM.
Definitions resolve when dispatched and are rechecked by the existing warmed
Source admission on first use. Preparation never plays a Source or emits a
sound event. The 16 MiB speculative PCM limit remains; ordinary registry scans
leave 4 MiB for imminent effects. The two-job limit and native playback keys,
arbitration, pitch/tempo and suspend/invalidation behavior are retained.

Lazy chip-worker startup sends the current effect-generation cancellation
command before the first effect. Cache invalidations can advance that generation
before any thread exists; without the startup command a fresh worker would
silently discard those initial requests as belonging to another generation.
The real PCM qualification exercises several invalidations before first startup
and requires the initial priority cry and registry effect to arrive and match
native synthesis.

## Ruby/Sapphire battle paint

Healthbox colors and read-only row options are cached by the five relevant
palette words; in-place palette changes invalidate them. Native panel text,
swap highlights and message glyphs reuse paint records. Coordinates, glyphs,
scissors and error restoration remain with their original native painters.

## Rollback and reproduction

The switches `gbAssetPrefetch`, `audioPriorityPrewarm` and `rsBattlePaintCache`
are independent and default on. For example:

```sh
POKEPORT_PERF='gbAssetPrefetch=0,audioPriorityPrewarm=0,rsBattlePaintCache=0' love .
python3 tools/check_gen1_performance.py --lua /path/to/luajit --love /path/to/love --full
```

The guarded checker uses isolated QA identities and records source hashes,
per-stage logs and results. It runs native cache/warp/audio contracts, real
worker transport, actual GPU atlas readback comparisons, private-edition and
mod-override checks, exact native cry/move PCM checks and the ROM-free test
tiers. Synthetic graphics and audio fixtures are owned by the tests; no ROMs
or player profiles are required. Pixel/PCM equivalence and reduced temporary
paint records do not establish whole-game FPS, handheld energy or seam-time
speedups.
