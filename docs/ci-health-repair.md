# Fork CI repairs, 2026-10-24

Scope: `codex/native-origami-foundation`, following `db804374`. The
Origami-specific port stays paused. No existing Gen1 checkout or player
runtime, saves, ROMs or imported caches are used by this work.

## Causes and corrections

| Original failure | Correction |
| --- | --- |
| Controller tests expected eight actions and fixed SELECT row 8 | Test the twelve GB/GBA/DS actions, find menu rows by action identity, and verify Y retains its native DS X binding until close |
| Soft reset / tool hooks called delegating Game methods on incomplete tables | Let the stand-ins inherit the current Game method table and provide the required touch-button image entries; execute the real step/draw paths |
| Quit test matched an earlier import-only quit branch | Scope to `love.run` and execute its actual event-dispatch body with isolated Android/desktop doubles, checking veto and exit order |
| Update tests offered Gen1 assets to the Gen2 package parser | Use the engine's `Gen2Recomped-*.love` identity and existing upstream release URL; verify foreign Gen1 assets are rejected |
| Wide animation fixtures were not centered on either picture anchor | Test actual 26/124px centers, midpoint interpolation and player-side overshoot; do not revert the corrected animation map |
| Six public seams had no contract tests | Real mod entries subscribe/wrap; real engine entry points drive Birch start/finish, bulk blocks, fixed ticks, egg completion and Gen4 healthbox ownership |
| Fixture digest golden predates the current native effect catalog | Deliberately re-pin to the existing runtime digest and add the entire canonical input and explicit Gen2/Gen3 mutation tests; see [the audit](known-differences.md#fork-fixture-fingerprint-baseline-2026-10-24) |
| MK301 flagged cache names inside documentation comments | Reuse the existing Lua comment lexer; keep quoted/long-string and JSON references, generated-tree files, and other content gates active |

No event/hook is added to coverage debt, no suite is disabled, and no
`continue-on-error` or skip is added to make these checks pass. Runtime battle
data and the fingerprint algorithm are unchanged. The mod content is unchanged;
the lint correction distinguishes comments from executable references.

The new public field test bounds unrelated mechanics at the post-tick update
boundary, while the real native update emits into the mod's public subscription.
The no-listener case confirms `world.tick` does not call emit. Hatch completion
is tested at the real message callback. These are lifecycle contract tests, not
visual/gameplay acceptance of a complete map or intro sequence.

## Validation

- Full ROM-free runner: `LUA=luajit ./scripts/test.sh` — all available tiers pass
  (90/90 engine suites, 3/3 mod-SDK suites, Dramatic Shape B30).
- `python3 -m unittest discover -s tests -p test_modkit_cache_comments.py` —
  four test methods cover comment forms, executable literals, JSON and files
  shadowing generated trees. Dedicated combined-contract CI runs them.
- `python3 tools/modkit.py lint mods/DRAMATIC_SHAPE` — passes with the source
  content unchanged.
- Imported-content/link and real gameplay tests remain unrun because this
  checkout contains no imported ROM data. The runner reports that absence.

Hosted CI results are recorded in the PR after pushing the repair commit;
local passes alone are not described as hosted CI success.
