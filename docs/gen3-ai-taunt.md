# Native GBA AI Taunt predicates

The native AI importer already decodes `if_target_taunted` and
`if_target_not_taunted`, but the host did not implement them. Reachable scripts
containing either command were therefore unavailable. Both predicates now
read the live target's `tauntTurns`; they do not read the user or its partner,
change the timer, or consume RNG. Other unsupported commands remain gated.

GBA Taunt now sets two residual ticks, matching the native `Cmd_settaunt` and
Gen1Recomp's owned effect. A repeated effect does not refresh the timer, and
an explicitly cleared zero counter permits application, and it can be applied again after expiration. Existing non-GBA duration behavior
is preserved.

The shared case file runs real equivalent AI programs through each engine's
VM. It checks both predicate directions, missing/zero/live timers, distinct
single/double targets and unchanged query state/RNG. It also calls each
engine's real owned Taunt effect and residual implementation to verify the
same 2 -> 1 -> expired lifetime, repeat refusal and reapplication. The source
uses its actual residual scheduler and adapter; only ROM text presentation is
replaced. This effect-stage fixture does not establish move-selection,
accuracy, animation or full gameplay parity.

Gen1Recomp's old predicates always treated the target as not taunted. The
paired source fix replaces those placeholders. Cross-engine checks require
the clean, explicitly pinned fixed reference documented below; they do not
claim agreement with the old placeholder implementation.

```sh
luajit tests/engine/gen3_ai_taunt.lua
python3 tools/gen3-ai-taunt-contract-check/check.py --gen1 /path/to/fixed/gen1
```

No ROM, generated cartridge assets or graphical process is required.

The fixed Gen1 reference is
`Roxas2712/gen1recomp-Mac-fix@cdd4ad167373e2b5f08c96f95ee87041f59e0e17`,
based on upstream dev `535a5ec088c1ae1bf4d91dd3e35a56f64cf46d91`. Its only
production changes replace the two AI predicate placeholders. The workflow
checks out this explicit counterpart; it is not an upstream merge claim.
