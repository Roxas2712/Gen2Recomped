# Native Gen2 world readiness

The persistent world owner publishes `phase = "boot"` until its world enters
successfully, then `phase = "play"`. Covering menus preserve that play phase.
Clearing or replacing the world returns to boot; a failed or retired entry
cannot publish play. Restoring an admitted native world restores play without
re-entering it. Legacy state stacks are unaffected.

`acceptsMenuInput()` observes whether the underlying field has settled, including
beneath an overlay. This lets a content installer wait for a safe native save
and restart while its status screen remains open. Scripts, battles, warps,
queued scripts and actor locks remain unsafe. Movement continues to call the
ordinary overlay-sensitive `busy()` and remains blocked by the active menu.

The regression tests use actual native stack/readiness code with synthetic
field data. Separate fork integration exercised an unchanged external content
menu and a real download/save/restart; it is not independent-branch GPU or
full-mod acceptance for this PR.

Contributions by Roxas2712 — <https://github.com/Roxas2712>.
See [the contribution permission](../LICENSE-ROXAS2712.md); existing licences
and other authors' rights remain in force.
