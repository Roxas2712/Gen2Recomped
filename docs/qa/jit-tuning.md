# JIT tuning qualification

The main state, audio worker and pure build workers apply the optional trace limits before loading engine modules. `POKEPORT_JIT_OPT=0` preserves runtime defaults; an explicit option list replaces the set. Failed tuning leaves the runtime usable.

Qualification: 15 targeted assertions, including actual compiled trace generation, all 53 native engine suites, every performance switch independently disabled, all-on/all-off, gallery, hooks, API3 against the pinned 535a5ec reference and 17 unchanged external fixtures. The real LÖVE 11.5 build worker host also passed. All 126 runs passed with a stable source fingerprint; see `jit-tuning.json`.

These checks establish behavior and compatibility. They do not measure gameplay trace eviction, frame time, or battery use.

Current-main integration also includes the Gen4 GPU skinning predecessor and the concurrent first-run/cloud changes. All 133 runs passed, including the four affected first-run/locale/private-suspend/sync suites. See `jit-tuning-current-main.json`; earlier measurements remain pinned to their recorded revisions.
