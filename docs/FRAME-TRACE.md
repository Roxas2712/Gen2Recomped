# Per-frame performance capture

Original contribution by Roxas2712; see LICENSE-ROXAS2712.md.

Where the existing F11 profiler is available, press F11 at the problem scene,
reproduce the slowdown, then press F11 again. Alongside the existing summary,
`performance/frame-trace.json` in the application's LÖVE directory contains
the last 180 frames. The next capture replaces that diagnostic file.
No save payloads, screenshots, stack dumps or automatic uploads are included.

For an unattended startup capture, set `GEN2_FRAME_TRACE=1`. This records
600 frames and writes once after capture, or when closing earlier. An abrupt
process termination can lose the buffered capture. Disk output takes place
outside captured frames. Captures are explicitly instrumented diagnostics,
not accepted FPS measurements.

Each frame records its sequence, relative start, duration, completion status,
window focus and named sections. Each section retains its call count, total
and largest duration, including the start/end of that largest call even when
the individual-event limit is full. Up to 128 individual events per frame include start
times and durations; overflow remains counted in the stage summaries. The
recorder bounds distinct section names to 256 and reports all overflow.
Unfocused or incomplete frames are retained and marked, not silently dropped.

Times describe CPU wall time and submission/waits. They do not measure GPU
execution of an individual draw. Nested sections overlap and must not be
added together. Compare update, scene/window rendering, present, event work,
collector budget and pacing before attributing a driver wait to a shader.
Existing hook self-time measurements retain their original meaning.

Mods and QA can use `require('src.core.FrameTrace')`: `start({frames=180,
events=128})`, optional `setContext('map/weather/view')`, `section(name)`
(returns a closing function), or `add(name, seconds)` for existing timers.
The main loop owns frame boundaries. Call `stop()` then `snapshot()` for an
owned JSON-compatible report, or `write('capture-name.json')` for a bounded
diagnostic path. `FrameProfile.section/add` already feed the recorder even
when aggregate profiling is disabled. Disabled recording allocates no events
and reads no clock. It does not change graphics, collector or JIT settings.
