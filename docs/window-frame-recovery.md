# macOS OpenGL and Metal window frames

The engine now owns the completed macOS window frame. On Metal it renders
the world, UI and overlays into a final GPU canvas, then presents that canvas
once. Screenshot requests read this completed target. Ordinary Metal frames
without a capture or test observer do not require CPU readback.

On macOS OpenGL, the engine first checks its current system framebuffer.
Only framebuffer zero returning `GL_FRAMEBUFFER_UNDEFINED` enables recovery:
OpenGL renders into the final GPU canvas, and its completed RGBA image is
transferred to an owned Core Animation sublayer on the current process's
OpenGL view. The layer uses nearest filtering and is removed on shutdown.
This restores visible game output; it **does not repair Apple's undefined
default framebuffer**. Recovery requires GPU readback and an additional image
copy each frame. Performance acceptance remains open. Healthy OpenGL and
other platforms retain their direct presentation path.

`WindowFrame` redirects the logical screen only while drawing a frame;
explicit offscreen canvases retain their existing behavior. It restores the
graphics function and physical target after drawing failures, resizes/releases
its retained canvas, and releases readback images even if a callback fails.
Engine screenshot requests are collected before drawing. The macOS error
screen also uses this path so a render failure remains visible.

## Diagnosis and evidence, 2026-10-24

On Apple M3 / macOS 15.8.2, both LÖVE 11.5 and the pinned LÖVE 12 development
build `937eb3b21f973607ab080aa26b7ef2a6b3b2b663` reproduced black OpenGL windows
without game code. Framebuffer zero returned `0x8219`, its read buffer was
`GL_NONE`, and `glReadPixels` failed with `0x506`. Capturing the test process's
actual OS window confirmed black output, while offscreen textures were valid.
Window recreation, display/context updates and alternate window flags did
not repair that condition. The recovery restores actual window output.

The isolated Metal blackout seen at the previous checkpoint was **not
reproduced** by this investigation's baseline standalone probes. Inspection
of the pinned LÖVE Metal implementation showed that native drawable
readability depends on screenshot requests pending before drawable
acquisition; the engine previously requested captures after `Game:draw`.
That is a suspected timing dependency, not a proved explanation of the
original Metal frame. The owned final target removes that dependency for
engine captures. No last-good-frame cache or blank-frame retry is used.

The [metadata-only report](qa/native-foundation/window-frame-recovery.json)
records the final six-case real-game matrix:

| Runtime/backend | Emerald checked frames | FireRed checked frames | Actual OS window captures |
| --- | ---: | ---: | ---: |
| LÖVE 11.5 / OpenGL | 641 | 694 | 8 |
| LÖVE 12 / Metal | 662 | 662 | 8 |
| LÖVE 12 / OpenGL | 650 | 655 | 8 |

All **3,964 checked completed frames** pass, with zero blank/stale frames,
138,788 assertions and 24 fresh actual OS window captures. Each game enters
a second map, moves there, changes window size, and returns. Emerald uses
the Battle Dome room/lobby; FireRed uses Pallet Town/the player's room.
The normal Battle Dome entry text box remains; tournament scripting is not
accepted by this test. Four snapshots per case verify the actual window;
the continuous observer verifies every completed frame during each observed
steady-state interval. The initial 60 setup/fade ticks per phase are excluded.
The driver draws a changing binary frame number, checks that readback belongs
to the current draw, and separately requires diverse central game pixels.
Warning text, frame markers and letterboxing cannot satisfy the game check.

All six configurations also pass the existing independent ROM-palette GPU
oracle: **9,009 assertions and 2,247,936 complete RGBA pixel comparisons**.
Emerald's four source palette phases and FireRed's 16 native tile frames
remain correct. Both source ROM hashes are unchanged. Standalone alternating
red/blue checks pass 120 frames per configuration (360 total). Intentional
draw failures display readable error windows under OpenGL 11.5 and Metal 12
and exit cleanly through worker shutdown.

ROM-free regression coverage adds a 990-check window-frame suite and six
Python ownership/rejection tests. The complete local runner passes 100/100
engine suites, 3/3 mod-SDK suites and Dramatic Shape B30.

## Isolation and reproduction

Tests use exported fork source, separately downloaded runtimes, new UUID save
identities and new in-memory game state. Legacy migration is disabled before
engine startup, identity changes and external/portable cache roots are
rejected, and no mods are loaded. This matrix copies only the game-version
imported assets from the previous task's explicitly owned fresh full imports
into the new identities; no saves/options/player caches are copied. No
protected Gen1 source or player instance is accessed. Only the current test
child's reported window is captured; no whole-screen or other-app capture
is used. ROM bytes, derived images, caches and machine paths stay local.

For a fresh full import and the same continuous test from a committed fork:

```sh
python3 tools/check_gen3_palette_gpu.py --love /path/to/love --emerald /path/to/emerald.gba --firered /path/to/firered.gba --backend opengl --window-frames
```

Use `--backend metal` with LÖVE 12 for Metal. The requested backend must
match the actual renderer. macOS OS-window proofs require Pillow and screen
capture access; rejection aborts the test rather than silently weakening it.
Omit `--window-frames` to run the independent palette-pixel oracle instead.
`POKEPORT_GRAPHICS_BACKEND=opengl|metal` now also selects the macOS LÖVE 12
backend; the default remains Metal.

This is scoped native flat-world presentation acceptance. It does not establish
long-duration stability, fullscreen/context-loss recovery, all platforms,
performance, cartridge fade semantics, First/Third Person, or a native Origami
consumer. Raw standalone LÖVE OpenGL framebuffer capture outside the engine
remains affected by the original platform failure. The Origami port remains
paused; this change updates neither Gen1 nor the installed player instance.
