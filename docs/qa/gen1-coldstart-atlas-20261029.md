# Gen1 transfer follow-up: cold audio and GB atlas preparation

Contributions by Roxas2712. Existing upstream licences/credits remain applicable.
Implementation details and rollback switches are in
[gen1-performance-transfers.md](../gen1-performance-transfers.md).

## Changes

- Send the current effect generation before the lazy chip worker's first job.
  Invalidating caches before thread creation previously stranded first requests.
- Let obsolete background chip synthesis observe generation/priority changes
  between chunks of 1024 samples. Promote matching pending work by ID; retry a
  priority hint if cancellation won the promotion race. M4A rendering retains
  its existing non-cooperative path.
- Send each distinct GB atlas palette once, using tile/alias indices. Admission
  recomputes the signature without allocating repeated RGB tables. Stock
  selectors memoize shared rows for one invocation; mutable custom selectors
  still validate each tile. Palette, tile-group and alias changes reject stale
  results.

## Native measurement

Apple M2, 16 GiB, macOS 15.8.1, LÖVE 12/Metal, AC power. Each component uses
four serial native processes in before/after/after/before order with fresh
isolated Red profiles and identical hints plus 250 ms lead time. Per revision:
128 atlas acquisitions across four maps and 72 cry acquisitions across three
species. Application caches reset between trials; OS file caches remain warm.
These are component wall/submit times, not whole-game FPS or GPU execution time.

GB atlas comparison: `243a24b7b090d467c14989e7b5572ff547f73406` to
`55e829f7cc1f0263846b79da92db81792640e05e`.

| GB main-thread metric | Before median | After median |
|---|---:|---:|
| Critical atlas acquisition | 0.379 ms | 0.335 ms |
| Service during lead time | 0.498 ms | 0.337 ms |
| Hint + service + acquisition | 0.952 ms | 0.735 ms |

Acquisition p95 fell from 2.007 to 1.422 ms; all 128 prefetches per revision were
ready. Four actual atlas readbacks were byte-identical. Aggregation does not
imply every map improves: PALLET_TOWN's acquisition median rose from 0.421 to
0.487 ms. Process medians varied significantly. Two completed synchronous
control processes from an interrupted control series are diagnostic only and
cannot establish a percentage advantage over the synchronous path. Worker CPU,
energy and whole-game frame times were not measured.

The later audio commits leave the measured GB plan/worker code unchanged. The
main merge adds native atlas ownership/restoration outside the measured global
`gbcAtlasFor` call. See the local evidence bundle for exact component revisions,
raw samples, accepted process intervals and discarded blocks.

## Audio result and qualification

Audio comparison: `42ff9dec449b67bbc3fa8243361cf576ea05d9a0` to
`25dd5e2bbb45a6ad6340094bdf888be3bad8e785` (final runtime code; later report-only commits do not change it).

| Cry demand metric | Before | After |
|---|---:|---:|
| Median, 72 acquisitions/revision | 0.063 ms | 0.067 ms |
| p95 | 0.225 ms | 0.129 ms |
| Maximum | 13.960 ms | 0.310 ms |
| Main-thread ChipAudio.newCry calls | 2 | 0 |

First cry in each fresh process: before 8.546/13.960 ms,
after 0.310/0.258 ms. The identical driver counts
main-thread cry construction separately from worker synthesis. Time spikes
alone do not prove a missed warm-up; this counter identifies actual fallbacks.

All 13 focused qualification groups passed across serial windows:
eleven targeted suites, actual-thread/GPU atlas
qualification (30 checks), and native SoundData/worker PCM qualification
(366 checks). The full checker was interrupted during CPU testing after
the first twelve groups passed. The additional broad CPU sweep completed
467 of 986 suite invocations before its announced slot ended;
this is not a full local pass. The normal PR CI checks the complete ROM-free
tiers on separate GitHub runners. Interrupted attempts are excluded.
Source fingerprints were verified across
all completed groups. PCM tests
cover pre-start invalidations, interruption during synthesis, unchanged live
PCM, pending-job promotion and a gated worker receiving urgent demand. Audio
Source hardware is doubled in the owned PCM fixture; the component benchmark
uses the native imported-cartridge runtime.

The local evidence bundle records the accepted measurement and qualification
intervals; rejected attempts are retained separately.

### CI follow-up

At revision `60ded007a66591e880196e77212203c39841b32c`, the full
[ROM-free CI](https://github.com/Roxas2712/Gen2Recomped/actions/runs/40909304330)
passed 981 engine suites, four modkit suites and all remaining tiers. The
[native pixel/PCM CI](https://github.com/Roxas2712/Gen2Recomped/actions/runs/40909305551)
also passed all thirteen focused groups, including 366 PCM checks.

The sole unexecuted check was macOS HTTP transport: GitHub cancelled its
arm64 job before assigning any runner, and its retry also remained queued.
That workflow now uses the repository's existing `macos-15-intel` pool for
macOS transport coverage. The application code is unchanged by this CI fix.


## Reproduction

```sh
python3 tools/check_gen1_performance.py --lua /path/to/luajit \
  --love /path/to/love --full --out .local/qa/gen1-follow-up
```

The checker uses `qa_storage.py`, ROM-free owned fixtures and isolated QA
identities. The local measurement bundle additionally retains the two exact
controller/driver versions, revision IDs, ROM/driver hashes and source hashes;
it contains no ROM bytes. A process watcher rejected an entire measurement
block upon a detected foreign test/compiler process. This is sampling-based
coordination, not an OS guarantee against unrelated background load.

Immediate playback with no preparation time can still synthesize synchronously;
this work removes avoidable missed preparation and repeated atlas planning.
The switches `audioPriorityPrewarm` and `gbAssetPrefetch` remain independent.
