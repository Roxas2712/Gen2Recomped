# Native performance baseline — 27 October 2026

Twelve real 60-second observations qualify the post-Phase-0 renderer at `b15e74c11b0c3c2703f61ff66070a97aec312230`. These are individual samples, not a statistical speedup claim. Frame times are milliseconds; lower is better.

## Hardware and controls

Apple M2, 8 CPU cores, 10 GPU cores, 16 GiB RAM; built-in Color LCD, native 2880×1864 at 60 Hz. The desktop was scaled to 1710×1107 logical / 3420×2214 backing pixels. LÖVE 12.0 development snapshot 20260920 used Metal on M2, with a 1024×768 logical / 2048×1536 framebuffer window.

Each case used a separate owned QA profile, a fresh supported cartridge import, seed 12345, VSync 0 and a software cap of 160. Background frame limiting was disabled. Fixed-step game simulation and native input/collision remained active. Map admission used a QA teleport; the measured seams were crossed by actual walking. No screenshots/readbacks or other heavy local qualification ran during timing. Native cases used no mods; voxel cases assert that only DRAMATIC_SHAPE was loaded.

Frame intervals run from one completed presentation to the next. Section values are inclusive wall times around the native FrameProfile calls, averaged across all measured frames; they cannot be added together. GPU sections time submission, without a completion fence or utilization measurement. `frame pacing: sleep` includes idle work, GC and spin pacing. CPU is process CPU / elapsed time, where 100% is one core; worker CPU is included. Focus changes in fixed HIGH cases are recorded in the raw reports; their background cap remained disabled. The adaptive case must remain focused. All four accepted voxel cases remained focused throughout their measured intervals.

## Whole-frame observations

| Case | Seconds | Frames | Average ms | Maximum ms | Process CPU % |
|---|---:|---:|---:|---:|---:|
| red-pallet-default | 60.012 | 7177 | 8.362 | 29.912 | 48.951 |
| red-route1-default | 60.010 | 7195 | 8.341 | 52.462 | 39.895 |
| gold-goldenrod-day-default | 60.015 | 7160 | 8.382 | 48.079 | 51.390 |
| gold-goldenrod-night-default | 60.011 | 7150 | 8.393 | 36.945 | 58.687 |
| emerald-route101-103-idle-off | 60.001 | 6364 | 9.428 | 243.590 | 85.253 |
| emerald-route101-103-idle-on | 60.007 | 7104 | 8.447 | 212.162 | 48.167 |
| platinum-twinleaf-201-idle-off | 60.001 | 7019 | 8.548 | 94.064 | 73.565 |
| platinum-twinleaf-201-idle-on | 60.013 | 7182 | 8.356 | 110.451 | 41.246 |
| emerald-route119-voxel-voxel-idle-off | 60.015 | 1394 | 43.052 | 129.910 | 108.420 |
| emerald-route119-voxel-voxel-idle-on | 60.007 | 4837 | 12.406 | 182.933 | 106.909 |
| emerald-route119-voxel-voxel-warm-disk | 60.014 | 1221 | 49.152 | 132.315 | 107.927 |
| emerald-route119-voxel-adaptive | 60.019 | 3410 | 17.601 | 108.445 | 103.738 |

## Native seam windows

The window starts with the boundary movement request and ends at the first driver observation after the destination was presented. This is distinct from the maximum over the whole 60-second case. Each row identifies the actual native source and destination.

| Switch case | Source → destination | Path cells | Presented window frames | Maximum ms |
|---|---|---:|---:|---:|
| emerald-route101-103-idle-off | MAP_G00_N16 → MAP_G00_N10 | 33 | 2 | 243.590 |
| emerald-route101-103-idle-off | MAP_G00_N10 → MAP_G00_N18 | 20 | 2 | 183.258 |
| emerald-route101-103-idle-on | MAP_G00_N16 → MAP_G00_N10 | 33 | 2 | 192.741 |
| emerald-route101-103-idle-on | MAP_G00_N10 → MAP_G00_N18 | 20 | 2 | 212.162 |
| platinum-twinleaf-201-idle-off | T01 → R201 | 10 | 2 | 94.064 |
| platinum-twinleaf-201-idle-on | T01 → R201 | 10 | 2 | 110.451 |

Emerald walks Route 101 → Oldale Town → Route 103 (53 native path cells). Platinum walks Twinleaf/header 411 → Route 201/header 342 (10 cells). OFF disables both `idleStream` and `gen4ChunkPrebuild`; ON enables both. The two Emerald crossings do not improve uniformly, and Platinum’s ON maximum is worse in this sample. Treat this comparison as neutral/inconclusive; retain both switches (R7).

## FrameProfile sections

Cells show average / maximum milliseconds per presented frame. “N/A” means no section was emitted on that generation/path; it is not a measured zero. `syncGen3Palettes` dispatch can be timed on earlier generations without doing Gen-3 palette work. NitroAudio measures main-thread update dispatch, not worker DSP completion.

### Pacing / world

| Case | pacing | entities | tiles | FX |
|---|---:|---:|---:|---:|
| red-pallet-default | 1.168 / 5.418 | 0.408 / 1.539 | 0.175 / 1.018 | 0.021 / 0.227 |
| red-route1-default | 1.170 / 5.549 | 0.218 / 0.760 | 0.149 / 0.978 | 0.013 / 0.230 |
| gold-goldenrod-day-default | 0.782 / 5.157 | 0.547 / 2.498 | 0.146 / 1.299 | 0.021 / 0.240 |
| gold-goldenrod-night-default | 0.855 / 5.346 | 0.879 / 3.649 | 0.164 / 1.038 | 0.017 / 0.227 |
| emerald-route101-103-idle-off | 0.265 / 4.560 | 1.189 / 4.606 | 0.564 / 5.351 | 0.028 / 0.360 |
| emerald-route101-103-idle-on | 1.208 / 5.479 | 0.317 / 1.726 | 0.274 / 5.987 | 0.023 / 0.230 |
| platinum-twinleaf-201-idle-off | 0.505 / 4.698 | 1.346 / 13.985 | 1.148 / 68.920 | 0.019 / 0.191 |
| platinum-twinleaf-201-idle-on | 1.321 / 5.664 | 0.498 / 13.830 | 0.458 / 87.307 | 0.008 / 0.175 |
| emerald-route119-voxel-voxel-idle-off | 0.019 / 0.075 | N/A | N/A | 0.153 / 0.610 |
| emerald-route119-voxel-voxel-idle-on | 0.043 / 2.819 | N/A | N/A | 0.121 / 9.681 |
| emerald-route119-voxel-voxel-warm-disk | 0.018 / 0.079 | N/A | N/A | 0.176 / 0.574 |
| emerald-route119-voxel-adaptive | 0.040 / 6.515 | N/A | N/A | 0.161 / 2.281 |

### Presentation / generation passes

| Case | renderer pipeline | zone blit | Gen-4 live | Sun |
|---|---:|---:|---:|---:|
| red-pallet-default | N/A | 0.139 / 0.752 | N/A | N/A |
| red-route1-default | N/A | 0.075 / 0.363 | N/A | N/A |
| gold-goldenrod-day-default | N/A | 0.026 / 0.274 | N/A | N/A |
| gold-goldenrod-night-default | N/A | 0.022 / 0.233 | N/A | N/A |
| emerald-route101-103-idle-off | N/A | 0.019 / 0.180 | N/A | N/A |
| emerald-route101-103-idle-on | N/A | 0.024 / 0.177 | N/A | N/A |
| platinum-twinleaf-201-idle-off | N/A | 0.023 / 0.167 | 1.002 / 68.461 | N/A |
| platinum-twinleaf-201-idle-on | N/A | 0.021 / 0.181 | 0.379 / 86.881 | N/A |
| emerald-route119-voxel-voxel-idle-off | N/A | 0.003 / 0.064 | N/A | 4.769 / 15.871 |
| emerald-route119-voxel-voxel-idle-on | N/A | 0.004 / 3.448 | N/A | 1.502 / 15.688 |
| emerald-route119-voxel-voxel-warm-disk | N/A | 0.003 / 0.056 | N/A | 4.904 / 20.832 |
| emerald-route119-voxel-adaptive | N/A | 0.003 / 0.102 | N/A | 0.004 / 0.163 |

### Palette / audio / present

| Case | syncGen3Palettes | NitroAudio update | native present |
|---|---:|---:|---:|
| red-pallet-default | 0.019 / 0.282 | N/A | 0.255 / 1.285 |
| red-route1-default | 0.022 / 0.509 | N/A | 0.290 / 1.306 |
| gold-goldenrod-day-default | 0.019 / 0.662 | N/A | 0.295 / 1.215 |
| gold-goldenrod-night-default | 0.017 / 0.754 | N/A | 0.259 / 1.532 |
| emerald-route101-103-idle-off | 0.301 / 3.712 | N/A | 0.277 / 1.298 |
| emerald-route101-103-idle-on | 0.109 / 5.631 | N/A | 0.280 / 1.294 |
| platinum-twinleaf-201-idle-off | 0.004 / 0.193 | 0.016 / 1.644 | 0.347 / 1.988 |
| platinum-twinleaf-201-idle-on | 0.003 / 0.084 | 0.009 / 1.983 | 0.324 / 3.766 |
| emerald-route119-voxel-voxel-idle-off | N/A | N/A | 0.578 / 2.111 |
| emerald-route119-voxel-voxel-idle-on | N/A | N/A | 0.572 / 13.289 |
| emerald-route119-voxel-voxel-warm-disk | N/A | N/A | 0.361 / 1.939 |
| emerald-route119-voxel-adaptive | N/A | N/A | 0.755 / 5.968 |

## Route 119 setup: cold, warm disk and warm memory

Route 119 is native `MAP_G00_N34`, 40×140 cells. Requested (10,10) is water; the closest unoccupied native walkable cell was (9,10). Each observation starts once the current full terrain mesh is published; neighbour jobs may remain and continue during measurement. Pending counts make this explicit. Setup uses VSync 0 / cap 160 before building and a 480-second guard.

These intervals include active neighbour streaming, whose amount of work differs between cold and cached admission. They are not steady-state or causal disk-cache speedup comparisons. The warm-disk case starts a new process/profile seeded from the completed idle-ON cache and resets the game save. A true-returning target-map `VoxelDiskCache.load` is required. Warm-memory probes call the public analysis functions again in the same process. Setup durations include cooperative yields; nested calls overlap. `inFlightAtStop` records scopes still open at the readiness cutoff, and snapshots cannot change when a background scope later completes.

| Case | Pending ready/end | Disk hits/misses at ready | Bytes loaded | Open setup scopes |
|---|---:|---:|---:|---:|
| voxel-idle-off | 5 / 5 | 0 / 1 | 0 | 1 |
| voxel-idle-on | 5 / 5 | 0 / 1 | 0 | 1 |
| voxel-warm-disk | 5 / 5 | 1 / 0 | 13730112 | 1 |
| adaptive | 5 / 5 | 0 / 1 | 0 | 1 |

| Case / phase | Structures.forMap | Gen3.prepare | TerrainAtlas.forMap | Grass | Flowers | Figures |
|---|---:|---:|---:|---:|---:|---:|
| voxel-idle-off / cold/disk setup | 33651.143 (123 calls) | 15040.886 (1 calls) | 5.504 (18 calls) | 37339.319 (1 calls) | 26.454 (1 calls) | 0.011 (1 calls) |
| voxel-idle-off / warm memory | 0.005 (1 calls) | 0.014 (1 calls) | 0.006 (1 calls) | N/A | N/A | N/A |
| voxel-idle-on / cold/disk setup | 25592.562 (67 calls) | 5994.320 (1 calls) | 5.425 (10 calls) | 27794.434 (1 calls) | 63.794 (1 calls) | 0.017 (1 calls) |
| voxel-idle-on / warm memory | 0.014 (1 calls) | 0.026 (1 calls) | 0.008 (1 calls) | N/A | N/A | N/A |
| voxel-warm-disk / cold/disk setup | 24586.765 (39 calls) | 9086.757 (1 calls) | 8.328 (6 calls) | 1764.980 (1 calls) | 17.067 (1 calls) | 0.040 (1 calls) |
| voxel-warm-disk / warm memory | 0.009 (1 calls) | 0.182 (1 calls) | 0.008 (1 calls) | N/A | N/A | N/A |
| adaptive / cold/disk setup | 8387.675 (32 calls) | 16990.507 (1 calls) | 4.248 (5 calls) | 8788.888 (1 calls) | 17.239 (1 calls) | 0.014 (1 calls) |
| adaptive / warm memory | 0.016 (1 calls) | 0.026 (1 calls) | 0.008 (1 calls) | N/A | N/A | N/A |

## Adaptive tier and unmeasured targets

Native PREFER FPS log during preparation: `[info] performance: PREFER FPS stepped to balanced`; `[info] performance: PREFER FPS stepped to low`.
The focused 60-second tier trace is in the voxel raw report: [{"seconds": 0, "focused": true, "tier": "low"}].

Android/RG34XXSP: not measured; adb was unavailable in PATH and the checked SDK locations. GPU utilization and 10-minute PREFER BATTERY versus LOW energy consumption: not measured. The machine used external power with zero instantaneous battery discharge; powermetrics required unavailable superuser access. No inferred power numbers are substituted.

## Reproduction and provenance

Run `python3 tools/check_performance_baseline.py --help` for the ROM paths, runtime, backend, scene and variant controls. All starters use the shared QA-storage leases and reclaim only owned disposable copies/profiles. No player profile, game asset or cartridge bytes are published. Statistics/adapter regression: `luajit tests/engine/performance_baseline_meter.lua` (50/50).

Native eight cases: harness commit `b882767be2bff2ffa87e2e3cc8fc0ff43ab2ad67`. They completed before the larger run was interrupted during voxel preparation. The native-only verification index explicitly says `completeWholeRun=false`; no whole-run success or final automatic source-stability check is claimed for that interrupted run. Each accepted case completed at least 60 seconds in an immutable git-archive host.

Voxel four cases: harness commit `e353116cf2a1d48f1fdd15de17df6eda14c0227c`, complete and source-stable. Preparation now waits for the current full mesh, not every neighbour job, and seeds mod options after enabling the native storage scope. Earlier unisolated three-mod voxel measurements are superseded and excluded. Host adapters only enable existing native pacing, run the interactive update with real dt, and add argument/return-preserving profiling wrappers in owned copies. They do not change the shipped runtime.

The measured renderer/mod runtime equals `b15e74c1`; the voxel launcher observed newer main `2fdfe77f0cade522d73fdacd6f8b7128e4c265d5` and correctly records `runtimeMatchesMain=false` because native Gen-2 presentation, options and lifecycle changes (`14169e20`) and #162 landed after the measured runtime. Those changes are not included in this baseline; later Gen-2 comparisons must account for them. The baseline remains explicitly pinned to `b15e74c1`, rather than claiming an exact newer-main measurement.

Raw evidence: [native cases](perf-baseline-data-2026-10-27/native.json), [voxel cases](perf-baseline-data-2026-10-27/voxel.json). ROM SHA-1 revisions and per-host adaptations are recorded there.
