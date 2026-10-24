# Native GBA AI random-branch contract

The native AI bytecode's four random comparisons consume `rng(0, 65535)`
and compare the result modulo 256 with the script's byte operand.
`if_random_less_than` and `if_random_greater_than` previously drew only
0–255, changing deterministic RNG behavior. `if_random_equal` and
`if_random_not_equal` were absent, causing the host's whole-script capability
gate to skip any reachable script using them.

All four operators now use the native draw range and byte comparison. The
existing whole-script gate still refuses other unsupported instructions.
This change does not add the unfinished public enemy switch/item hook.

## Shared interpreter checks

`tests/gen3_ai_random/cases.lua` runs equal conditional/score/call/end programs
through Gen1Recomp's actual GBA `AiVm` and Gen2Recomped's actual `Gen3AI`.
No copied interpreter or stubbed score handler supplies the result. Each
program scores two moves with consecutive RNG values, checking both branch
effects and complete RNG ranges/order. The matrix covers FireRed and Emerald,
all four comparisons, operands 0/128/255, and ten raw values from 0 to 65535,
including equal low bytes with different high bytes.

Run the ROM-free engine checks and cross-engine comparison with:

```sh
luajit tests/engine/gen3_ai_random.lua
python3 tools/gen3-ai-random-contract-check/check.py --gen1 /path/to/gen1
```

The reference checkout must be clean at
`535a5ec088c1ae1bf4d91dd3e35a56f64cf46d91`. Workers run from their respective
engine directories; the same case file drives both. The dedicated workflow
retains its JSON comparison report.

These checks prove native interpreter branch behavior. They do not claim
complete AI opcode coverage, identical damage estimates, full ordinary
opponent-controller RNG setup, or a portable public battle-hook contract.
