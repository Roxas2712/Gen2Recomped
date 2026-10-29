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
saved landmark copy, without moving roamers or migrating saves. Native
landmark getters retain the raw OAM records. The source getter supplies a live
screen-coordinate view (`x - 8`, `y - 16`); edits convert back to that same
native record, and ordinary `pairs`/`next` expose the source values. Region
boundaries follow active cartridge/imported metadata, including Crystal's
inserted Battle Tower.

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

## GSC evolution presentation

`src.ui.gen2.EvolutionAnim` resolves to `src.compat.gen2.EvolutionAnim`.
Both imports expose the same subclassable class, including `setPhase`,
`updateFlash`, `picPath`, `drawPanel` and `drawWidescreen`. Legacy presentation
mods can override the picture, phase and completion methods without replacing
the native Game or changing their manifest. The existing ordinary evolution
screen remains on its current dispatch path.

The options constructor accepts `mon`, `entry`, `index`, `party`, `save`,
`force` and `onDone`. Target rows accept source `into` and native `species`.
Writeback delegates to the native evolution/stat/event owner and retains the
actual Pokemon record. An explicit save receives its own Pokedex marks;
cancellation does not evolve or teach. Native Gen2 move learning handles
free/full/known slots and the actual forget screen.

The Gen2 evolution module additionally exposes the cartridge presentation
constants, fresh `flashRounds()` tables, `flashFrames()` and `speciesName()`.
The path-first `Sprites.pic(path, context)` uses the same live
`pokemon.sprite` hook as native `Sprites.path`, including true-colour results.
Crystal picture scripts use the native PicAnim owner with the evolution
idle/wait/cry/play order. Indexed palettes, true-colour replacement art and
Classic mode remain owned by the native palette renderer.

Qualification includes the unchanged published Ascendant 6.7.38 Gen2 entry
through the actual SDK with synthetic data, its original Mega subclass on both
sides, and actual LÖVE 12 Metal/OpenGL GPU reads with generated fixture art.
These checks establish the reported load/animation contract; they do not claim
a complete Windows game session, every optional mod feature, or the separately
reported Kris/Gold player-selection issue.

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


### Live GSC field context and water permission queries

The source `World` remains the actual native `OverworldController`, and
`Permissions` remains the actual native `Collision` module. Existing native
movement methods, strict terrain predicates and imported permission sets are
unchanged. Additional `of`, land/water/wall, walkable, ledge and three-valued
`surfable` queries accept GSC collision classes; `src.core.CollPermissions`
exposes the same classification owner. These class queries do not reinterpret
Gen3 collision blocking bits or replace actual map movement admission.

`World:fieldContext(mon)` reads the live save/party, player/facing/upper collision
classes, current block/index, native facing occupant, environment, movement state,
forced-bike flag, escape point, Strength and darkness. `cellCollisionAcross`
reads already resident neighbors with their actual pixel offsets, including live
block edits. It does not load maps, advance scripts, roll encounters or modify
saves. An absent neighbor is closed; a block index never addresses a foreign map.
The existing non-GSC field-action protocols remain separate. This read interface
does not claim the source FieldMoves action/result protocol or Aerodactyl-wall
script callback; those are still open capabilities.
