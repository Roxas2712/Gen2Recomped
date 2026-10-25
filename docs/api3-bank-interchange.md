# Bank interchange and account-shared Lua storage

RetroRecomped API 3 adds two versioned interfaces: `mod.storage:shared(game)`
for a mod's data across games, and `mod.bank` for explicit Bank-copy exchange.
Normal per-playthrough `mod.storage` remains available. Both new persistent
interfaces require a linked account with a confirmed email. Existing verified
local profiles work offline. A handle remains bound to the account that opened
it and refuses access after the active account changes.

## Shared storage v1

```lua
local shared, code, message = mod.storage:shared(mod.game)
if not shared then return nil, code, message end
local context = shared:context() -- versioned mod/account scope; no disk paths
local record, reason = shared:read("legacy-bank/v1/main")
if not record and reason ~= "not_found" then
  return nil, reason -- damaged data is not an empty Bank
end
-- Write only after the mod's own validation and user action.
local ok, failure = shared:write("legacy-bank/v1/main", record or {
  schema = 1, pokemon = {}, items = {},
})
```

The detached facade has `context`, `read`, `write`, `delete`, `exportPackage`,
`importPackage` and `listPackages`. A mod ID names one account-private namespace
across all games. It does not grant access to another mod's namespace.
`read` is deliberately read-only: it does not promote staging or backup data.
This lets a transactional Vault classify main, backup and staging itself.
Writes verify their staging file and retain a backup. This is not a multi-key
transaction or a distributed lock.

Keys are nonempty letters, numbers, dash and underscore segments separated by
`/`, at most 240 bytes. Absolute paths, dots, backslashes and empty segments are
rejected. Values must be data tables, at most 16 MiB encoded. Functions,
userdata, threads, metatables, cycles, non-finite numbers and unsupported keys
require a mod-owned data adapter and are rejected. Traversal is bounded to
200,000 nodes and 96 levels.

`exportPackage(name, table)` returns `true, nil, receipt`; the receipt contains
`name`, `modId` and encoded byte count. Export names are immutable: an identical
retry succeeds, different contents require a new name. `importPackage(name)`
returns a detached data table. `listPackages()` returns sorted `{name=...}` rows.
These methods store local packages; they do not execute them or start uploads.
Failure returns `nil, code, message`, with codes such as `not_found`,
`account_required`, `invalid_key`, `invalid_data`, `already_exists`,
`size_limit`, `write_failed` and `delete_failed`.

## Bank API v1

```lua
assert(mod:supports("bank", "inspect"))
local report = mod.bank:inspect(pokemon)
-- report.schema, serializable, reason, fields[{name,kind}], types, nodes
if not report.serializable then return nil, report.reason end

-- confirmed must be the boolean true following an explicit player action.
local id, why = mod.bank:deposit(mod.game, pokemon, confirmed)
local package, exportError = mod.bank:export(id, confirmed)
```

`formats()` lists supported schemas. `deposit` makes an immutable copy of the
full Pokémon Lua record and records the mod ID/version, game, slot, playthrough
and trainer ID. Unknown serializable mod fields remain in the record. Export
includes trainer/origin information and should be explained in the mod's UI.
The confirmation argument records the trusted installed mod's decision; it is
not a sandbox for hostile installed mods or an account authorization token.

For KASC packages:

```lua
local preview, why = mod.bank:previewLegacy(packageBytes, sourceGameOverride)
if not preview then return nil, why end
-- Show preview.entries, blocked, items and lua before asking for confirmation.
if #preview.blocked > 0 then return nil, "Resolve the blocked records first" end
local receipt, problem = mod.bank:importLegacy(preview, confirmed)
```

The reader accepts `kanto-ascendant.legacy-bank-package` package v1 with Vault
schema 1 or 2, and `retrorecomped.bank-copy` v1. Packages are restricted Lua
data grammar, not executable Lua, with an 8 MiB limit matching the Cloud object
limit. Source game definitions must be locally imported. Unknown/custom
editions need an explicit source-game choice or a provider adapter. No ROM data
is requested or included by the interface.

The KASC adapter verifies the full Vault hash, Pokémon hashes, item hashes,
unique record identities and declared schema. Leased/pending Pokémon cannot be
imported until resolved in KASC. Commit recomputes copies from the verified
package; changing a preview's entries cannot change what is imported. Repeating
an unchanged import is idempotent. Source saves and Vaults are never deleted.
An interrupted multi-record import may leave some valid immutable copies; retry
completes the rest. It does not promise an all-or-nothing multi-file commit.

Genetics, training, evolution, Move-Memory, extensions, source identities and
transfer history remain in the namespaced KASC provider record. The entire
Vault, including item scopes, quantities, transactions and receipts, is retained
in a content-addressed archive and travels through normal Bank sync. Archived
KASC inventory is **not** automatically minted into the native Item Bank or
equipped; that needs a provider-specific item/transaction adapter. Ordinary
native carried items use `pokemon.item`, with legacy `heldItem` input supported
on conversion. Conflicting aliases are refused. Gen1 destinations stage item
custody; returning to a compatible game uses the native `item` field.

The generic Bank-copy export preserves provider extensions. KASC does not yet
consume that generic format automatically: reverse transfer requires a KASC
adapter. Shared mutable Vault storage is local; only explicitly imported
immutable archives are included in Bank sync. Neither interface serializes a
running script, battle callback, coroutine or exact gameplay continuation.

## Launcher review

Open **Pokémon Bank → Legacy / Lua** to preview and confirm a package or export
the selected Bank copy. Desktop uses the existing native file dialog. Dropping
a package onto this page also works. Mobile/console fallback lists `.lua` files
explicitly copied into `imports/bank/`; reviewing never consumes the input.
Exports are account-private under `bank/exports/`.

Portrait Bank views show one touch-sized box at a time, with Save A / Bank /
Save B tabs. Tap a source Pokémon, change tabs and tap an empty PC cell to stage
a copy. Small screens page through portions of a box instead of shrinking its
cells. The Pokémon Info page shows complete origin IDs and the Lua inventory;
desktop keeps the three simultaneous panels for dragging between them.

The ROM-free launcher contract includes `tests/engine/bank_interop.lua`, native
item conversion regressions and the existing API-3 playthrough/storage suites.
These verify persistence and interfaces without launching a game. They do not
establish full KASC gameplay compatibility.

An optional trusted KASC checkout can additionally exercise its actual pure
Vault/Store code with synthetic data and an in-memory filesystem:

```sh
python3 tools/run_retro_launcher_contract.py --legacy-bank-source /path/to/KASC
```

The runner pins these source inputs through QA storage before starting tests.
It never reads that checkout's player saves or launches its game/mod entry.
