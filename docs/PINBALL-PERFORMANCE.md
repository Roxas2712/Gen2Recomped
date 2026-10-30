# Pinball performance investigation

Contributions by **Roxas2712**. The optional full table remains a beta view;
guest execution still includes explicitly reported interpreter fallback.

## Changes

The full-table host compositor now retains unchanged eight-row bands. Each
band compares the exact referenced map entries, complete tile bytes, palettes,
overlapping object attributes, positions and affine matrices. Changes to the
field or relevant display/blend registers invalidate the cache. This is an
exact byte comparison, not a probabilistic hash. The canonical guest PPU and
every simulation frame still execute normally.

The original uncached host path remains available for comparison with
`ASCENDANT_PINBALL_REFERENCE_TABLE=1`. Both modes must produce the same
pictures and guest RAM checkpoints under identical inputs. This compares two
host composition paths, not retail hardware output. The latest managed
comparison also loads a solo quick state, checks its immediate full-table
picture, and replays forty frames with exact picture/RAM comparisons.

The worker now releases its producer-side ImageData and SoundData proxies
immediately after channel publication. LÖVE channels retain their own native
object references; the receiving proxy remains valid. This avoids retaining
unneeded large buffers until worker garbage collection. The real LÖVE lifetime
test checks 100 image/audio handoffs and a bounded three-image FIFO. See LÖVE's
[Variant ownership](https://raw.githubusercontent.com/love2d/love/main/src/common/Variant.cpp)
and [proxy release](https://raw.githubusercontent.com/love2d/love/main/src/common/runtime.cpp).

Native banners, ball saver, shops and unsupported scenes continue to use the
complete original viewport. Once a board has expanded, recovery to the full
table requires thirty consecutive eligible guest frames (about half a second).
Repeated painting of the same guest frame does not advance that delay. This
prevents brief flag changes from repeatedly resizing the entire pane. An initial
eligible board and a loaded quick state can expand immediately. These are host
layout changes; the original game's flashing effects remain intact.

## What the measurements establish

The managed native reference comparison covered 28,800 matching pictures and
244 matching RAM checkpoints across USA/Ruby and EU/German/Sapphire with the
stable layout policy. A further 9,600-picture / 84-checkpoint comparison checked
the final quick-state layout reset and exact forty-frame replay in both cache
modes and editions. The earlier longer comparison reused about 69% of rendered
Ruby rows and 76% of Sapphire rows. These figures cover the exercised scenes,
not every bonus board or animation.

An actual six-minute, two-player Ruby full-table run completed a full
18,000-frame round: 112,800–71,000 points, correctly awarded to player one, then
started another round. It presented 59.67 distinct game images/s; display p99
was 17.09 ms and the longest window refresh interval was 38.75 ms. However,
there were rare source-picture holds up to 150.04 ms while the window kept
refreshing. This is **not** a zero-stutter result. The old display-only pass
condition missed this distinction and has been tightened to also reject a
source-picture gap of 75 ms or more.

Optional test diagnostics separate native simulation wall time, host
composition wall time and worker thread CPU time, as well as image/audio
handoff and scheduling lateness. They are disabled during normal play. This
lets a slow native step be distinguished from a slow main-window refresh,
without changing guest timing to improve a reported FPS number.

The first four-minute German Sapphire sample exposed a 317.74-ms native step
with only 10.91 ms of worker CPU time. That implicates time outside active
computation, such as scheduling or paging, rather than 318 ms of game work.
The development Mac also reported about 7.9 GiB of swap in use; this alone does
not prove any particular stall was a swap read.

The macOS worker now requests user-interactive QoS while its animation is
active and focused, and utility QoS while paused, waiting, finished or unfocused.
This affects only that worker, using the
[documented pthread QoS API](https://developer.apple.com/library/archive/documentation/Performance/Conceptual/EnergyGuide-iOS/PrioritizeWorkWithQoS.html).
No global priority, swap or power settings change. The actual native worker
focus/pause check observed classes `33 → 17 → 33 → 17 → 33`. Set
`ASCENDANT_PINBALL_DEFAULT_QOS=1` for a comparison using the inherited class.
Older native libraries and other platforms retain their existing scheduler.

In the four-minute German Sapphire repeat with foreground QoS, the worker
reported the expected class change from default (`21`) to user-interactive
(`33`). It presented 59.73 distinct game images/s with no source-picture hold
over 50 ms: worst source interval 38.31 ms, worst native step 19.26 ms. The
prior 318-ms step did not recur in this sample. This supports the scheduling
change on this Mac; it does not guarantee every future load or paging condition.
A single 38-ms window interval remained. Repeated source intervals near 33 ms
are also expected when displaying a 59.7275-Hz guest on a fixed 60-Hz window.

The final three-minute solo original-view run also passed: 59.73 distinct
game images/s, source p99 18.59 ms, worst source interval 43.53 ms, and
worst native step 10.67 ms. Neither final displayed repeat lost focus or
recorded a source-picture interval above 50 ms. Shorter 38–44-ms intervals
remain; these results do not establish imperceptible motion in every scene.

Aggregate measurements and qualifications are in
[the long-play evidence](qa/pinball-long-play.json). Measurements use one Apple
M3 / 16-GiB development Mac, LÖVE 12 Metal and automatic distinct flipper
inputs. Other devices, real physical controller pairs, every bonus board and
production ModCompass duels require separate qualification.

## Repeating the checks

Prepare a private installation using your own verified cartridges first.
Run displayed tests sequentially, with other graphics QA paused:

```sh
python3 tools/qualify_pinball_native.py --frames 7200 --label comparison
python3 tools/qualify_pinball_scheduler.py --love /path/to/love
python3 tools/qualify_pinball_frames.py --love /path/to/love --label two-ruby --seconds 360 --seats 2 --full-table --pause-unfocused
python3 tools/qualify_pinball_frames.py --love /path/to/love --label two-sapphire --seconds 240 --seats 2 --full-table --locale de --field 1 --pause-unfocused
python3 tools/qualify_pinball_frames.py --love /path/to/love --label solo-original --seconds 180 --pause-unfocused
```

The optional focus policy pauses native execution while the test window is
unfocused and records/excludes that time; the default instead fails focus loss.
Normal gameplay focus behavior is unchanged. Round preparation/countdown and
three warm-up seconds per round are excluded from active timing. Detailed
reports remain in ignored QA storage; the launcher and solo saves use isolated
test profiles. No cartridge bytes, artwork, generated guest code or user saves
are committed.

## October 27 playback regression follow-up

The background worker's utility priority produced a measured 283 ms wall-time
step despite only 16 ms of thread CPU time. A running audible game now retains
its latency-sensitive class across focus loss. Pause and waiting/finished duel
phases still relinquish it. The actual native worker test observes the sequence
`33,33,17,33,17,33` on macOS. A native presentation lease separately prevents the
launcher from reducing the frame/audio consumer to 20 Hz, and the real keyboard
entry point now forwards repeat flags to Pinball.

The follow-up graphical run kept a stable full-table shape, played at 58.80
unique images/s and reported zero audio restarts. Display p99 was 33.27 ms,
maximum 33.67 ms; native steps peaked at 20.70 ms. The strict 25 ms display-p99
criterion remains unsatisfied. This report does not claim universal smoothness,
controller/network qualification or a complete playthrough.

## HALT correction: game time rather than window refresh

All earlier image-FPS measurements above predate this correction. They describe
presented frames; they did not prove that the game's own logic advanced once per
VBlank. The same caution applies to counting audio-source restarts alone.

The interpreter fallback in the pinned runtime continued executing instructions
inside a BIOS `IntrWait` subtree while the CPU's HALT latch was set. The wait
could return with HALT still set; the outer dispatcher then stalled the game
until another interrupt. A prepared Ruby state advanced only 74 game steps in
120 VBlank steps. The fix suspends interpreted instructions while halted, pumps
the existing device/IRQ clock, then reloads the CPU state before continuing.
No game RAM, physics speed or PCM rate is patched to mask the problem.

The same state now advances 120/120 game steps with both native RAM templates
and the RAM interpreter. Fresh USA/Ruby and Europe/German/Sapphire each advance
240/240 game steps; each produces exactly 4.01824951171875 seconds of PCM for
those 240 VBlanks, with no sound-mixer lock spanning the measured boundary.

A separate mGBA reference run, using the same private USA ROM and replacement
BIOS, reaches title/field-selection stages at the same frame indices after the
intro. A short-time spectral comparison of the captured 7–15 second audio
segment changes from 0.4269 before the fix to 0.9486 after it, at zero lag.
This is an observational similarity metric, not byte-identical audio or a
listening-test certificate. The reference tool is not a shipped runtime.

See [functional coverage](PINBALL-FEATURE-PARITY.md) and the scoped evidence in
[the HALT follow-up](qa/pinball-halt-followup.json). Native original menus, SRAM
reopening and image/RAM replay are checked separately from displayed pacing.

## Fixed full-table framing

The shared player now keeps a fixed portrait scale while full-table mode is
selected: 192×285 for GBC, 256×388 for GBA. Original-view menus or unsupported
scenes are centered at that same native-pixel scale, so temporary native
fallbacks no longer enlarge the half-table viewport and zoom back out. F6 still
explicitly changes between full-table and fitted original view. A received
opponent portrait also retains its framing through later original-view frames.

GBC standard-field loading and ball-loss sequences additionally retain the last
complete world surface and draw their current window overlay on it. The native
window's eight-pixel status row is isolated from the board; multi-row bonus/menu
windows remain complete. This avoids both the repeated camera zoom and the
Diglett/flipper fragments previously copied into the lower HUD strip. It is a
presentation correction, not a game-timing or physics change.

## Stage-load content guard

Fixed dimensions alone did not prevent an incorrect whole portrait: the GBC
cartridge changes its stage identifier before clearing palettes and waiting for
VBlank, while VRAM can still contain the previous half. Reinterpreting that
VRAM with the new stage identifier briefly duplicated the top or bottom half.
The follow-up captures reproduce this even though the image remained 192×285.

The host now latches the stage change immediately, including a boundary before
the palette-clear instruction. It preserves the last complete picture through
the scheduled LCD-off/palette-clear/load sequence and resumes composition after
the loaded half becomes ready. The initial CGB fade is handled separately: its
legitimate zero DMG palette does not blank a newly started game. A temporary
composition error also retains the complete picture, while incrementing an
explicit failure counter. No fallback half-table is published in a standard
field, including the first loading frame.

`qualify_pinball_gbc.py --full-table --transitions` now checks board pixels at
those boundaries and captures both the complete host picture and original
viewport. Canonical RAM is still compared against a second original-view game.
The ROM-free native regression additionally covers the stage-id change before
palette clearing, the ensuing loading frame and the first opaque loading
canvas. These checks address content validity, not just image dimensions.
