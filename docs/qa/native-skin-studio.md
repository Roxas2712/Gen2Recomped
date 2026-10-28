# Offered native skin studio

Depends on the offered viewport/runtime/hotbar stacks (#124, #383, #386).
This branch adapts the actual older native launcher and its flat settings
owners; it does not import a replacement Gen1 launcher. The library/editor,
widget toolkit and shared cursor are complete implementations. All62 icons
are independently drawn native vectors, without excluded Gen1 artwork.

The native host routes pointer/text/keyboard/wheel/focus/device events,
suspends and resumes its own launcher, and defers Play until update. The
embedded Test device scopes the same rectangle as drawing and the selected
cartridge context, restoring both afterwards. Preview reset/menu/speed actions
report their parsed action and cannot call a suspended game's handlers.
Native Gen4 X/Y declarations work through real Input; DS-only contacts stay
inert/click-through on Crystal, and mixed bindings retain supported GB input.

The shared native FilePicker provider now has real capability probes,
validated/quoted commands, one-backend cancellation, pointer-release ownership
and protected binary reads. Older dialog pipe reads could raise instead of
returning failure; they now close the pipe and return no selected file.
Windows non-ASCII staging preserves the selected extension rather than .bin.
This is a command contract, not complete interactive Windows/Unicode IO proof.
Required original-project and contribution credits remain in README and the
native launcher's measured/wrapped footer alongside existing authors.

Evidence:

- Actual offered native main/host callback suite50, studio model137, image
  import35, UX211, library reach118, default cursor/editor16, transitions36,
  pagination4472, spinner5 and updated format243 contracts pass. Native
  hotbar271 and skin65 regressions pass. Picker91 and import-error28 pass.
- Real isolated LOVE12 on Apple M3, exact636fa7a0: Metal and OpenGL each
  pass18 studio GUI/Test framebuffers, nine owned on-disk skins, actual PNG
  save/reload, undo/redo, native ZIP export/drop/import and persisted selection,
  plus all62 native vector icons. Later changes add explicit generation gates,
  scoped preview actions and command/format contracts, verified separately.
- Native host and picker91/skin65 focused tests pass on c23c6627. The complete
  available official scripts/test.sh run on that offered tree is in progress.
  There is no current upstream-main mergeability, full Gen1 GUI pixel identity,
  OS-window/mobile/FPS/full-mod or release qualification claim.

Provenance: identified studio/cursor/widget code and adapted tests originate
in Gen1Recomp535a5ec0, Copyright(C)2026 BOIS CLUB GAMES, LLC, under the
preserved GPLv3/Section7 terms in licenses/GEN1RECOMP-TOUCH-SKINS.md.
Native integration, FilePicker provider and vector artwork contributions by
Roxas2712 are expressly offered under LICENSE-ROXAS2712.md, subject to
existing grants and other authors' retained rights. Mods/player profiles
are not modified. Full parity and release acceptance remain open.
