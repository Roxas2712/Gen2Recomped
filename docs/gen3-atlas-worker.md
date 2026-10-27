# Gen-3 source atlas worker

`Performance.atlasWorker` prepares copied Gen-3 source atlas banks in the
existing build pool. `AtlasPixelsCore.run` returns detached RGBA and index
streams plus the initial CPU state. `AtlasPixels.fromCore` restores the
main-thread model without repeating metatile compositing. The live decoder
retains the original bank and animation frame-table references; palette
cycles, palette overrides, edits and uploads retain their existing owners.

The worker path is limited to plain channel-safe data and unchanged native
constructors/decoder methods. Plain mod data edits are copied and validated
again before publication. Functions, metatables, unsupported data, changed
source values, failed workers, retirement and context-loss timeouts retain
the existing coroutine path. Public pending jobs remain typed coroutine jobs;
no pending placeholder enters the resident atlas table. LOW admits two atlas
jobs to the pool's one worker. A five-second timeout bounds lost replies.

IdleStream's central poll publishes through the existing native atlas owner
on the main thread. A required `get` uses a zero-wait timeout: it cancels
pending CPU work and runs the existing constructor, preserving immediate
admission without running unrelated callbacks or adding a 50-ms frame stall.
Textures and resource leases retain their normal publication and retirement.

The ordinary native Gen-3 renderer has a different atlas producer. This
switch targets the source field/atlas bridge; a vanilla scene that never
uses it cannot establish a worker speedup. `check_performance_baseline.py
--atlas-bridge` installs a pass-through source-field callback in its owned QA
host, enters the production replacement boundary with the native game/map/
actors/clock and records actual adapter draws and worker cache provenance.
No alternate simulation or shipping callback is installed. OFF and ON use
the same source and bridge scene. Performance acceptance is pending.

`luajit tools/atlas_worker_check.lua` checks all five GBA editions, exact RGBA
and index streams, live animations and palette edits, reference ownership,
late replies, source changes, cancellation, failure and the independent
switches. The actual graphics-free worker host additionally transports the
production core through LÖVE threads and compares its bytes on LOW.
