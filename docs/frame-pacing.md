# P1: VSync and the software deadline

The run loop records whether it actually presented a frame. After presentation,
`FrameCap.pace` skips the software wait when VSync is active and the FPS cap is
at least the reported display refresh rate. Without presentation, with VSync
off, with an unknown rate, or with a lower FPS cap, the existing carried
deadline, one-millisecond sleep chunks and stall re-anchor remain active.

The default-on rollback switch is independent of all other performance work:

```lua
require("src.core.FrameCap").vsyncPacing = false
```

Display flags are sampled at most once per second to avoid allocating their
table each frame. Provider/VSync changes invalidate that sample; other display
rate changes are observed on the next periodic sample. Existing option values,
simulation timing, mod interfaces and callback call sites are unchanged.

`frame pacing: sleep` in the existing F11 FrameProfile measures the helper,
including its software wait. `present (GPU wait / vsync)` retains its original
scope. Removing a redundant software wait can move wall time into present
without changing FPS.

The owned-window probe runs the real helper and FrameProfile with the switch
off/on, each after 120 warm-up frames and over 120 measured frames. Run through
the guarded launcher:

```sh
python3 tools/check_frame_pacing.py --love /path/to/love --report /path/to/owned/qa/report.json
```

An older public checkout can use `--qa-tools /path/to/fork/tools`. The launcher
pins inputs, uses a separate QA identity, retains raw profile logs and records
SHA-256 hashes of the actual measured source files alongside the Git parent.

Observed macOS/arm64, 60-Hz display, VSync 1, cap 60:

| Backend | Software wait off/on, ms/frame | Present off/on, ms/frame | CPU off/on, ms/frame |
| --- | ---: | ---: | ---: |
| LÖVE 11.5 OpenGL | 0.50 / 0.02 | 15.96 / 16.47 | 0.786 / 0.558 |
| LÖVE 12 Metal | 0.01 / 0.03 | 16.50 / 16.47 | 1.205 / 1.428 |

These fresh composed-fork measurements used runtime source `c75bb29e`. OpenGL
software sleep calls fell from 6,716 to zero across 120 measured frames. Metal
already needed no software sleeps; its short CPU sample increased. No general
CPU reduction is inferred from these measurements. Both enabled runs made zero extra sleep calls and stayed near 60 FPS, with no
measured interval exceeding 1.5 display periods. These short blank-window
checks establish the pacing decision and its profiler scope. They do not
establish a universal CPU/FPS gain, loaded-world behavior, or handheld results.
