# Native colour-effect drawing

`gba_fx.draw/active/withClip` now cover five-bit fade colours, grayscale, brightness bands, object-window masks and clipping. Alpha combines the transformed source with the native underlay snapshot in one pass. The draw callback runs once, including when fade and alpha are combined; two simulated blend passes cannot consume a native drawing receipt twice.

Each nested draw uses a separate shader bank, so restoring a shader handle also restores the caller's effective uniforms. A bounded pool reuses programs and native alpha surfaces; masks remain borrowed and are detached after painting. Errors restore render target, shader, colour, blend and scissor. Teardown during a painter is deferred until the active draw exits. Object-window/band coordinates use logical target pixels, including DPI2; the existing default native-alpha program retains its integer arithmetic.

Fork source `929266d044` passes38 groups including93 effect/ownership tests and the earlier profile, coordinate, battle, Gen2, checkpoint/suspend and session regressions. The same frozen bytes also pass the two additional native level-up streak/facade contracts. Exact older-public composition `c72042ec0c` passes25 groups plus those two level-up contracts. The shared alpha helper extension belongs to PR339; the drawing interface belongs to PR329. Small checked helper patches retain the older public native controllers.

Owned-output GPU probes pass346 checks each on Metal/OpenGL for both fork `3baa88a3d7` and public `da50b66c1f`. Samples cover all17 fade coefficients, brightness, grayscale ordering, combined alpha, object windows, bands, clips, default native alpha and DPI1/2. Each run observes64 painter calls. These are ROM-free pixel/resource tests, not full game, OS-window or sustained performance acceptance. Reference mods and player saves remain unchanged; managed QA enforces20GiB free reserve.

Contributions by Roxas2712. Existing native code and third-party rights retain their provenance. See NOTICE.md and LICENSE-ROXAS2712.md for Cedric / UNDERdecoded integration permission and visible-credit requirements.
