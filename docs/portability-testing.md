# Combined mod-portability testing branch

The fork's `codex/portability-testing` branch combines the public API, native
hook, rendering, shader and baseline test fixes prepared in Gen2Recomped PRs
#88–182, #184–185 and #188–191, #194–196, #198, #203, #206, #209, #210, #212, #214 and #215 (excluding unrelated #138). It is for testing the
combined changes before upstream reviews and merges individual PRs. Upstream
`main` is separate; cartridge-support PRs from other work remain separate.

**Publication scope: Gen2Recomped only.** Gen1Recomp is a read-only portability
reference. Historical results below that use a modified Gen1 reference fork
are not proof of parity with unchanged upstream Gen1. They do not require or
authorize publishing upstream Gen1 changes.

The combined runtime tested for this snapshot is
`4a2f0d15de9820e897f6dfe895e204b3737a15d6`. Its ROM-free run passed
**222/222 engine suites**, **3/3 SDK suites** and the Dramatic Shape B30 profile.
Subsequent status commits do not change production code.

[PR #215](https://github.com/UNDERdecoded/Gen2Recomped/pull/215) aligns native
GBA accuracy and ordinary post-hit chances. The percentage command now shares
native stage/ability/item arithmetic, all-slot weather suppression, Protect and
semi-invulnerability guards, guaranteed-hit cases, absorption and the public
`battle.accuracy` context. Secondary effects retain the native inclusive chance
boundary, including explicit zero, Serene Grace and draw-before-protection
ordering. Authored effect handlers keep their policies. Real special Fire hits
thaw after secondary processing; Substitute hits do not. Strong poison retains
its native marker through public API-3 views/edits, saves and party transport;
callback edits update the owning counter transactionally.

The clean feature `a6205dfce1b6d091e758238447db3b25462367f4` passes **68,836
focused checks** (15,082 accuracy, 53,598 secondary, 156 protocol). Its full run
passes 98/107 engine suites, SDK 3/3 and B30. The exact Counter of all 25 inherited
FAIL lines across nine suites matches clean #214 (95/104). Their separate fixes
remain green in the combined runtime above. Both clean feature and combined
runtime match the unchanged source in **72 workers / 48,524 paired observations**.
The checker retains every bounded RNG call/value, callback context, PP, HP,
stage and status event. Clean pre-secondary `184fdaaa` retains 56 differing
Thunder execution observations as the negative control; no failures are hidden.

Native GBA command revision 1 and six native move fields enter link hashes;
runtime-aware cache keys prevent stale cross-game reuse. The audited raw fixture
changes from `e33d251961f2a41d` to `3a76cc5fce47a5c3`. Non-GBA fingerprints,
including the combined red golden `a000e3862d11a73a`, stay unchanged. Actual
handshake/controller tests stop older peers before battle. Two complete seeded
synthetic link mirrors retain matching turn hashes/components and toxic markers.
A CPU-only smoke also runs actual imported Thunder through public enemy-action
and status-event paths in FireRed/Emerald. No imported assets/data are published.

All seven hosted #215 workflows await maintainer approval; the
[dedicated contract run](https://github.com/UNDERdecoded/Gen2Recomped/actions/runs/40154632317)
has zero jobs. The chat's 100-artifact limit prevents another attachment; the
regular PR is published and linked. Evidence is retained in
`tmp/native-hit-full-accepted.log`, `tmp/native-hit-contracts.json` and
`tmp/native-hit-import-smoke.log`. Complete cartridge genetics transport,
timed Lock-On/side/volatile producers, global RNG/VBlank scheduling and demo
controller playback remain separate. This does not certify live rendering or
whole-game acceptance. See [the scoped contract](native-gen3-hit-commands.md).

[PR #214](https://github.com/UNDERdecoded/Gen2Recomped/pull/214) replaces
midpoint/random-mon construction for native Gen-3 demo presets with a private
constrained-identity builder. Zero IVs/EVs, nature-adjusted stats, PID-selected
ability, full PP/HP, native friendship/experience and Poke Ball now agree with
the unchanged source. `gender.roll` executes only for nature-matching candidate
PIDs. Cartridge order maps/native indices handle canonical, raw and translated
registries without English-only lookups. Party construction completes before
borrowing the real save party, which is restored by reference without edits.

The clean feature `440a5da635dc9737875c38e4ac324ce2343a23ee` passes **209,742
focused checks**. All **56 workers / 5,574 paired observations** agree on the
clean combined runtime above; 180 new preset cases per profile include every
consumed word, final input-stream state and public gender-hook call. The source
runs its original LCRNG; the host receives an independent equivalent input
stream. Only engine field/ID schemas are normalized. No observations are
removed. The old prerequisite fails 1,065 assertions before reaching the missing
new private factory. The exact Counter of all **25 inherited FAIL lines across
nine suites** is unchanged: feature 95/104 vs prerequisite 94/103. Their separate
repairs are already in this combined branch, whose complete run is green.

A CPU-only smoke also creates all nine preset members independently from each
actual locally imported FireRed/Emerald cache (18 total). This checks the private
constructor with real imported records; it is not live rendering or full demo
playback acceptance. Emerald covers the shared Gen-3 data contract; retail
Teachy TV is FireRed-specific. Whole-game/VBlank RNG scheduling and the subsequent
demo controller's midpoint battle RNG remain open. The move-effect fingerprint
is unchanged (`a000e3862d11a73a`). See [the scoped contract](native-gen3-constrained-party.md).

All seven hosted #214 workflows await maintainer approval; the
[dedicated contract run](https://github.com/UNDERdecoded/Gen2Recomped/actions/runs/40150160378)
has zero jobs. Local green checks are separate. The PR attachment was attempted
but the chat's 100-attachment limit is reached. Evidence is retained in
`tmp/constrained-party-full-accepted.log`, `tmp/constrained-party-contracts.json`
and `tmp/constrained-party-import-smoke.json` (private ignored QA outputs).

[PR #212](https://github.com/UNDERdecoded/Gen2Recomped/pull/212) shares
native GBA critical policy between ordinary damage and Beat Up. First/Wally
states skip critcalc's draw; Teachy TV consumes it and discards its result.
Oak's inflicted-damage bit advances after the public hit event. Existing
script/constructor metadata reaches the policy. Public critical contexts
carry battle, target, canonical/numeric move IDs and stage, and ordinary GBA
hit events carry damage kind and Substitute metadata.

Native physical item/current-species stages and the critical cap are covered.
Lansat uses Focus Energy and is not consumed or stacked when already focused.
The focused suite passes **3,396/3,396 checks**, including legacy passthrough
controls. The shared API-3 mod/action/executor matrix matches clean read-only
Gen1 in **52 isolated workers / 5,214 paired observations** on this runtime.
The new critical matrix has 27 FireRed and 29 Emerald cases at all four
positions with ordinary and scripted attacks; see [coverage and limits](native-gba-critical-context.md).
The clean #210 negative control fails **288 assertions** in its new FireRed cases.

Feature quick acceptance is **92/101** engine suites against **91/100** on
clean #210. Exact Counters of all **25 inherited FAIL lines across nine
suites** match, with no additions; SDK 3/3 and B30 pass. This combined branch
includes the baseline repairs and passes **218/218**, SDK 3/3 and B30 with
zero FAIL lines. Integration preserves the existing native held-item phase
guard while adding the alternate Focus Energy marker. Only the audited
effect fingerprint section changes for `BEAT_UP_EFFECT.rev = 3`; the
fingerprint gate passes 33/33 checks.

All six hosted #212 workflows await maintainer approval; the
[dedicated contract run](https://github.com/UNDERdecoded/Gen2Recomped/actions/runs/40148026770)
has zero executed jobs. The app's 100-artifact cap prevents another PR card;
the regular PR is published and linked. Stats are controlled and kind fields
on the reference/Oak cases are seeded. Full controller playback, constructor
stat generation, advice/intro/animation behavior, fresh ROM import, raw RNG
traces and complete gameplay remain separate acceptance surfaces.

Prior #210 results retain runtime
`f39cc19534737f8f3b764cdd1c1a1d993a96fd6e` and its 217/217 engine result:

[PR #210](https://github.com/UNDERdecoded/Gen2Recomped/pull/210) reads
Beat Up participants across both native side parties in two-trainer and
player/ally battles. A private live view preserves trainer-owned replacement
benches, the battle-scoped player view, upcoming slot replacement and the
current user's HP/status. Party-array references are captured for the move,
matching the reference when whole fields are reassigned during a hit callback.

The focused suite passes **1,728/1,728 checks**. Eighteen cases at all four
positions on FireRed/Emerald use native constructors and actions, including
status/egg/faint filtering, one or both owners blocked, accuracy-time
eligibility, callback mutations, live/detached active battlers, Substitute,
fainting, criticals and variation. The same API-3 consumer and shared fixture
match clean read-only Gen1 in **48 isolated workers / 4,766 paired
observations** on this clean combined runtime. The #209 negative control
fails **58 assertions** in the new FireRed cases.

Feature quick acceptance is **91/100** engine suites against **90/99** on
clean #209. Exact Counters of the **25 inherited FAIL lines across nine
suites** match, with no additions; SDK 3/3 and B30 pass. This combined branch
includes the baseline repairs and passes **217/217**, SDK 3/3 and B30 with
zero FAIL lines. Raising `BEAT_UP_EFFECT.rev` from 1 to 2 changes only the
audited effect fingerprint section; all six other populated sections and
their mutation checks remain unchanged.

All six hosted #210 workflows await maintainer approval; the
[dedicated contract run](https://github.com/UNDERdecoded/Gen2Recomped/actions/runs/40145716820)
has zero executed jobs. The app's 100-artifact cap prevents another PR card;
the regular PR is published and linked. These constructor/action contracts
use synthetic imported-shaped parties. Full link/multi-owner controllers,
arbitrary mid-move ownership reshaping, graphical intros/animations and
complete gameplay remain separate; see [scope](native-gba-beat-up-side-parties.md).

Prior #209 results retain runtime
`4d169998e342794802c87b043796ed7c9dfa51e8` and its 216/216 engine result:

[PR #209](https://github.com/UNDERdecoded/Gen2Recomped/pull/209) adds
cross-engine acceptance for the composition of Beat Up (#206) and native
held-item adjustment (#182). It adds no new runtime policy. FireRed and
Emerald roll Focus Band independently after each reached strike's variance,
including nonlethal hits, Substitute and zero damage under Endure. Earlier
procs cannot protect later strikes; removal/equipping inside actual public
hit callbacks and a second move are exercised.

The focused suite passes **1,672/1,672 checks**. The same actual API-3 mod,
fixture, selected actions and native executor match unchanged read-only Gen1
in **44 isolated workers / 4,622 paired observations** on this clean runtime.
Physical Focus Band 196 and imported-shaped item 1196 are covered; parameter
mutation uses the latter because the reference has built-in metadata for
physical item IDs. The #206-only negative control fails **56 assertions** in
the new FireRed cases. See [contract scope](beat-up-held-item-contracts.md).

The test-only feature commit passes **90/99** engine suites compared with
**89/98** on the clean prerequisite (#206 plus #182). Exact Counters of all
**25 inherited FAIL lines across nine suites** match, with no additions;
SDK 3/3 and B30 pass. This combined branch includes the baseline repairs and
passes **216/216**, SDK 3/3 and B30 with zero FAIL lines. No record revision,
fingerprint golden or production behavior changes are introduced by the
contract commit.

The reference's persistent move-local Focus Band state belongs to the
Ruby/Sapphire policy; these FireRed/Emerald profiles do not select it. All
six hosted #209 workflows await maintainer approval; the
[dedicated contract run](https://github.com/UNDERdecoded/Gen2Recomped/actions/runs/40144832869)
has zero executed jobs. The app's 100-artifact cap prevents another PR card;
the regular PR is published and linked. Other scripted executors, joined
multi-trainer/link parties, Ruby/Sapphire controllers, animations and full
gameplay remain separate acceptance surfaces.

Prior #206 results retain runtime
`f6f3bfe95dc70256bea403afc9423bf35c73162b` and its 215/215 engine result:

[PR #206](https://github.com/UNDERdecoded/Gen2Recomped/pull/206) executes
native GBA Beat Up with each healthy party member's level/species base
Attack and the active target species' base Defense. It rechecks party
eligibility during mod callbacks, rolls critical/variation independently,
applies Helping Hand, continues after breaking Substitute and records the
last direct strike for special counter memory, including zero under Endure.
Native event metadata and the absence of ordinary damage/critical callbacks
are verified. The active/retained species cases seed the native battler
fields; the full Transform controller is outside this proof.

The focused suite passes **1,330/1,330 checks**. The same API-3 consumer and
fixture match unchanged read-only Gen1 in **40 isolated workers / 4,486
paired observations** on the clean combined runtime. The public species
patch changes actual native strikes. A real canonical `EFFECT_BEAT_UP` patch
with #121 passes **14/14** composition checks. The clean #203 prerequisite
fails **168 assertions** in the new FireRed cases; the Endure and active
species regressions each failed 16 assertions before their fixes.

The final feature quick run passes **88/97** engine suites against **87/96**
on clean #203. Exact Counters of the **25 inherited FAIL lines across nine
suites** match, with no additions. SDK 3/3 and B30 pass. This combined branch
includes the existing repairs and passes **215/215**, SDK 3/3 and B30 with
zero FAIL lines. Integration preserves the existing damage-adjustment
argument, GBA Substitute counter guard and battle-scoped party fallback.
Only the audited effect fingerprint section changes; see
[the contract and limits](native-gba-beat-up.md).

Both sides use the maintained pinned LuaJIT with JIT enabled. All five
hosted #206 workflows await maintainer approval; the
[dedicated contract run](https://github.com/UNDERdecoded/Gen2Recomped/actions/runs/40144144197)
has zero executed jobs. The app's 100-artifact cap prevents another PR card;
the regular published PR is linked here. Focus Band's native adjustment
schedule, joined multi-trainer/link parties, intro/tutorial controllers,
animation fidelity and full gameplay remain open acceptance surfaces.

Prior #203 results retain runtime
`ba2d7d11dccc64994e0367158d79f4b0d9f68ef8` and its 214/214 engine result:

[PR #203](https://github.com/UNDERdecoded/Gen2Recomped/pull/203) executes
native GBA Spit Up through its set-damage path: multiply the calculated base
including +2, then Helping Hand/STAB/type rounding, without ordinary damage
or critical callbacks or a variation roll. It corrects consumption on Protect
and immunity, preserves stock on miss/interruption/absorption, clips Substitute
hits and retains native set-damage event metadata. Stockpile cap/reuse and
Swallow interaction are checked through actual actions.

The focused suite passes **8,292/8,292** checks. The same API-3 consumer and
fixture match unchanged read-only Gen1
`535a5ec088c1ae1bf4d91dd3e35a56f64cf46d91` in **32 isolated engine workers /
3,974 paired observations** on clean feature and combined runtimes. Coverage
includes all four users, counts 0–3, low/wide stats, physical/authored special
types, STAB/resistance/immunity/Foresight, Helping Hand, interruption and
selected ability/item/stage/weather/screen combinations. A canonical public
`SPIT_UP` patch with #121 passes **14/14** real-mod composition checks.

Both sides and the dedicated workflow use JIT-enabled LuaJIT v2.1
`a4c064539ea931274d407e1249b4bb575424a0f4` (`2.1.1792588164`). The old local
ARM64 `2.1.1700008891` VM has a JIT-dependent Thick Fat discrepancy in unchanged
reference code; its original failed report is retained, not filtered or
claimed green. The Gen2 host's new Spit Up cases also match the pinned
reference under that older VM. See [runtime and scope](native-gba-spit-up.md).

Feature quick acceptance is **87/96** engine suites versus **86/95** on clean
#198; exact Counters of all **25 inherited FAIL lines across nine suites**
match, with no additions. The prerequisite fails 770 new FireRed assertions.
SDK 3/3 and B30 pass. This combined checkout includes the baseline repairs
and the audited native record revision; its full run passes **214/214**.
Only the `move_effects` fingerprint section changes for `SPIT_UP_EFFECT.rev=1`.
The existing damage-adjustment argument is preserved during integration.

All five hosted workflows await maintainer approval; the
[dedicated workflow](https://github.com/UNDERdecoded/Gen2Recomped/actions/runs/40141841786)
has zero jobs. Local acceptance is separate. The chat attachment limit prevents
a new PR card; the published PR remains linked here. Full item/ability/badge
coverage, raw legacy aliases, other set/delayed executors, wider RNG traces,
called/link controllers, animations and complete gameplay remain separate.

Prior #198 results retain runtime
`bf67876e473c7881fe2d08935c504fc7a922291c` and its 213/213 engine result:

[PR #198](https://github.com/UNDERdecoded/Gen2Recomped/pull/198) implements
native GBA Helping Hand (effect 176) and its shared ordinary-damage modifier.
The current living partner receives nonstacking support until next-turn
planning; replacement does not inherit it. Critical/STAB/type rounding,
physical/special/spread attacks, fixed damage and confusion exclusions,
status/refusal gates, residual lifetime, owned PP and actual priority queues
are covered by **5,322/5,322** focused checks.

The same API-3 consumer and shared fixture match unchanged read-only Gen1
`535a5ec088c1ae1bf4d91dd3e35a56f64cf46d91` in **28 engine workers / 1,916 paired
observations** on feature and combined runtimes. The clean prerequisite fails
391 assertions in the initial new FireRed matrix. Existing paired GBA base
and critical-order checks remain green. A real mod's canonical
`effect = "HELPING_HAND"` patch with #121 passes **12/12** additional checks,
including a publicly selected right-flank enemy move with supported damage.

Feature quick acceptance is **86/95** engine suites versus **85/94** on clean
prerequisite `45f5b4e3386f704ab011ca3b6690aaa79f0bc425`. The exact Counter of
all **25 FAIL lines across nine inherited suites** matches, with no additions;
SDK 3/3 and B30 pass. Dependencies #196, #178 and #175 remain separately
published. This combined checkout already contains their baseline repairs,
updates the former missing-handler assertion and audits the intentional
fingerprint change in only `move_effects`; its full run passes **213/213**.

All five hosted workflows await maintainer approval; the
[dedicated workflow](https://github.com/UNDERdecoded/Gen2Recomped/actions/runs/40139823577)
has zero jobs. Local acceptance is separate. The chat's attachment limit
prevents a new PR card; the published PR remains linked here. Dedicated
set-damage/delayed executors (Spit Up, Beat Up, Future Sight/Doom Desire),
full ability/held-item ordering, other effect producers, AI scoring,
called/link moves and full gameplay/RNG parity remain separate surfaces.
See [native GBA Helping Hand](native-gba-helping-hand.md).

Prior #196 results retain runtime
`218cf2c9879bf8dd7687491429ca2a427d5eee83` and its 212/212 engine result:

[PR #196](https://github.com/UNDERdecoded/Gen2Recomped/pull/196) implements
native GBA Follow Me (effect 172) through the ordinary registry, selected
mod-action targets and actual priority queues. Both sides, successive casters,
fainting/replacement and Lightning Rod precedence follow the covered native
reference. State expires at next-turn planning; residual collection keeps it.
Self/spread policies, imported protection flags and status interruption remain
authoritative. The focused suite passes **180/180** checks.

The same API-3 consumer matches unchanged read-only Gen1
`535a5ec088c1ae1bf4d91dd3e35a56f64cf46d91` in **24 engine workers / 354 paired
observations**, on both feature and combined runtimes. Unchanged #195 fails
29 new FireRed assertions. An additional real-mod proof of canonical
`effect = "FOLLOW_ME"` writes with #121 passes **14/14** checks, including
actual redirected damage and owned PP. No generated contract change is needed.

Feature quick acceptance is **82/91** engine suites versus **80/90** on clean
#195, with SDK 3/3 and B30 passing. Exact FAIL-line Counters add nothing and
remove only the two old fingerprint failures; the remaining 25 lines across
nine inherited suites match. The new handler intentionally changes only the
`move_effects` fingerprint section. This combined checkout updates that
section pin and the former missing-handler assertion, retaining all other
fingerprint sections and mutation checks. Its full run passes **212/212**.

All three hosted workflows await maintainer approval; the
[dedicated workflow](https://github.com/UNDERdecoded/Gen2Recomped/actions/runs/40138746937)
has zero jobs. Local acceptance is separate. The chat's 100-attachment limit
prevented adding a new PR card; the published PR remains linked here.
Remaining effect producers, AI scoring, random-target/full RNG parity,
link/called moves, damage amounts and item/switch/watch actions remain
separate work. See [native GBA Follow Me](native-gba-follow-me.md).

Prior #195 results retain runtime
`916661d14a9f45511924f719d4b5524369182672` and its 211/211 engine result:

[PR #195](https://github.com/UNDERdecoded/Gen2Recomped/pull/195) honors a mod's
positional GBA action target at native execution time. Replaced/absent targets
resolve through the current slot, explicit choices override stale UI choices,
and selected self/spread/field policies and active Lightning Rod redirection
retain the reference's covered local-battle semantics and target order.
Pressure counts every relevant holder and spends PP once; GBA spread actions
emit one `battle.move_used`, while actual hits use `battle.damage_dealt`.
The zero-power default path no longer publishes a spurious zero-damage hit.

The **434/434** new target checks pass, including actual Gen2 double-turn
queues, event targets/order/cardinality, PP, cached/replaced/absent targets,
Lightning Rod priority, legacy handles, malformed hints and unchanged random
selection/RNG against an identical-stats control. All prior move-choice,
selector and record checks pass. The same consumer matches unchanged read-only
Gen1 `535a5ec088c1ae1bf4d91dd3e35a56f64cf46d91` in **20 isolated engine workers /
312 paired observations**, on both the feature and combined runtime.

The feature is stacked on #194. Its full quick run retains exactly the same
**27 FAIL lines across ten inherited suites**, with no new failures; this
combined branch includes those repairs. All three hosted workflows await
maintainer approval; the [dedicated workflow](https://github.com/UNDERdecoded/Gen2Recomped/actions/runs/40136548705)
has zero jobs. Local acceptance is separate. Follow Me/unported effect
producers, automatic AI target scoring, full random/native RNG parity, called
moves, link ordering, damage amounts and item/switch/watch actions remain
separate work. See [selected target contract](portable-enemy-targets.md).

Prior #194 results retain runtime
`679b54967922bd8c14907c8c0bc152a2e2e615bc` and its 210/210 engine result:

[PR #194](https://github.com/UNDERdecoded/Gen2Recomped/pull/194) exposes the
common native GBA move record fields for API 3 inside `battle.enemy_action`
`next()`: kind, native move reference, slot, user, battler and double targetType.
The native exhausted fallback retains symbolic `STRUGGLE`. Native and public
hooks keep their own move-reference representations, including native rewrites;
legacy API-1/2 views, canonical id edits and detached native actor queries remain
supported. Metadata stays in weak side tables, without rewriting learned moves.

The **254/254** new record checks, prior **1,252/1,252** move-choice checks and
**438/438** selector checks pass. Actual `battle.move_used` events prove the
selected move executes; HP/PP checks verify mutation versus replacement,
nested references, charge continuation, Struggle and mixed native/public hooks.
The same consumer matches unchanged read-only Gen1
`535a5ec088c1ae1bf4d91dd3e35a56f64cf46d91` in **16 isolated engine workers /
220 paired observations**, on both the feature and combined runtime.

The feature is stacked on #191 and retains the exact **27 FAIL lines across
ten inherited prerequisite suites**, with no new failures. Their repairs are
included in this combined branch. All three hosted workflows await maintainer
approval; the [dedicated workflow](https://github.com/UNDERdecoded/Gen2Recomped/actions/runs/40134177111)
has zero jobs. Local acceptance is separate. Scores and selected targets are
not fabricated; item/switch/watch records, other native fields, damage amounts,
RNG traces and full gameplay remain separate work. See
[native move records](portable-enemy-move-records.md).

Prior #191 results retain runtime
`6bb17f00c9baedc665448254da99641dfe9db64a` and its 209/209 engine result:

[PR #191](https://github.com/UNDERdecoded/Gen2Recomped/pull/191) aligns API-3
GBA `battle.enemy_action` input selectors with unchanged Gen1. The single
controller supplies nil; the double controller supplies positional IDs 1/3.
Nested forwarding and reentrant queries restore each call's selector. Native
Gen2 callbacks, API 1/2 native and API 2 unified retain their actor contracts.
A query of the other flank keeps execution/PP ownership with its caller.

The **438/438** focused argument checks and all prior **1,252/1,252** move
checks pass. Coverage includes actual single/double turn queues, mixed public
and native hooks, legacy identity, forwarded native choices, and cleanup after
a fatal native AI error. The public priority integration still passes **32/32**.
The same consumer matches read-only unchanged Gen1
`535a5ec088c1ae1bf4d91dd3e35a56f64cf46d91` in **12 isolated engine workers /
162 paired observations** on both the feature and combined runtime.

The feature is stacked on #190. Its full quick run has exactly the same
**27 inherited FAIL lines across ten suites** as the clean prerequisite,
with no new failures; this combined branch includes the baseline repairs.
All three hosted workflows await maintainer approval; the
[dedicated workflow](https://github.com/UNDERdecoded/Gen2Recomped/actions/runs/40132593110)
has zero jobs. Local acceptance is separate. Native action result fields,
public item/switch/watch actions, explicit double-target conversion, damage
amounts, RNG traces and full gameplay remain separate contracts.
See [API-3 enemy-action arguments](portable-enemy-action-arguments.md).

Prior #190 results retain runtime
`fbd10fa1288ee9c09ec7823a8e606765278d88e8` and its 208/208 engine result:

[PR #190](https://github.com/UNDERdecoded/Gen2Recomped/pull/190) normalizes public
GBA `battle.enemy_action` move choices and binds execution PP to the native
selected slot. Bare names/numbers and new `move`/`id` records execute the
requested move, preserve learned moves, and handle nil/false fallback.
The **1,252/1,252** focused checks pass across FireRed/Emerald and API 1 native,
API 2 native/unified and API 3 unified, including Pressure, Mimic, duplicate
moves, right-flank ownership, exhausted slots and native charge continuations.

The same public consumer matches unchanged read-only Gen1
`535a5ec088c1ae1bf4d91dd3e35a56f64cf46d91` in **8 isolated engine runs /
100 paired execution observations**. Both the feature and combined runtime
pass. The feature is stacked on #102 and retains exactly its **27 FAIL lines
across ten baseline suites**, with no new failures; the combined branch includes
the baseline repairs. [Hosted CI](https://github.com/UNDERdecoded/Gen2Recomped/actions/runs/40131487598)
requires maintainer approval and has zero jobs. Local acceptance is separate.
This verifies move-result selection, owned PP, actual damage occurrence and
charge outcomes; hook arguments, double target conversion, damage amounts,
RNG traces and public item/switch/watch actions remain separate contracts.
See [portable enemy move choices](portable-enemy-move-choices.md).

Prior #189 results retain runtime
`10421a5125d1289bdcee7b5811957b954013a033` and its 207/207 engine result:

[PR #189](https://github.com/UNDERdecoded/Gen2Recomped/pull/189) prevents
scalar chosen/rampage target values from aborting an ordinary move queue.
Its **712/712** focused checks pass for Red, Gold, FireRed and Emerald,
including actual single/double action execution, fallback targets, native
handle identity and PP consumption. Valid ally, self, field, fainted-target
and living rampage-lock behavior is preserved. Run
`luajit tests/engine/unusable_target_handles.lua`.

The independent feature retains the same **27 FAIL lines across ten existing
upstream suites**; this combined branch includes their fixes. The
[hosted #189 CI](https://github.com/UNDERdecoded/Gen2Recomped/actions/runs/40129207307)
requires maintainer approval (`action_required`) and has zero executed jobs.
Local acceptance is separate. No Gen1 code or publication is required.

The in-progress enemy-decision branch additionally verifies the new delegated
`target=true` controller case with the same Test Mod on both GBA profiles in
API 3 and API 2/unified, including complete HP/PP/stock/event observations.
Its larger strict comparison still reports 534 RNG-trace differences from
the earlier turn-word sampling introduced by #188. Those raw differences
remain failures; this is not a claim of complete native-controller parity.
That unfinished hook is still excluded from this combined branch.

Prior #188 results retain runtime
`aed508c2918a369f1d19e2250eb11635c17bd78f` and its 206/206 engine result:

[PR #188](https://github.com/UNDERdecoded/Gen2Recomped/pull/188) implements
native GBA AI order prediction and actual turn planning with one shared
Quick Claw word, native speed arithmetic, priority and double comparisons.
Its **16,680** focused checks pass here. The original pinned FireRed/Emerald
C functions match **5,240 VM queries, 524 pair comparisons and 524 sorts**,
with zero differences. This uses read-only pret references and no Gen1 patch.
See [native order validation](gen3-ai-order.md).

The same public held-item consumer also passes **32/32** integration checks
across both profiles and API 1 native, API 2 native/unified and API 3 unified.
Run `luajit tests/gen3_ai_order/public_priority.lua` on this combined branch.
The actual comparator honors virtual Quick Claw, greater move priority and
the native strict threshold; AI prediction reads physical metadata.

The independent feature retains exactly the **27 FAIL lines across ten
upstream baseline suites**; their fixes are already included here. Both
hosted #188 workflows await maintainer approval (`action_required`); the
[dedicated workflow](https://github.com/UNDERdecoded/Gen2Recomped/actions/runs/40127906217)
has zero executed jobs. Local acceptance is separate. These are CPU checks,
without a new graphical or full-controller/gameplay parity claim. The
unfinished enemy switch/item hook remains outside this combined branch.

A read-only audit of the local Emerald cartridge program now finds handlers
for every reachable opcode in scoring stages 0–9 (1,745 instructions across
32 script slots, 67 distinct opcodes). Stage 2 previously lacked the order
predicate. This verifies handler availability only; complete predicate,
stock-scoring and native controller semantics still need validation before
publishing the unfinished enemy switch/item hook.

Prior #185 results retain runtime
`b74f59f6f05eb4624e71edaa2c64c2ae26d08c88` and its 205/205 engine result:

[PR #185](https://github.com/UNDERdecoded/Gen2Recomped/pull/185) implements
both native attacking-move predicates. They inspect exactly four current
user slots for a non-NONE move with nonzero declared power, regardless of
PP, Disable, Taunt, considered move or category. Current battle moves override
the learned list; missing definitions preserve the source error boundary.

The clean combined runtime matches in **4 workers / 4,272 paired observations**,
with **21,264** focused host checks. Source workers pass **8,528** checks each.
The checker pins clean upstream Gen1 dev
`bryanthaboi/gen1recomp@535a5ec088c1ae1bf4d91dd3e35a56f64cf46d91`; those source
predicates already implement the native rule, so this milestone needs no new
source production patch. The source fork's composed testing branch retains
its historical reference-only fixes at `fb7b0366efcb85e703e9e6d5a8a24d01456a109b`.
See [native attacking-move predicates](gen3-ai-attacking-moves.md).

Unchanged host main fails **4,256** assertions and differs in all **2,136**
observations per profile. The independent Gen2 feature retains exactly the
**27 FAIL lines across ten baseline suites**; their repairs are included here.
Both hosted #185 workflows await maintainer approval (`action_required`);
the [dedicated workflow](https://github.com/UNDERdecoded/Gen2Recomped/actions/runs/40122406817)
has zero executed jobs. Local acceptance is separate.

Ordinary usable contexts run through actual VMs; empty/all-zero-PP contexts
exercise actual opcode dispatch because there is no native considered move.
These are bounded CPU contracts, without new graphical or full-controller/
full-gameplay parity claims. The unfinished enemy switch/item hook remains
outside this branch. Native order prediction is still a prerequisite.

Prior #184 results retain runtime
`335000f18e7002f9be487a49e5164466ff602439` and its 204/204 engine result:

[PR #184](https://github.com/UNDERdecoded/Gen2Recomped/pull/184) implements
native `if_status_in_party`: full 32-bit equality, six stored slots, native
HP/species eligibility and FireRed/Emerald party selectors. Ordinary egg
flags preserve the underlying species. Actual sleep producers now maintain
the stored party count, including native GBA RNG, Early Bird and waking-turn
behavior. Other generations keep their existing policies.

The clean combined runtime matches in **4 workers / 2,500 paired observations**,
with **10,006** host and **7,496** source focused checks. The workflow pins
the modified Gen1 reference fixture at
`Roxas2712/gen1recomp-Mac-fix@9e372ef7f18a8069289b3c2b367fa45490f98ab0`.
That source also needed its previous approximation corrected; neither PR is
claimed merged upstream. See [native party status](gen3-ai-party-status.md).

The Gen1 fork's `codex/portability-testing` historically composed three reference fixes
at `fb7b0366efcb85e703e9e6d5a8a24d01456a109b`. Its focused checks pass
**372** Taunt, **1,240** item-knowledge and **7,496** party-status checks.
The independent party-status source standard run passes all selected tiers,
including engine **1,116/1,116** and SDK **79/79**; cartridge-cache cases skip.

Negative controls reject unchanged source dev (352 failed checks / 352
different observations per profile) and host main (2,494 / 1,246). The
independent Gen2 feature retains exactly **27 FAIL lines across ten baseline
suites**; their repairs are included here.

The recorded hosted #184 workflows and historical source CI require approval
(`action_required`); the [party-status workflow](https://github.com/UNDERdecoded/Gen2Recomped/actions/runs/40121125880)
and source CI have zero executed jobs. Local acceptance is separate. These
are bounded CPU VM/status checks, without a new graphical/full-controller
or full-gameplay claim. The unused broken inverse remains unsupported;
remaining native AI order/attacking-move predicates still need contracts.
The unfinished enemy switch/item hook remains outside this branch.

Prior #182 results retain runtime
`611e97230e1fea0c14b008c69a0fdfede4573f8b` and its 203/203 engine result:

[PR #182](https://github.com/UNDERdecoded/Gen2Recomped/pull/182) implements
native GBA AI held-effect and item-membership queries with actual Focus Band
and Leftovers observation producers. Native side/slot history, Emerald's
second metadata lookup and the retail byte-OR operand are preserved. GBA
Focus Band adjustment, confusion self-hits and the default OHKO policy now
produce matching history and RNG traces. Custom OHKO policies and other
generations retain their behavior.

The shared comparison passes **4 workers / 364 paired observations** on the
clean combined runtime, with **1,491** host checks and **1,240** source checks.
The modified Gen1 reference fixture
is pinned at `Roxas2712/gen1recomp-Mac-fix@12c9e5b5a2325470d6bb266c9a1f37b7954b698e`.
Gen1's old getter and metadata precedence also needed fixes; this is not a
claim of agreement with the old placeholders or a completed upstream merge.
The source fork's `codex/portability-testing` at
`a0c74c9570f0482a85886ecd8a2328de79ba7e09` combines the historical Taunt/item reference fixes
and passes their **372** Taunt and **1,240** item-knowledge checks.

Unchanged Gen1 dev fails 116/113 checks and differs in 117/127 observations;
Gen2 main fails 310/320 and differs in 157/161 (FireRed/Emerald). The independent
Gen2 feature retains exactly **27 FAIL lines across ten baseline suites**;
their repairs are included in this combined branch. See
[native GBA item knowledge](gen3-ai-item-knowledge.md).

The recorded hosted #182 workflows and historical source CI require approval
(`action_required`); the [item-knowledge workflow](https://github.com/UNDERdecoded/Gen2Recomped/actions/runs/40119262288)
and source CI have zero executed jobs. Local acceptance is separate. These
are bounded CPU VM/effect/damage checks; no new graphical or full-gameplay
parity is claimed. The unfinished enemy switch/item hook remains outside
this branch. Remaining native AI predicates and complete stock-controller
contracts still need work.

Prior #181 results retain runtime
`f9531b9053b8e7cf226e9d7ad494406a5e5fab65` and its 202/202 engine result:

[PR #181](https://github.com/UNDERdecoded/Gen2Recomped/pull/181) implements
both native AI Taunt predicates against the live target, corrects GBA's
owned effect to two residual ticks and accepts an explicitly cleared zero
counter. Other generations retain their existing duration. Both directions,
multiple target slots, repeat refusal, expiration and reapplication are tested.

The shared interpreter/effect/residual matrix passes **4 workers / 96 paired
observations**, with **567** host checks and **372** source checks. The final
combined comparison is clean at `d8fed51a5ee3105d27d5f78b13ea4470dc529d15`.
Gen1's previous unconditional false/true predicates differ from this modified
reference fixture. The historical checker
explicitly pins that source fork at `10613015fc68d924915570bd1abee34b70d5bd01`;
this is not an upstream merge claim. The base Gen1 source fails 56 assertions
and differs in 28 observations per profile; Gen2 main fails 196 and differs
in all 48 observations. See [native AI Taunt](gen3-ai-taunt.md).

The independent Gen2 feature retains the exact 27 failure lines across ten
upstream baseline suites. The recorded hosted #181 workflows and historical source CI
require approval (`action_required`); the
[Taunt workflow](https://github.com/UNDERdecoded/Gen2Recomped/actions/runs/40113016261)
has zero executed jobs. Local acceptance is separate. These are bounded CPU
AI/effect/residual checks, with no new graphical gameplay or complete AI
parity claim. The unfinished enemy switch/item hook remains outside this branch.

Prior #180 results retain runtime
`df1566375b3776fce349c04f9c05eaa9bd1525e5` and its 201/201 engine result:

[PR #180](https://github.com/UNDERdecoded/Gen2Recomped/pull/180) adds the four
native GBA move/effect membership commands and Emerald's observed-move
history. Native decision entry points learn before scoring; a changed party
object invalidates the old occupant's knowledge. FireRed's actual-move reads,
Emerald's partner asymmetry and effect-slot gate are preserved.

**19,116** feature checks and **4 workers / 3,072 paired interpreter observations**
pass for FireRed/Emerald. The same interpreter matrix also passes on this
combined runtime, with zero differences. Clean upstream differs in all 1,536
observations per profile. See [native AI move knowledge](gen3-ai-move-knowledge.md).

The independent feature passes **65/75** engine suites versus upstream
**64/74**; its exact 27 failure lines across ten baseline suites are unchanged.
Their repairs are included here. Both hosted #180 workflows await maintainer
approval (`action_required`); the
[move-knowledge workflow](https://github.com/UNDERdecoded/Gen2Recomped/actions/runs/40111054659)
has zero executed jobs. These are CPU interpreter/decision checks, with no new
graphical gameplay or complete AI parity claim. The unfinished enemy
switch/item hook remains outside this combined branch.

Prior #179 results retain runtime
`8284917e91317fe688dac54ffba0b4cba1d9e017` and its 200/200 engine result:

[PR #179](https://github.com/UNDERdecoded/Gen2Recomped/pull/179) supplies seven
native GBA AI query families: last-used move, move type/power/effect from the
result register, protection count, active types and Flash Fire state. It
preserves the importer's last-move alias, native type numbers, error behavior
for missing definitions and role-specific partner rules. The queries consume
no RNG. It is independent and based directly on upstream `main`.

**2,339** host checks and **4 workers / 472 paired interpreter observations**
pass on FireRed/Emerald, including all native type numbers, aliases, declared
custom type indices, unknown move definitions, counters and absent partners.
Clean upstream fails 702 assertions and differs in 236 observations per GBA
profile. See [native AI move and battler queries](gen3-ai-queries.md).

The isolated feature passes **65/75** engine suites versus upstream
**64/74**; all **27 FAIL lines across ten baseline suites** match exactly.
Their repairs are included in this combined branch. Both hosted #179
workflows await maintainer approval (`action_required`); the
[AI-query workflow](https://github.com/UNDERdecoded/Gen2Recomped/actions/runs/40109041486)
has zero executed jobs. Local acceptance is separate.

This is CPU/native-interpreter evidence. The unfinished enemy switch/item
hook and its extended AI/controller wiring remain on the development branch.
Other unsupported commands stay gated; reference held-effect/taunt placeholders
and further native AI semantics still need functional common contracts.
No new composed graphical gameplay or complete AI parity is claimed.

Prior #178 results retain runtime
`735c7ec0bba6e73075be708cf1e88a89872b3bd3` and its 199/199 engine result:

[PR #178](https://github.com/UNDERdecoded/Gen2Recomped/pull/178) selects native
GBA base-damage arithmetic: wide stats, burn/screens/spread/weather before
+2, the physical minimum and Solar Beam's bad-weather step. It is independent
and based directly on upstream `main`. **20,742** host checks and **4 workers /
6,912 paired ordinary damage observations** pass for FireRed/Emerald, with
six checks preserving Gen-1/Gen-2 arithmetic. Clean upstream differs in
2,209 numeric observations per GBA profile. See
[ordinary GBA base damage](gba-base-damage.md).

The combined calculation retains Gen-2 critical-base doubling in its existing
position and the separate GBA opt-in. The unchanged public critical consumer
matches both native SDKs on Gold/Silver/Crystal/FireRed/Emerald in **20 workers /
960 paired observations** across host API 3 and API 2/unified, with no differences.
These checks are CPU/native-calculator and SDK/move-pipeline evidence, not a
new composed graphical gameplay run.

The independent feature passes **65/75** engine suites versus upstream
**64/74**; all **27 FAIL lines across ten baseline suites** match exactly.
Their repairs are already included here. Both hosted #178 workflows await
maintainer approval (`action_required`); the
[base-damage workflow](https://github.com/UNDERdecoded/Gen2Recomped/actions/runs/40103939356)
has zero executed jobs. Local acceptance is separate. The unfinished enemy
switch/item hook and its AI/controller changes remain outside this branch.

Prior #177 results retain runtime
`bb85a4412a28233738f2faeacbf6ea18dfb1ba4c` and its 198/198 engine result:

[PR #177](https://github.com/UNDERdecoded/Gen2Recomped/pull/177) matches native
GBA AI random-branch semantics: draw a u16 and compare its low byte for all
four operators. It is independent and based directly on upstream `main`.
**1,920** host checks and **4 workers / 240 paired interpreter observations**
pass. The optional native Emerald importer/interpreter comparison passes at
clean combined tooling runtime `1f6de178ed7a0764e5b240dd600937d6888e3127`:
**39 common subroutines / 390 paired observations**, no differences or missing
reference entries; 42 additional host entry boundaries remain unpaired.
This is CPU/native-VM evidence, not a new LÖVE gameplay run. See
[native GBA AI random branches](gen3-ai-random-contract.md).

Clean upstream `13af468` fails 631 assertions per profile on the new matrix
and differs in all 390 native RNG traces and 41 resulting scores. The isolated
feature passes **65/75** engine suites versus upstream **64/74**; all **27 FAIL
lines across ten baseline suites** match exactly. Their repairs are already
part of this combined branch. The unfinished enemy switch/item hook remains
separate.

Both hosted #177 workflows await maintainer approval (`action_required`);
the [AI random-branch workflow](https://github.com/UNDERdecoded/Gen2Recomped/actions/runs/40101310265)
has zero executed jobs. Local acceptance is separate.

Prior #176 combined validation below retains runtime
`6ba0ca1569a27faba67f0481e602df777fa5dc39` and its 197/197 engine result;
its feature-native GUI evidence is not relabeled as a new composed run.

[PR #176](https://github.com/UNDERdecoded/Gen2Recomped/pull/176) selects Gen-2's
native critical-base step instead of doubling the level. At level 29, power 35
and equal Attack/Defense, a non-STAB critical with random 217 now deals **17 HP**,
not 16; with STAB it deals **25**, not 23. Native generation metadata selects the
step; the Gen-1 and explicit-multiplier paths retain their own rules. Seven
arithmetic regressions and **1,950** loader checks pass. Both host API modes
match Gen1 API 3 in **20 workers / 960 paired observations**, covering
Gold/Silver/Crystal plus the existing FireRed/Emerald matrix. Unchanged #175
differs in 32 damage cases and fails two assertions per Gen-2 version.
See [native Gen-2 critical base](gen2-critical-base.md).

Native LÖVE 11.5 results retain the clean feature runtime
`397d7d6fb48bcf8f539c152397bb3e5ad220d23d`: imported Gold, FireRed and Emerald,
six constructed battles each, **18 battles / 36 public critical decisions**.
The same public consumer, actual FIGHT/move input and native queues pass HP,
PP and callback-count checks. Those native file hashes describe the #176 snapshot;
`Damage.lua` has since gained #178's GBA base profile. This remains feature-runtime
native acceptance, not a newly relabeled composed GUI run. The owned example was
removed with hash guards. Drivers stop before battle finish/afterBattle/SAVE;
no native Silver/Crystal GUI, full playthrough or fresh-ROM import is claimed.

All **35** hosted #176 workflows await maintainer approval (`action_required`);
the [critical workflow](https://github.com/UNDERdecoded/Gen2Recomped/actions/runs/40098076236)
has zero executed jobs. The isolated feature passes 142/152 engine suites with
exactly the prior ten baseline failure suites. Their separate repairs are in
this combined branch. The unfinished enemy switch/item hook remains separate.

Prior #175 results retain runtime
`d9be4e9cfc8f05e2284ada5dacf8daed7382c4a5`; they are not new Gen-3 native runs:

[PR #175](https://github.com/UNDERdecoded/Gen2Recomped/pull/175) corrects the
Gen-3 critical multiplier's placement before STAB/per-type rounding. Base 11,
critical x2, Steel resistance and random 85 now gives **9 HP**, matching native
Gen1 GBA, rather than 8. Profiles without the new ordering flag retain their
existing order. **15** arithmetic regressions and **780** loader checks pass.
Both host API modes match the clean Gen1 API-3 reference in **8 workers / 384
paired observations**: both attackers, critical/noncritical, STAB,
neutral/half/quarter/immune targets, rolls 85/92/100, HP, PP and hook counts.
Unchanged #174 differs in 18 cases and fails two regression assertions per GBA
profile. See [Gen-3 critical/type rounding](gen3-critical-order.md).

At the recorded #175 runtime, native LÖVE 11.5 / imported FireRed and Emerald each
pass six constructed battles with the same public critical-hit consumer,
actual FIGHT/move input and full native turn queues. HP, PP and all 24 public
critical decisions pass. The owned example was removed with hash guards.
The driver stops before battle finish/afterBattle/normal SAVE. This is not a
complete playthrough, fresh full-ROM import or universal damage-rule proof.
The unfinished enemy switch/item controller remains on a separate branch.

At #175 publication, all **35** hosted workflows awaited maintainer approval (`action_required`);
the [critical-order workflow](https://github.com/UNDERdecoded/Gen2Recomped/actions/runs/40093193249)
has zero executed jobs. Local validation is separate. The isolated feature
passes 141/151 engine suites with exactly the prior ten baseline failure
suites; their separate repairs are included in this combined branch.

Prior #174 metadata evidence retains runtime
`4975ca8337faa27dde511fa5c6cb93c6210c7bab`; it is not a new AI-class native run:

[PR #174](https://github.com/UNDERdecoded/Gen2Recomped/pull/174) aligns AI-class
content: common item names such as `POTION` resolve to mounted native item keys,
and public reads, iteration and write results are detached. **442** content
checks and **670** loader checks pass. The same public consumer passes both
SDKs on eight versions in **32 workers / 112 paired observations** across host
API 3 and API 2/unified, against clean Gen1
`535a5ec088c1ae1bf4d91dd3e35a56f64cf46d91`. The reference uses API 3;
Gen1 API-2 live-record aliasing is explicitly outside the common contract.
Unchanged #173 fails the Gold and FireRed fixtures with unresolved item refs.
See [portable AI-class content](portable-ai-class-content.md).

At the recorded #174 runtime, native LÖVE 11.5 checks pass on imported Red, Gold,
FireRed and Emerald: actual public mod load, common/native item resolution,
detached records and frozen writes at title and in-memory New Game. The owned
example was removed with hash guards. No normal SAVE, battle decision,
complete playthrough or fresh full-ROM import is claimed. This does not enable
the unfinished `battle.enemy_switch_or_item` hook.

At #174 publication, all **34** hosted workflows awaited maintainer approval (`action_required`);
the [AI-class workflow](https://github.com/UNDERdecoded/Gen2Recomped/actions/runs/40090696993)
has zero executed jobs. Local validation is separate. The isolated feature
passes 139/149 engine suites with precisely the prior ten baseline failure
suites; their separate repairs are included in this combined branch.

Prior #173 import results retain runtime
`ddac8aaf1d6b042ddd3defe57fe3e8de1b8b2039` and are not a new importer run:

[PR #173](https://github.com/UNDERdecoded/Gen2Recomped/pull/173) preserves
native trainer AI import inputs: exact Gen-2 seven-byte attributes and ordered
stock, plus raw GBA item-effect bytes alongside parsed medicine. **32** focused
checks pass. The actual native importers match in **6 workers / 1,168 metadata
records**, including 583 effect-mask cases for each of FireRed and Emerald.
These use synthetic cartridge bytes, not a complete fresh-ROM reimport or
native gameplay test. Existing caches need reimport to acquire the new fields.
See [native trainer AI metadata](native-trainer-ai-metadata.md).

This prepares `battle.enemy_switch_or_item`; it does not enable the hook.
The separate development branch has further native policy/controller
validation gates and is not part of this testing branch. Metadata and
hook/gameplay validation remain separate.

At #173 publication, all **33** hosted workflows awaited maintainer approval (`action_required`);
the [metadata workflow](https://github.com/UNDERdecoded/Gen2Recomped/actions/runs/40079359698)
has zero executed jobs. Local validation is separate.

Prior #172 gameplay evidence below retains runtime
`7a12243293dcb7a6ff2a00dc64490f3c6bb5aa32`; it is not a new native #173 run.

[PR #172](https://github.com/UNDERdecoded/Gen2Recomped/pull/172) binds native
FireRed/Emerald party action text and separate cancel buttons, plus FireRed's
Item-PC withdrawal title, cancel row and submenu. Shared native reader checks
**257** and action/render/retirement checks **62** pass. The unchanged public
consumer compares through both real SDKs: **8 workers / 522 paired native text
values**, against clean Gen1 `535a5ec088c1ae1bf4d91dd3e35a56f64cf46d91`.
Both API 3 and host API 2/unified pass, including wrong-profile isolation,
separate TAKE/CANCEL labels, control characters and existing-menu retirement.

At the recorded #172 runtime, native LÖVE 11.5 / imported FireRed and Emerald passed: actual
party/footer/submenu drawing, SUMMARY open/B-return, ITEM submenu/B-close,
party close; FireRed's real Player-PC → Item Storage → withdrawal title/list/
submenu and translated CANCEL without inventory changes. Isolated in-memory
New Game; no normal SAVE, full playthrough, fresh full-ROM import or pixel
identity claim. The owned example was removed with hash guards.
See [GBA menu prose](portable-gba-menu-prose.md).

At #172 publication, all **32** hosted workflows awaited maintainer approval (`action_required`);
the [GBA menu workflow](https://github.com/UNDERdecoded/Gen2Recomped/actions/runs/40076430839)
has zero executed jobs. Local validation is separate.

Prior #171 registry evidence below retains runtime
`62f8902617255195b4a12b176f171925c49209ec`; it is not relabeled as a new native run.

[PR #171](https://github.com/UNDERdecoded/Gen2Recomped/pull/171) adds a separate
engine-prose registry, native Gen-2 label projection/formatting, same-spelling
script isolation and ten native GBA Pokemon-storage action/description bindings.
Registry/native checks **175**, ownership **510**, formatting **57**, provenance
**52** pass. The unchanged consumer compares through both real SDKs:
**24 workers / 94 paired native observations**. The separate native formatter
comparison adds **8 engine workers / 96 paired observations**. All use the clean
Gen1 pin `535a5ec088c1ae1bf4d91dd3e35a56f64cf46d91`.

At the recorded #171 runtime, native LÖVE 11.5 / imported Gold, FireRed and Emerald passed:
Gold native battle-prose helper, real textbox/end-marker handling and separate
same-label native script/A-close/resume; GBA actual storage menu/all five
labels/descriptions/B-close/reopen; frozen writes. This does not execute a
complete battle/wakeup turn. Isolated in-memory New Game, no normal SAVE,
full playthrough, fresh full-ROM reimport or pixel-equivalence claim. The owned
temporary example was removed with hash guards. See [portable ROM prose](api3-rom-text.md).

**Remaining prose work:** further party prompts, field-move names, mail/trade,
Item-PC quantity/results, Emerald Item-PC and other field/battle readers need
explicit bindings. A Gen-2 screen that still prints a hardcoded fallback
instead of reading its label also needs a native reader change. Availability
of `rom_text` does not mean every native printer or label consumer is covered.

At #171 publication, all **31** hosted workflows awaited maintainer approval (`action_required`);
the [ROM-prose workflow](https://github.com/UNDERdecoded/Gen2Recomped/actions/runs/40074003980)
has no executed jobs. Local validation is separate.

Prior #170 script-text runtime `a7a4091be9f4b631d54cd6f57ce1d33c5d8bed46`
and its native dialogue/grammar results retain their own status JSON fields;
they are not relabeled as new native script-text smoke runs. The existing
script-text unit contracts also pass in the current complete suite.

Prior #169 identity-hook native smoke and matrix results retain their own
runtime `19513a930c6befae0b0ee336d0c9f4984d7ae929` in the status JSON; they are
not relabeled as new native UI runs. See [Pokemon identity hooks](portable-pokemon-rolls.md).

Prior #168 mart, #167 held-definition and #166 scheduling evidence retains
its own historical refs in the status JSON. These establish their tested
contracts, not complete battle-rule parity; Choice Band locking, further
deferred abilities, Quick Claw turn-RNG ordering and volatile rules remain
separate work.

Prior held-read, field-residual, caught-marker, charge, PP, item, follower,
map and storage families retain their historical refs in
`portability-testing-status.json`; those results are not relabeled as new runs.

Native LÖVE 11.5 smoke tests reached the intro, title and New Game
world/introduction for Red, Gold, FireRed and Emerald using isolated copies
of existing imported caches. These prove startup, not full cartridge
playthroughs or universal mod support. Shared contract checks use clean pinned
Gen1 references; each `tools/*-contract-check/` tool documents its requirements.

## Start a test installation

```sh
git clone --branch codex/portability-testing \
  https://github.com/Roxas2712/Gen2Recomped.git gen2-portability-testing
cd gen2-portability-testing
bash scripts/run-portability-test.sh
```

Use LÖVE supported by the engine. If it is installed outside the locations
recognized by `scripts/run.sh`, set its executable explicitly:

```sh
POKEPORT_LOVE=/path/to/love bash scripts/run-portability-test.sh
```

The wrapper defaults to the separate LÖVE identity
`Gen2RecompPortabilityTesting` and disables automatic legacy save/settings
migration with `POKEPORT_SKIP_LEGACY_MIGRATION=1` and foreign save discovery
with `POKEPORT_ISOLATED_TESTING=1`. Import your own supported ROM through the
launcher, then install the mod under test in this test installation. No ROM,
generated cartridge cache, save or private mod is distributed by this branch.
The source checkout must be complete; sparse developer checkouts can omit
assets needed by the interactive launcher.

Keep the test game's data folder separate from normal installations. The
identity separates the initial save directory; choosing an existing game-data
folder explicitly can still share its files. Import a *copy* of a save through
the launcher when a test needs progress. See the normal launcher documentation
for supported versions and import requirements.

## Develop and verify

```sh
LUA=luajit bash scripts/test.sh --quick
```

For portable mods, start with API 3 and use `mod:supports` before optional
features. Keep generation-specific mechanics behind explicit capability
checks. See `api3-portability.md` and the `portable_*` examples.

The published PRs remove many adapter patches; they do not make arbitrary
engine-module imports portable. Remaining work includes DS party navigation, a shared follower-art contract, checkpoints, further
item/encounter hooks (including custom item effects, additional key-item
handlers, battle interception and a shared live table-transform seam), and
optional SDK services. LeafGreen/Ruby/Sapphire are not registered host profiles. Gen1's newer import verification
options also need a matching contract. DS native screens have additional gaps.
Shader imports intentionally support a bounded subset, not all RetroArch presets.

Feature changes continue as separately tested PRs. This testing branch will be
updated with tested combinations; it is not a replacement for reviewing them.

## Native boot smoke test

After importing a cartridge into the separate test installation:

```sh
POKEPORT_VERSION=red POKEPORT_DRIVER=tests/portability_boot_driver.lua \
  bash scripts/run-portability-test.sh
```

The driver advances the native intro, invokes the title's New Game action,
checks the world below the introduction, and exits. It does not import or
copy a ROM itself. `POKEPORT_PORTABILITY_SHOT=/absolute/path/frame.png` can
request a captured frame. Use an isolated test installation; this driver
starts a new game and is not intended for your normal playthrough identity.

## Native battle-party smoke test

The fork also includes a bounded native menu test after cartridge import:

```sh
POKEPORT_VERSION=firered POKEPORT_DRIVER=tests/portability_party_driver.lua \
  bash scripts/run-portability-test.sh
```

Use the isolated identity and a disposable test installation. The driver starts
New Game, constructs six native Pokemon and a battle in memory, opens the real
party screen, enables the public navigation predicate, and checks direction,
submenu confirm/cancel and party cancel. It then exits. Red, Gold, FireRed and
Emerald passed with existing imported caches. Optional frame capture uses
`POKEPORT_PORTABILITY_SHOT=/absolute/path/party.png`. This smoke test does not
prove a full playthrough, native pixel parity or DS party-hook support.

The status file records a separate tested runtime ref for each native smoke
family, including the party-menu and storage-restart snapshots.

## Native storage restart test

Install the public `examples/portable_storage` folder as a mod in the isolated
test installation and enable it. With an imported cartridge, run two processes:

```sh
POKEPORT_VERSION=firered POKEPORT_STORAGE_PHASE=prepare \
  POKEPORT_DRIVER=tests/portability_storage_driver.lua bash scripts/run-portability-test.sh
POKEPORT_VERSION=firered POKEPORT_STORAGE_PHASE=verify \
  POKEPORT_DRIVER=tests/portability_storage_driver.lua bash scripts/run-portability-test.sh
```

Use a disposable test installation: `prepare` starts New Game and writes an
ordinary save plus mod records/bytes. `verify` resolves the selected storage at
the native title after a fresh launch, checks Continue and the binary/record
roundtrip, then deletes only the smoke keys. The ordinary test save remains.
Red, Gold, FireRed and Emerald passed both phases with the same installed
API-3 consumer. No generated cartridge data is distributed by this branch.

The current full-suite runtime includes the enemy-PP and caught-marker drivers.
Later commits normalize test-fixture formatting (verified bytecode-equivalent)
and record validation/documentation; they change no production code. Older native smoke families
retain their historical runtime refs; they are not relabeled as new executions
on this runtime.

## Native connected-map lifecycle test

Install and enable `examples/portable_live_maps` in the isolated test
installation, then run:

```sh
POKEPORT_VERSION=firered POKEPORT_DRIVER=tests/portability_live_maps_driver.lua \
  bash scripts/run-portability-test.sh
```

The driver starts New Game in memory, selects a bounded connected-town fixture
for Red/Gold/FireRed/Emerald, and uses the native map-loading and neighbor-rebuild
paths. It checks the same public consumer's preparing/updated delivery and API-3
pixel placements, including a repeated rebuild. It does not write a normal save
or distribute any cartridge data. Use the separate test identity; this is a
bounded lifecycle test, not a full cartridge playthrough or pixel-parity proof.
The consumer itself has no generation-specific map IDs or engine imports.

## Native follower lifecycle and movement test

Install and enable `examples/portable_follower` in the isolated test installation:

```sh
POKEPORT_VERSION=firered POKEPORT_DRIVER=tests/portability_follower_driver.lua \
  bash scripts/run-portability-test.sh
```

Red, Gold, FireRed and Emerald passed using the same installed public consumer.
The driver starts New Game in memory, selects a real town, verifies map-entry
allow/deny and original native handles, then sends native directional input.
It checks companion movement through the ordinary NPC/world update loop,
removal, respawn and unsubscribe. Map-load companions begin under the player,
so the fixture takes two steps to verify movement. The driver does not write
a normal save. Native smoke ref `0482e8473228da203f156e3d4c62e662393cdee0`
adds only this standalone driver over the follower full-suite runtime
`318a1bae110afd5a5ee892674b2e61dda9def98d`. DS follower
coverage and a shared follower-art API remain separate work; this is not a
full-playthrough or identical-artwork claim.

## Native GB item UI lifecycle test

Install and enable `examples/portable_item_use` in the isolated test installation:

```sh
POKEPORT_VERSION=red POKEPORT_DRIVER=tests/portability_item_use_driver.lua \
  bash scripts/run-portability-test.sh
```

Red passed with imported native data and the unchanged public API-3 consumer.
The driver starts New Game in memory, opens the actual bag and party picker
with native input, blocks a Potion without HP/inventory/result-UI changes,
then delegates through healing, the HP animation and text back to the bag.
It also checks unsubscribe and native reuse. It does not issue normal SAVE.
Native smoke ref `3982554dc466ed3306b7a1256cac6c2f44a38cd1` adds only the
standalone driver over the historical GB full-suite runtime
`6775eabe22d77d89abd09d8ed4101c16b90a96b1`. The ROM-free shared tests cover
Red/Blue/Yellow in four SDK modes. GBA now has a distinct field-result producer;
this GB-shaped producer is not advertised for Gold/GBA/DS. These are bounded
native checks, not full-playthrough or pixel-parity evidence.


## Native GBA field-item lifecycle test

Install and enable `examples/portable_gba_item_use` in the isolated test
installation, then run with an imported cartridge:

```sh
POKEPORT_VERSION=firered POKEPORT_DRIVER=tests/portability_gba_item_use_driver.lua \
  bash scripts/run-portability-test.sh
POKEPORT_VERSION=emerald POKEPORT_DRIVER=tests/portability_gba_item_use_driver.lua \
  bash scripts/run-portability-test.sh
```

FireRed and Emerald passed on LÖVE 11.5 with the same installed API-3 consumer.
The driver starts New Game in memory, opens the real bag and party picker
with native input, blocks a Potion, delegates healing once, checks replaced
and suppressed result text after native HP animation, and unsubscribes. It
also uses the native white flute, verifies reusable inventory and the native
encounter modifier, preserves state on same-map reload and clears it on an
actual map change. It does not issue normal SAVE. The full-suite and native
runtime ref is `2551b7ef641ad138dc78e03b6212e1e18da85702`.

The two engines have different native item text and world services. This
proves the tested field-result boundary and bounded native lifecycle, not
all cartridge mechanics, UI pixel parity, a full playthrough or Gold/DS item
coverage. See `portable-gba-item-use.md` for the argument/result contract and
remaining native item adapters.


## Native title-screen encounter preview test

Install and enable `examples/portable_encounter_table` in the isolated test
installation. Run with an imported cartridge:

```sh
POKEPORT_VERSION=red POKEPORT_DRIVER=tests/portability_encounter_table_driver.lua \
  bash scripts/run-portability-test.sh
```

Repeat with `gold`, `firered` or `emerald`. All four passed on LÖVE 11.5
using the same installed API-3 consumer. The driver reaches the native title
with no active overworld, chooses an actual imported map table, checks
replacement/empty/nil/unsubscribe, rejects RNG use during each query and checks
that native encounter tables, save and preallocated world identity stay
unchanged. It does not start New Game or issue normal SAVE.

Native ref `292c4beb6445ac09ee1541a68562a8fa9038f22f` and shared-report ref
`7b4e51dd479725a5c2797f0a1e46d9721e0189f9` add only this standalone driver
over the full-suite runtime. `encounter.table` is preview-only on both
engines: actual encounters still use `encounter.roll`/`encounter.species`.
DS does not advertise this hook. The shared fixture rejects unregistered
versions, including LeafGreen/Ruby/Sapphire, rather than silently testing Red.
See `portable-encounter-table.md` for the contract and generation boundaries.


## Native charge-turn resolution and queue test

Install and enable `examples/portable_charge_required` in the isolated test
installation, then run with an imported cartridge:

```sh
POKEPORT_VERSION=red POKEPORT_DRIVER=tests/portability_charge_required_driver.lua \
  bash scripts/run-portability-test.sh
```

Repeat with `gold`, `firered` or `emerald`. All four passed on LÖVE 11.5
using the same installed API-3 consumer. The driver starts New Game in memory,
constructs native battlers with actual imported SolarBeam/Fly records and
checks charge/bypass, release without another callback/player PP cost,
GBA release animation metadata and unsubscribe. It uses the ordinary battle
state/input to consume the native text/result queue. This bounded test skips
the separate sendout intro and disables animation playback; it is not proof
of complete battle-entry, GPU animation, pixel parity or a full playthrough.
It does not issue normal SAVE.

The native ref is `e47c4ec558034c0b83b5f6ff5158510a79c3a459`; shared-report
ref `b5bc959d19b3d9e5ebc4528c9f47323bd35a0fbb` adds only the standalone driver
over the full-suite runtime. Native enemy PP costs are recorded separately:
Gold's reference spends one while this host's current Gen-1-default rules
spend zero. The new hook preserves that native policy; correcting the existing
rule difference remains work. See `portable-charge-required.md`.


## Automatic native rulesets and enemy PP

PR #162 fixes the measured Gold-family enemy PP difference for automatic
selection. New settings and cartridge-save import skeletons use RULESET -> AUTO
(`options.ruleset = false`). Explicit saved ids remain explicit; old literal
`gen1_faithful` settings cannot reveal whether the earlier default was intended.
Select AUTO to opt an existing test installation in. Gen 2 selects the bounded
`gen2_finite_pp` compatibility ruleset; this changes only enemy PP, not every
Gen-2 battle mechanic. See [native ruleset defaults](native-ruleset-defaults.md).

Install and enable `examples/portable_enemy_pp` in the isolated test installation:

```sh
POKEPORT_VERSION=gold POKEPORT_DRIVER=tests/drivers/enemy_pp_defaults.lua \
  bash scripts/run-portability-test.sh
```

Red, Gold, FireRed and Emerald passed on LÖVE 11.5 at the runtime above. The
driver starts New Game, preserves the existing preference check, selects AUTO
only in memory, and constructs a native wild battle with imported data. Real
FIGHT/move input drives three complete turn/result queues. The same public
observer checks PP; finite-PP games reach the native AI's Struggle fallback,
while Red retains unlimited enemy PP. An explicit Gen-1 choice is checked on a
new battle afterward. Sendout intro is skipped and animations are disabled for
this bounded queue check. No normal SAVE is issued; this is not a full-playthrough,
whole-battle or pixel-parity claim.

The standalone feature retains exactly the ten old baseline suite failures
covered by PRs #128–134 (115/125, SDK 3/3 and B30); this combined runtime includes
those repairs and passes all 170 suites. At #162 publication, all 23 hosted PR workflows reported `action_required` pending maintainer
approval; the [PP workflow](https://github.com/UNDERdecoded/Gen2Recomped/actions/runs/40046010257)
had zero jobs. Those recorded results are separate from local validation.


## Native caught-marker HUD/GPU test

PR #163 adds `battle.caught_marker_visible` and its actual classic/wide GB and
GBA single-battle marker rendering. Gen 1 defaults off; Gold/GBA default on for
eligible already-caught wild species. Only literal true shows it. Ownership,
trainer/tutorial/ghost/status/hidden-HUD gates and GBA presentation caching
remain native. DS reports unavailable. See [portable caught markers](portable-caught-marker.md).

Install and enable `examples/portable_caught_marker` in the isolated identity:

```sh
POKEPORT_VERSION=gold POKEPORT_DRIVER=tests/drivers/caught_marker.lua \
  bash scripts/run-portability-test.sh
```

Imported Red, Gold, FireRed and Emerald passed on LÖVE 11.5 at native runtime
`40e3e1219e05dd3f675fddcc01c7b1b0f92593ab`. The driver starts New Game,
constructs a native battle and draws the actual HUD into GPU canvases. Pixel
readback checks show/hide/native/nil/zero, ownership/trainer/status/hidden-HUD
exclusions and unsubscribe with the same installed API-3 consumer. Optional
`POKEPORT_CAUGHT_SHOT=/absolute/path/hud.png` writes an inspected HUD image.
No normal SAVE is issued. This is bounded native HUD/GPU verification, not a
complete playthrough, full battle sequence or cross-engine pixel-equality proof.

The GPU smoke uses existing cache artwork/fallbacks. The older Emerald glyph
is cropped to its native 8x8 footprint. Fresh GBA imports now read tile 70
separately from the unchanged 66-tile status scan; synthetic ROM bytes exercise
the real reader/decoder and output palette/transparency. Complete fresh-ROM
reimports were not performed. The later full-suite runtime includes this
import-reader correction; it is not relabeled as a new GPU execution.

Feature full-suite ref `bd182e0f4c39df69f86bcc76ceb15a51e1330579` passed
118/128 engine suites with exactly the ten old baseline failures covered by
#128–134, SDK 3/3 and B30. The combined runtime includes those repairs and passes
173/173. The feature head's later change is bytecode-equivalent fixture formatting;
the native contract suite was rerun afterward.


All 24 hosted #163 PR workflows currently report `action_required` pending
maintainer approval; the [new caught-marker workflow](https://github.com/UNDERdecoded/Gen2Recomped/actions/runs/40048498745)
has zero jobs and has not executed. Local test results above are independent.


## Native field-residual input and faint/replacement test

PR #164 adds `battle.field_residual` on GB/Gold/GBA. Mods read detached field
and battler data and return validated damage descriptors; native code owns
HP, messages, animation, faint events, EXP and replacement. GBA supplies slot
IDs 0–3, once-per-turn dispatch and stale-batch refusal. DS reports unavailable.
See [portable field residuals](portable-field-residuals.md).

Install and enable `examples/portable_field_residual` in the isolated identity:

```sh
POKEPORT_VERSION=gold POKEPORT_DRIVER=tests/drivers/field_residual.lua \
  bash scripts/run-portability-test.sh
```

Imported Red, Gold, FireRed and Emerald passed on LÖVE 11.5 at runtime
`8e0d34aeee4328465155bb2ea884145e2dcc40ec`. The driver starts New Game,
constructs native battles and drives actual FIGHT/move input through the
normal result queues. It then verifies detached edits, both orders of
simultaneous final KOs and unsubscribe. GBA additionally checks a right-flank
KO through native EXP and replacement, and simultaneous terminal doubles.
Gold retains both terminal faint announcements; GB/GBA suppress the enemy's
faint/EXP path. The driver stops at the in-battle loss before finish/blackout
or SAVE processing. This is not a full playthrough or whole-rule/pixel parity
claim; sendout intros are skipped and animations disabled in memory.

The unchanged consumer passes the actual reference GB/Gold/GBA producers and
the host in API 1 native, API 2 native, API 2 unified and API 3 unified modes:
64 isolated workers and 568 paired observations. Tests cover native weather
upkeep, batches/clamping, failures/replay, detached views, GBA Psychic type
pairs/flanks/once-per-turn/stale state, allied own-party authority, terminal
single/double KOs, unsubscribe, no-mod and entry rollback. The reference GBA
collector records residual steps; these comparisons do not run its complete
presentation/award controller. The host authority suite separately drains
real native EXP/faint/replacement queues.

Feature ref `124da70a77a09737d6a99aef2933ab722b3d5133` passed
120/130 engine suites, SDK 3/3 and B30, with exactly the ten prior baseline
failures covered by #128–134: all 26 FAIL lines match the previous #163 run.
Imported Red battle/save-conversion/parity J/K checks passed
468/468, 95/95, 73/73 and 22/22 respectively; external binary save fixtures
were not supplied. The combined runtime includes the baseline repairs and
passes 175/175 engine suites. Later testfork edits only record this evidence.

All 25 hosted #164 PR workflows report `action_required` pending maintainer
approval. The [new field-residual workflow](https://github.com/UNDERdecoded/Gen2Recomped/actions/runs/40050804974)
has zero jobs and has not executed. Local validation above is separate.


## Native held-item input, consumption and entry/escape test

PR #165 adds `held_item.trigger` on Gen2/3 hosts. It steers actual native
held-effect reads with common `HELD_*` names, two-result forwarding and byte
probability parameters. API 3 exposes common item/Pokemon identities and
scalar definition transactions; Gold metadata edits persist and GBA's remain
per-read copies. GB/DS report unavailable. See
[portable held-item reads](portable-held-items.md).

Install and enable `examples/portable_held_item` in the isolated identity:

```sh
POKEPORT_VERSION=gold POKEPORT_DRIVER=tests/drivers/held_item.lua \
  bash scripts/run-portability-test.sh
```

Imported Gold, FireRed and Emerald passed on LÖVE 11.5 at runtime
`3d6bfceeaf25b97d7a7ce708ada8fe3306e0357d`. The driver starts New Game,
constructs native battles and drives actual FIGHT/move input and result
queues, checking public imported IDs, suppression/substitution, HP and held
consumption. It verifies native delegated Leftovers, one-HP endurance and
unsubscribe; GBA also exercises entry White Herb and the actual RUN menu.
The in-memory setup skips sendout intros and disables animations. It stops
before battle finish/afterBattle/SAVE processing. This is bounded native
verification, not a full playthrough or cross-engine pixel proof.

The unchanged consumer passes both real SDKs on Gold/Silver/Crystal and
FireRed/Emerald in API 1 native, API 2 native, API 2 unified and API 3 unified:
40 isolated workers and 1,706 paired observations. Tests exercise native
readers and actual moves/order/entry/escape/residual handlers, all 66 GBA
enums through the real item-data fallback reader, errors/replay, metadata,
no-mod and rollback. Native HP formulas are checked for the requested effect,
not asserted identical. The source GBA residual collector is not its complete
presentation/award controller.

At the #165 runtime, the worker separately recorded unrestricted empty-hand
grants under `native_policy`: reference GBA read six times and healed 35 HP
for a 7-HP Berry override, versus two reads and 7 HP in the host. That gap
was excluded from equal observations and rejected by the strict checker.
PR #166 resolves this historical discrepancy; unchanged #165 remains a
negative control. The unchanged pre-hook #164 engine also reports unavailable,
dispatches zero callbacks and cannot suppress native Leftovers. Full Choice
Band locking and other native battle rules remain additional work.

Feature ref `1ce83faf4b980584be9d747eee82efc530ede09f` passed
122/132 engine suites, SDK 3/3 and B30, with exactly the prior ten baseline
failures repaired by #128–134; all 26 FAIL lines match #164. Imported Red
battle/save-conversion/parity J/K regressions passed 468/468, 95/95, 73/73 and
22/22; no external binary save fixture was supplied. The combined runtime
includes those baseline repairs and passes 177/177 engine suites. Later
changes only record this validation.

All 26 hosted #165 PR workflows report `action_required` pending maintainer
approval. The [new held-item workflow](https://github.com/UNDERdecoded/Gen2Recomped/actions/runs/40054092842)
has zero jobs and has not executed. Local validation above is separate.

## Native GBA item-scheduling test

Install and enable the unchanged public `examples/portable_held_item` mod,
then use the isolated installation with an imported FireRed or Emerald:

```sh
POKEPORT_VERSION=firered POKEPORT_DRIVER=tests/drivers/held_item_scheduling.lua \
  bash scripts/run-portability-test.sh
```

The driver starts New Game in memory, builds a native battle, chooses FIGHT
and a move through native input, and drains the normal result queue. It checks
bounded empty-hand grants across a full turn, poison cure before lethal chip,
consumption and unsubscribe. It does not write a normal save or prove a full
playthrough. Gold uses the existing `tests/drivers/held_item.lua` smoke.

## Native held-definition test

Install and enable `examples/portable_held_content` in the isolated identity:

```sh
POKEPORT_VERSION=gold POKEPORT_DRIVER=tests/drivers/held_content.lua \
  bash scripts/run-portability-test.sh
```

The driver uses an in-memory New Game and constructed native battle, actual
FIGHT/move input and result queues. It checks imported public item IDs,
7-HP healing and consumption, detached reads and frozen writes, then stops
before finish/afterBattle/SAVE. This is not a full-playthrough or pixel test.
Keep this example separate from the older `portable_held_item` example when
checking unmodified native behavior.

## Native mart-definition test

Install and enable `examples/portable_mart_content` in the isolated identity:

```sh
POKEPORT_VERSION=gold POKEPORT_DRIVER=tests/drivers/mart_content.lua \
  bash scripts/run-portability-test.sh
```

The driver starts an in-memory New Game, compiles bounded native shop IR,
runs real script coroutines and uses actual menu input. It verifies imported
public IDs, ordinary and bargain prices, money/inventory, sold-out and reopen
protection, runner close/resume and detached/frozen public records. It exits
without a normal SAVE action. It does not claim a full playthrough, fresh full
ROM reimport, daily stock reset or special-shop pixel equivalence. Old imported
marker-only fallbacks need reimport for the new mart-ID annotations; the
normal ROM-script path uses the live pool directly.

## Native Pokemon identity-hook test

Install and enable `examples/portable_pokemon_rolls` in the isolated identity:

```sh
POKEPORT_VERSION=gold POKEPORT_DRIVER=tests/drivers/pokemon_rolls.lua \
  bash scripts/run-portability-test.sh
```

Gold, FireRed and Emerald pass. The driver starts an in-memory New Game and
uses imported species metadata, real constructors, native summary creation/
drawing and B-close input. It checks common API-3 IDs, Gen-2 refresh, GBA
cached display/live query distinction, unchanged genes/stats under plain
overrides, the native forced-wild constructor and callback bypass, then
retires the callbacks. It does not perform a normal SAVE action or claim a
complete battle/playthrough, raw save-format or pixel equivalence. Deliberate
Gen-2 DV edits are a separate mutation case in the shared contracts.
