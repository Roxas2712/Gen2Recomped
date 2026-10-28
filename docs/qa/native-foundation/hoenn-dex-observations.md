# Native Hoenn dex/search observations and RS menu text

Contributions by Roxas2712 — https://github.com/Roxas2712.
See LICENSE-ROXAS2712.md for the contribution terms and specific integration
permission for Cedric / UNDERdecoded. Existing notices and rights remain intact.

`ui.game3.rse.pokedex.active()` observes the actual constructor-admitted Hoenn
listing/search screen. It exposes zero-based selection and mode, national mode,
and detached parameter cursor/scroll records. Closing/replacing the screen,
stack, save, dataset, loader or source view retires retained observations.
Observation cleanup never closes a native menu or mutates native preferences.
The fork binds both the existing RS controller and generic Hoenn controller;
the older-public offer binds the controllers present on its own baseline.
No later RS controller body is copied into that composition.

RS semantic battle-text reads select the actual cartridge's command prompt and
swap prompt. PP and type each select their own line of the shared native record;
both preserve leading structured controls. The active-Pokemon prompt remains
separate from the player-name/Safari prompt. Explicit canonical prose/record
edits, removals and translation remain authoritative. Queries retain no dataset.
The label relationship is documented by the public
[RS battle strings](https://github.com/pret/pokeruby/blob/5784633ce4ef7ade1a7f2d2d0c288e3d5e6cdd7f/src/data/battle_strings_en.h).
No replacement cartridge lettering or cache migration is introduced.

`Gen3TextPen` shares measurement and painting of embedded positioning controls
through the native proportional font. Minimum-width cells preserve complete
Unicode/charmap ligatures; clipping skips ink without changing pen position.
Ordinary strings keep the existing path. Unsupported/truncated positioning
controls fail before any glyph is painted, with native face/shader/colour state
restored. This is a bounded synchronous layout adapter, not a dialogue VM.
The current-main Safari composition also paints the RS user frame once while
retaining the native labels/cursor and native battle state.

Frozen fork `0f4111a361` on main `4e481a9c` passes 72 CPU groups, including
214 Hoenn observation, 56 semantic RS text, 180 pen-layout and 22 RS Safari
frame checks. Exact older-public composition `6248b0294b` passes 37 groups,
including 174 Hoenn, 56 RS text and 180 pen checks. The smaller Hoenn count
reflects the absent later RS controller; its constructor is not claimed tested.

Owned-output probes `b34e4d27e7` (fork source `f08e55c19c`) and `bbd293c34c`
(public source `a56e42c307`) each pass 402 checks / 160 frames on each Metal
and OpenGL backend: actual native font shaders, asymmetric glyphs, main/small
faces, HD off/on, DPI 1/2, scale 1/2, Unicode/ligatures and rejected malformed
controls. These probe the pen/font paths; later semantic text selection is
covered separately by the newer CPU snapshots and actual runs.

Unchanged-mod Ruby run `0fe7c55780-ruby` completes the native trainer battle,
paper/native/terrarium/native/paper view changes, move swap/restore/cancel and
idle presentation cleanup with exit 0. Its images exposed the subsequent pen
and prompt-selection fixes; it is not accepted as evidence of those later fixes.
Fresh runs `92d67353a1-ruby` and `1f2a1ba9d3-sapphire` both exit 0 on
source `0f4111a361`: clean AP labels, all five trainer-battle views, native
move swap/restore/cancel, actual RS dex constructors and parameter navigation,
then native close and observation retirement. Those real RS constructors are
qualified separately from the earlier typed-state CPU fixtures.
No complete gameplay, all-map visual or sustained-FPS acceptance is inferred.
QA uses owned disposable profiles, preserves player saves and enforces at least
20 GiB free, exceeding the requested 8 GiB.
