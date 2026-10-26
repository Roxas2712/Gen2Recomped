# Native ROM language packs

The fork exposes `mod.localization` and the capability
`mod:supports("localization", "rom-language-v1")`. Capability discovery is lazy:
it does not construct Game, read a cartridge, load graphics or register a pack.
Supported targets are Red, Blue, Yellow, Gold, Silver, Crystal, FireRed,
LeafGreen, Ruby, Sapphire and Emerald. This is a profile-driven language
contract, not support for arbitrary ROM revisions or unrelated games.

```lua
return function(mod)
  if mod.localization and mod:supports("localization", "rom-language-v1") then
    return mod.localization:install({format="rom-language-v1"})
  end
  -- Existing implementation for a different host.
end
```

Version 1 consumes Uni-Language Ascendant's existing catalog, exact-ROM
requirements, shared extraction recipes, startup UI and language menu. The
native implementation lives in `src/translation/rompack`; it is no longer
shipped as a separately maintained `fork/` subtree inside the mod ZIP.
The original local adapter sources are retained in the mod development tree
as historical work, but are excluded from the native package and execution.

Host-owned responsibilities include native text/name ID projection, localized
asset/font binding, live language application, restoration and rollback. The
central Assets service resolves session-owned memory files; native image and
pixel readers use the same source without patching LOVE constructors. Retired
event buses stop exposing a previous game's files. Source/recipe fingerprints
invalidate compiled caches after engine updates. Machine translation defers
to the cartridge language pack while that session is active, without changing
the user's saved launcher settings.

The language picker imports through the launcher's atomic optional-import
store. It checks the catalog's SHA-1 in addition to the declared size and MD5.
Legacy `language-inputs/` inputs migrate to this same native store. Neither
imports nor language application change the base English cache. Language
changes are restricted to the title or settled offline overworld and preserve
live save data, position and stable gameplay identities. Failure rolls back
to the prior language; no ordinary game save is written.

Native API example above is intentionally format-versioned. It does not make
every existing Gen1 internal module name or renderer interchangeable. The same
mod keeps its original Gen1 implementation and selects this native backend
through capability discovery.

Validation:

```
luajit tests/engine/rom_language_pack.lua
python3 tools/check_native_languages.py --mod /path/to/uni-language-ascendant \
  --love /path/to/love --out .local/qa/native-rom-languages
python3 /path/to/uni-language-ascendant/tools/package_native.py \
  --engine . --qa .local/qa/native-rom-languages/receipt.json
```

The real-ROM runner uses isolated identities, a frozen source snapshot and the
ordinary mod payload without its old host subtree. The final receipt binds
the precise engine sources, mod bytes, logs and scoped native observations.
Absent source languages are not certified by German runs. All derived host
modules retain their GPL-3.0 provenance; see
`src/translation/rompack/NOTICE.md`.

Fresh installation additionally exercises the launcher’s atomic import publication into a new `baseroms/` folder and ZIP replacement of a populated profile. Private inputs and the data-only profile are copied from the rollback snapshot and verified before that snapshot is retired. LOVE 12 file creation uses `openFile(path, mode)`; stable 11.5 retains its unopened-File path. Both ranged readers retain edition-prefix routing.

Known inherited display limit: the native Ruby/Sapphire fallback summary view has overlapping text rows in both English and localized mode. This integration does not certify Gen1 screenshot parity or repair that existing summary renderer. Native profiles, source-derived text and the recorded runtime operations are covered separately from full visual parity.
