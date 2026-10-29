# Legacy Gen2 mod compatibility

API 1/2 source mods can still target the shared native engine. These adapters
translate their original contracts at the loader boundary; no mod identifier is
special-cased and no second battle controller, wallet or encounter engine runs.

## Native Gen2 mods remain supported

Gen1 compatibility adds entry points alongside the native Gen2 interfaces.
It does not require an existing Gen2 mod to change its manifest, opt into a
source profile, migrate its save, or convert its data to Gen1 formats. Module
names alone are not evidence that two functions have interchangeable contracts.
Keep native arguments, return values, RNG consumption and record ownership when
adding a source adapter. Both consumer paths belong in regression tests.

In particular, `src.pokemon.Pokemon.new(data, species, level, rng, form, opts)`
keeps the native two-bound RNG and validated, copied Gen2 DVs. Its source
counterpart, `src.battle.gen2.Mon.new(data, species, level, opts)`, accepts the
original source options: nickname, HP, happiness, Pokerus, caught data, authored
moves/stat experience, and held-item selection. Explicit source arrays and DVs
remain the caller's objects. Both constructors create the actual native
Pokemon; `experience` and `maxHp` remain live views of native storage rather
than a second saved balance. The older function-RNG overload of the compatibility
constructor also remains available.
The two public constructors call a shared private builder independently. A
native mod wrapping the existing six-argument constructor does not need to
forward hidden source options or change its wrapper to keep both paths usable.

The source helpers `displayName`, `eachSaveMon`, `syncSaveIdentity`,
`evolutionAtLevel` and `wildItem` are additive. The held-item helper implements
the two cartridge byte gates; this does not establish that native ROM imports
already publish every species' held-item metadata. Save traversal covers real
party, box and Day-Care records without treating unrelated mod data as Pokemon.
Native sparse-slot traversal and source array traversal retain their respective
policies. Source OT stamping returns the actual Pokemon; the existing native
battle stamping method retains its own return and metadata behavior.

`src.core.Game2:learnMoveOn(mon, moveId, onDone)` is the public GSC field
teaching entry. Native TM/HM, Rare Candy and evolution/reminder field paths
dispatch through that same method. A free slot writes once and completes after
its message; a known move reports false. A full set uses the actual native
Gen2 four-row picker, protects HMs, and supports cancellation and the stop/retry
loop. `src.ui.gen2.ForgetMoveList` resolves to the native list module, so a
presentation wrapper reaches the picker without editing the mod. These field
contracts do not implement the separate source Battle turn/event interface.

`src.core.gen2.Nests` and native AREA screens share the native
`src.world.Gen2Nests` search. Grass at every time of day, water and active
Johto roamers contribute sorted, deduplicated landmark indices. Fishing,
headbutt-only, swarm replacement and Fast Ship entries do not become ordinary
nest markers. An unmet roamer with zero HP remains visible; a retired or
unreleased one does not. Reads use the current native map header rather than a
saved landmark copy, without moving roamers or migrating saves. Landmark
getters return the actual native records, and region boundaries follow the
active cartridge/imported metadata, including Crystal's inserted Battle Tower.

`tests/engine/gen2_field_learning.lua` drives the actual text/choice/picker
stack through free, known, full, HM-refusal and cancellation paths. It also
checks that sequential native field learning reaches a source wrapper and that
loader teardown restores the original native method.

`tests/engine/gen2_source_birth.lua` loads native and source consumers side by
side, checks their distinct constructor contracts across the supported Gen2
editions, and exercises the complete held-item byte domain. The ordinary
engine and SDK suites remain required for both paths. These checks do not
establish compatibility with every private engine-internals modification or
replace the unchanged-mod graphics, download and gameplay acceptance runs.

## Existing compatibility boundaries

- Source encounter edits during legacy event callbacks update the native
  grass/time, water, tree and fishing records. The derived view remains read-only
  outside that callback scope, including after a throwing callback.
- Authored move/effect vocabulary, level moves and positional move-effect
  callbacks resolve to the actual native move catalogue, battlers and action
  queue. The old combined Special alias reads the actual Sp.Atk value, while
  the native Sp.Atk and Sp.Def remain distinct.
- Legacy Mon creation, OT stamping, evolution, Hall of Fame, phone, money and
  badge queries use the native objects and progress stores.
- Optional local imports do not block save admission. An engine version change
  alone does not imply an unreadable save; incompatible save formats/API levels
  still block with their specific reason. No unknown format is bypassed.
- Old custom 3D mod shaders use the existing engine shader adapter installed
  before mod loading. That owner already tracks Canvas/window changes. An
  additional API-specific reflection is unnecessary: it flips OpenGL Canvas
  output and Metal window output a second time. Keep standard 2D, explicit
  native sources/options, API 3 and LÖVE 11 on their existing compiler paths.

## Validation

The targeted contracts cover content/effects, the native battle model, encounter
views, save admission, imports, launcher requirements, compatibility aliases and
workspace restore. The real shader probe loads API 1/2/3 mods after installing
the same graphics adapter as main.lua.

An imported Crystal GPU run with the supplied KASC and VASC packages plus a
separate Mega-only overlay exercises the real native battle and renderer:
logical L activation, authored sphere/sigil/flash, animated Mega front cards,
regular attack damage, victory and return to the map. Player movement and the
upright world/player orientation are also captured. This GPU check uses LÖVE
12.0.0 on macOS; it does not establish other backend/device parity.

KASC's Mega source/art changes remain in its separate private fix repository.
No Mega-specific code or art is included in this engine change. The original
reported save was not available, so it is not covered by the save fixtures.
Full story coverage and every optional legacy mod feature are outside these
checks; optional animation/model assets can still emit their own diagnostics.
# Regression boundaries

Content-name translation preserves the shared DELETE marker, including nested
type-field patches. Whole records still use the existing `remove` method;
API-2 full-value overrides do not acquire a new DELETE exception. Native marts
retain an empty ordered shelf after removal, as required by the script pool.

`tools/legacy-mod-shader-gpu` compiles through real API-1/2/3 mod environments
and compares actual Canvas pixels at DPI 1/2 plus real window captures. Nested
target changes must restore shader/Canvas ownership. Explicit native source and
compiler-option contracts, standard 2D and API-3 custom programs retain the
preceding engine compiler's output. Compact native shader sources without a
trailing newline remain valid when the wrapper adds its preprocessor directives.
The test uses synthetic geometry and no ROM; it does not replace a full mod run.
