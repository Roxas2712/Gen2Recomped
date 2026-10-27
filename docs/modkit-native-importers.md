# Native importer source and ROM-content lint

MK301 continues to reject shipped generated-cache paths, JSON assets pointing
into that cache, and executable cache references in ordinary mods.

A Lua importer that declares `engine_internals` and at least one sized,
MD5-checked required or optional import contract may read or rebuild the player's
generated cache. Such source references produce a visible MK301 warning.
This covers native language/graphics extraction recipes without changing
the mod or requiring it to ship extracted game data.

The exception applies only to source references. It does not exempt generated
files, ROM/patch formats, audio banks, matching/near-matching cache assets or
bulk data dumps from their existing checks. Declaring the permission alone
does not qualify. Runtime import validation and permission checks are unchanged.
Lint checks the declaration, not the presence or contents of a user's ROM.
`--strict` continues to promote the source-access warning to a failure.

Regression coverage: `tests/test_modkit_native_importer.py` and
`tests/test_modkit_cache_comments.py`.
