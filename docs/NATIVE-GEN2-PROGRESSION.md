# Shared native GSC experience and learning

The source Mon API now exposes growthFor, experienceForLevel,
levelForExperience, registerInto, newStatExp, gainStatExp, experienceGain,
partySpecies, writeStats, gainExperience and learnMove over actual native
owners. The existing movesAtLevel source spelling now returns source-shaped
slots even without a move registry. Source experience is a live alias to the
native exp field, so HUD/save/combat and source reads share one value.

## Native failures corrected

GSC now evaluates the level portion before participant division. EXP.SHARE
halves the base pool first; callbacks see actual recipient counts and the
halved/luckyEgg flags. Traded/trainer/Lucky Egg boosts use the source rounding
order, inside exp.gain, so a final hook result is not boosted a second time.

One five-word stat-exp owner awards Special Attack yield to shared Special,
not Special Defense or a stale legacy Special member. Pool halving precedes
participant division; active and cured nonzero Pokerus bytes double the
result. The same byte reader serves existing native lifecycle and experience
consumers. exp.gain runs before stat-exp assignment, and effort precedes the
new level/stat calculation, including live hook edits to Pokerus.

Native GSC level-ups use the same progression kernel as the source method:
final stats/HP are committed before one event per crossed level. Ordinary
native battlers follow the replaced stat block; independent Transform stats
stay owned by their wrapper. The source fixed level cap remains 100; the
native path retains its configurable cap. Explicit later IV/EV models and
other generations keep their existing native paths.

Growth coefficient rows and registered callbacks share one evaluator; a
merged registry record wins over the cartridge row. Native construction now
reads this winner. Source registerInto seeds only actual coefficient rows;
the normal native builtin seed retains its named/table curves as well.

A shared rolling four-move window corrects a native GSC arrival bug: after
A/B/C/D, E, A, the result is C/D/E/A, because A was forgotten before its second
appearance. A global ever-seen set incorrectly produced B/C/D/E. Source and
native free-slot learning now share the stored slot and a single learned
event. Full/known source choices preserve the party and report their reason.
Other generations retain their selected arrival policy.

## Evidence and remaining scope

- Committed progression implementation eb4a7183: 2,519,385 arithmetic/source
  checks, 595 actual SDK/native progression checks, 5,295 existing-native-API
  rounding checks; native stat refresh, fields, semantic reconstruction, PP
  and GBA participant suites passed.
- Composed source d7c3c43b, including merged main dbc7d10d: learning188,
  progression595, rounding5295, actual lifecycle80 and PP6642 checks passed.
- The identical progression fixtures on predecessor ae0b75bf fail 528 native
  arithmetic/effort checks, 13 missing source declarations and five actual
  SDK method checks. The arithmetic fixture uses existing native methods,
  independently of the missing new source API.

These are ROM-free semantic/native-owner results, not GPU, GUI, final package
or full VASC acceptance. Source construction/options/identity walkers and the
remaining Mon interfaces, standalone source Battle execution, full reference
visual/download comparisons and final desktop packages remain required.
Supplied mods, ROMs, Gen1 and player profiles were not modified.

Contributions by Roxas2712 — https://github.com/Roxas2712
Original additions are offered under LICENSE-ROXAS2712.md, subject to existing
upstream, Gen1 and third-party rights, grants and attribution.
