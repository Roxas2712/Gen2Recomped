# Native pixel cursor binding

Actual unchanged-mod run `78b938448b-firered` stops in the action-menu painter at missing `Window.cursorPx`. The pixel cursor now borrows the current native Theme cursor symbol and the existing imported proportional-font painter. Native colors, optional face selection, proportional advance and graphics-state/error restoration remain owned by those existing helpers. No private glyph atlas or hardcoded replacement cursor is added.

Frozen source `ee555e80d2` passes syntax and all23 targeted suites (24 groups), including145 glyph/cursor checks,5344 tutorial/UI checks and existing native menu/battle/START, Gen2 window/queue/scene/live-view/summary, checkpoint and suspend regressions. The fixture changes the native symbol between draws and verifies both actual pixel coordinates and restored face/shader/color state. Actual unchanged-mod graphics reprobe is running; clean scene, OS-window and60FPS acceptance remain open. QA uses isolated profiles and20GiB free reserve; player saves remain untouched.

Contributions by Roxas2712. Existing native code and third-party notices retain their provenance. See NOTICE.md and LICENSE-ROXAS2712.md for Cedric / UNDERdecoded integration permission and credit requirements.
