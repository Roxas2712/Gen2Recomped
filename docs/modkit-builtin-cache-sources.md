# Built-in localization source pins

The built-in Uni-Language package contains compiler recipes, profile bindings
and native cache adapters. Their source names virtual compiler outputs and
native cache paths; these strings are not packaged cartridge bytes or images.
The generic MK301 reference scan previously rejected this inherited package
in every PR CI merge containing it.

`tools/modkit_builtin_cache_sources.json` records exact SHA-256 hashes for the
56 existing Lua sources that need those references. Only the repository's
own policy applies, at its exact built-in mod path, for the declared manifest
id with `engine_internals`. A policy shipped inside a mod has no effect.
Changed source bytes require inspection and an explicit pin update. JSON
references receive no exception.

These pins affect only MK301's source-reference finding. Generated-tree
files are still rejected before the pin check. Cartridge and patch files,
audio banks, duplicate bytes, image comparisons and all other content gates
run unchanged. MK303 now also covers the supported GBA/NDS cartridge
extensions, which the old GB-only list omitted. Ordinary mods retain the
original reference policy. No runtime
mod permission, file lookup or asset transform behavior changes.
