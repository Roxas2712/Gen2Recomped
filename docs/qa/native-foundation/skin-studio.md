# Native skin library and editor

The native launcher's Settings / Touch Controls section now opens a complete
skin library/editor, alongside the existing default-pad position editor.
The skin service and touch hotbar remain prerequisite increments (#311/#318).

The studio includes creation/selection/deletion, native/RetroArch/Delta
archive import/export, real image import, idle/pressed art, bind editing,
native Gen4 X/Y binds, viewport placement, page/orientation and device presets,
undo/redo, test input and deferred Play. Archive drops ask before discarding
unsaved edits. The desktop picker and file-drop paths are supported; native
mobile document-picker admission remains a separate qualification requirement.

The native host suspends/restores its own launcher and clears old held input.
It forwards text, keyboard, wheel, pointer, focus/visibility, gamepad/raw
joystick and removal events to the active editor. Native touch owns mobile
gestures and synthetic mouse events do not fire a second click. The default
layout editor also gains the actual shared virtual cursor, including dragging,
size buttons and focus cancellation.

## Findings and evidence

- Native host contracts exercise actual `main.lua` callbacks and real studio
  state. The constructor is isolated and cartridge admission is observed;
  this does not claim an imported ROM or full game boot. Forty checks pass
  on composed source `9d930a6d`, including real memory-file persistence,
  file drops, X/Y Input ownership, focus/visibility/device removal, and
  deferred Play returning to the same native launcher.
- A negative probe (`91e59881`) failed Test input against the embedded mock
  device. Draw had already relinquished its skin surface; input used full
  window coordinates. Input now scopes the actual mock-device rectangle
  and restores its caller's surface. The corrected host contract passes40.
- Adapted Gen1 contracts pass: studio model137, image import35, UX211,
  library reach/scroll118, native default editor/cursor16, transitions36,
  pagination4472 and spinner5. The owned bundled-clone fixture replaces
  unavailable reference artwork. Picker tests explicitly inject availability;
  text scans of a different host were replaced with actual native callbacks.
- Real LÖVE12/Apple M3: Metal on `9d930a6d` and OpenGL on `a461b08c` each
  pass18 native studio GPU frames (two orientations, library/editor, four
  modals, Test idle/pressed/released), real PNG import/decode/save/reload,
  undo/redo, nine actual owned library entries, actual ZIP export/drop/import
  and persisted selection, plus all62 independently drawn vector icons.
  Portrait editor, landscape Test and the vector contact sheet were inspected.
- An initial GPU assertion compared the entire editor after a click. The
  ordinary focus ring legitimately changed. The final assertion compares
  the actual mock-device pixels while retaining complete frame screenshots;
  held native Input and the pressed PNG change, then release restores them.
  The visible missing minus glyph was replaced with portable ASCII labels.
- The first full studio run passed897/898 engine suites and all four SDK
  suites. Its sole failure was the copied GB-only format expectation that Y
  must always be decorative. The native parser retains Gen4 declarations;
  actual input capability gates keep DS-only contacts inert and pass them
  through on Crystal, while mixed X/A bindings activate only A. The revised
  format contract passes243; the expanded actual native host contract passes50.
  Test input also scopes the selected cartridge and restores the outer context;
  preview reset/menu/speed actions cannot call a suspended game's handlers.
- The Windows picker staging command now retains the selected extension, so
  an image/archive picked through a non-ASCII path is not mislabeled `.bin`.
  Command/IO contract tests cover this path; interactive Windows and complete
  Unicode native-path handling remain separate acceptance requirements.
- Existing hotbar273 and quit-to-launcher86 native contracts pass after the
  studio integration. Full current-tree CI and packaged/OS-window acceptance
  remain separate gates. No full Gen1 GUI pixel identity, mobile hardware,
  performance or complete unchanged-mod gameplay is inferred from these tests.

## Provenance

SkinStudio, PadCursor and the identified default-editor cursor sections,
widget toolkit and adapted tests originate in Gen1Recomp
`535a5ec088c1ae1bf4d91dd3e35a56f64cf46d91`, Copyright (C)2026 BOIS CLUB
GAMES, LLC. Their GPLv3 and Section7 terms are retained in
`licenses/GEN1RECOMP-TOUCH-SKINS.md`. The native host integration and all62
vector icons are contributions by Roxas2712, subject to preserved existing
grants and `LICENSE-ROXAS2712.md`. Excluded Gen1 launcher files and artwork
are not copied. Mods and player installations are not modified.

Full Gen1 behavior parity, current unchanged-mod scenarios and the final
release remain open. Presence of the editor is not completion of that goal.
# Windows original-path file reads

SkinStudio's `FilePicker.open/read` now keeps the original UTF-8 filename and
uses `NativeFile`'s readonly Win32 wide-character reader. It does not copy the
image into `%TEMP%`, whose user-profile path can itself contain non-ASCII
characters. Existing `chooseFileByExt` callers retain their staging contract
unless they explicitly select the native UTF-8 reader.

The Windows workflow runs LÖVE/LuaJIT against real binary files under a directory
containing accented, CJK and non-BMP characters, checks exact multi-block bytes
and basename preservation, then replaces/removes them to prove handle release.
It also checks coexistence with the download publisher's FFI declarations,
missing/empty files and invalid UTF-8. The portable engine suite covers exception
and close handling. These are file-IO checks, not a Windows GPU or full-mod
qualification; inspect the exact-head workflow result before claiming Windows
acceptance.
