# Private X/Y backend patches

The reviewed backend checkout is Zakuro
`e174910de5e7285581b153cbce05543efb135cd5` (MIT). These patches contain source
changes, not game data or generated game code. Keep upstream licensing and
credits. Integration work is credited to **Roxas2712**.

The existing macOS portability and Ascendant presentation patches enable the
local runtime. Apply the additional performance patches to that checkout:

```sh
git -C .local/pokemon-x/zakuro apply ../../../tools/patches/zakuro-readback-reuse.patch
git -C .local/pokemon-x/zakuro apply ../../../tools/patches/zakuro-macos-shader-handoff.patch
python3 tools/build_pokemon_xy_bridge.py --test
```

Do not apply a patch twice. `git apply --reverse --check` can confirm that its
changes are already present. Never reset a dependency checkout to force a patch
over unrelated edits. The build uses the private Rust homes, managed cache and
space budgets; coordinate its CPU/GPU window with other active tests.

`zakuro-readback-reuse.patch` keeps two required immutable batch snapshots and
at most one retired allocation per capture. It reuses bytes only when
`Arc::get_mut` proves there are no other strong or weak owners. It preserves
snapshot/batch identity, dimensions and the complete image contents. Three
CPU tests cover actual allocation reuse, held-image immutability and resizing.

`zakuro-macos-shader-handoff.patch` keeps small, already compiled SIMD vertex
batches on the Mac emulation thread instead of handing the entire task into
Rayon's pool and waiting on another thread. Interpreted/cold shaders keep the
existing threshold, and large compiled draws remain parallel. NaN tracing
retains its interpreter behavior. A bit-for-bit output/order test covers both
prepared and unprepared programs on either side of the batch thresholds.

The normal launcher loads the rebuilt private bridge dynamically. Reference
bridges used by comparative QA remain private and are retained for rollback.
`pokemon_xy_gameplay_qa.py transition-ab` runs the same owned state and input
script with A–B–B–A ordering under the shared hardware lease. Its report keeps
control runs and focus/QA flags; a quiet control run cannot establish that an
earlier half-second hitch was eliminated by the patch.
