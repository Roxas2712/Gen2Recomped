# Native battle menu frames

Actual unchanged-package run `a5e30e7856-firered` stops in UI drawing at missing `Ui.drawMenuFrames`. The binding now borrows the existing native generic panel/window geometry and the actual native RS panel/chrome owner. Generic imported panels already contain their selected user frame; a one-use receipt prevents painting another frame over that panel. RS retains its separate native user-frame layer and selected style. Wide and Safari paths retain their native fallback. No private renderer body is substituted.

Receipts are bound to the admitted native view, native frame, compositor serial or active graphics scope, mode and actual render target. Canvas handles remain opaque even when represented by tables; only MRT binding descriptions compare structurally. Cohort/owner retirement invalidates receipts. Frame drawing is graphics-fenced and never advances battle queues, RNG, HP or native clocks.

This branch includes main `6d2bf2f4` through merge `81e89d2f`. Both native text-reader ABIs remain supported: boolean structured mode and options-table mode, with RS-only NAME_END allowed solely by its explicit native option. Native Wally healthbox behavior is preserved; its shared observation returns a boolean even while hidden.

Frozen candidate `8e6c8853cd` passes syntax and all24 targeted suites (25 groups):263 frame checks,639 text/import IR checks,571 stage checks, selection/particle/picture/entry/capture/command/session/UI and RS import/map/boot/panel/cache contracts, plus current Gen2 window/queue/scene/live-view/summary regressions. The initial fixture omitted native font passthrough and RS panel metadata; the next attempt exposed a real nil-versus-false visibility regression. Both failed runs remain retained. Source/test hashes identify the final passing tree.

The actual unchanged-mod map/native/terrarium reprobe is running. No accepted scene frame, physical-window, complete tutorial presentation or60FPS result is claimed by these CPU tests. Tests use isolated QA profiles and20GiB free reserve; player saves remain untouched.

Contributions by Roxas2712. Existing native code and third-party rights retain their provenance. See NOTICE.md and LICENSE-ROXAS2712.md for Cedric / UNDERdecoded integration permission and credit requirements.

Public composition: this older public baseline lacks the native RS panel class and Wally controller. The offer adds the shared renderer/query helper and focused scoped UI hooks only, retaining the older native bodies. Its fixture checks optional RS owner delegation with the actual chrome contract shape; it does not qualify the absent native RS controller or fork-only merge fixes. Separate RS offers remain prerequisites for that native default path. Public composition qualification is pending.
