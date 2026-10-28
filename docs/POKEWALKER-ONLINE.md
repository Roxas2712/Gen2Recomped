# Pokéwalker account and cloud integration

Contributions by Roxas2712. This change builds on the existing Pokéwalker,
ModCompass identity, friend list, chat, private object storage and save sync.
It does not introduce another account service or a ranked multiplayer mode.

## Implemented

- `ProfileFs` isolates the walker, recovery copies and transfer backups for
  each account and for guests. The linked legacy account keeps its paths.
  An unbound legacy guest walk is copied and verified into the guest profile;
  recovery bytes remain there. A migration marker prevents leftover shared
  originals from reappearing in a subsequently linked account after a crash.
- Walker state references are bound to their profile. Switching accounts,
  loading a new state or adopting a cloud snapshot retires stale references.
  An open minigame closes without paying into the new account. Passive-time
  counters are reset at account boundaries.
- `WalkerCloud` uses `profiles/pokewalker/state.lua` in the existing account's
  ModCompass object store. The snapshot includes the walk, watts, inventory,
  cosmetics, purchases, achievements, daily minigame budgets and records.
  Native step-journal cursors remain local to each device.
- Cloud sync follows existing account/slot sync. A walking Pokémon refers to
  its existing cloud save ID; the destination resolves its own local slot.
  Unsynced or missing source saves block transfer. An open source game or an
  identical Pokémon already present in that save blocks restoration.
- Only one side changing permits normal upload/download. Concurrent changes
  preserve the local state and an account-private remote recovery copy under
  `walker/conflicts/`. No balance, catch or reward lists are merged. The object
  store's existing `If-Match`/`If-None-Match` guards reject competing writes.
  Login restoration never silently discards a locally changed walker.
- Sync pauses walker mutations and is deferred while an active minigame run
  is unfinished. This synchronizes progress and records, not an in-flight
  minigame's frame/input state. Corrupt local files block replacement.
- Settling the same minigame purse twice pays once. A reported persistence
  failure restores the preceding in-memory wallet, records and budget.
- **Friends & cloud** opens the existing friends, inbox and chat interfaces.
  It uses their account-scoped presence cache and preserves server visibility
  decisions. Guests can continue local walks/minigames and see the sign-in
  entry point. Personal score tables are labelled as personal records.
- Shared minigame menus/results use the launcher language. Names are inserted
  after translating templates; the font cache follows language changes.

## Configuration and rollout

No new server migration, dependency, relay or credentials are required for
these progress/social changes. Existing ModCompass object routes already allow
`profiles/…` paths, enforce account ownership, encrypt stored objects and apply
the normal progress quota. Existing cloud-sync opt-in and restore controls are
retained. New code is reviewable separately from the private PokéSlide work.

Local recovery copies and migration markers must be retained when upgrading or
rolling back. Do not remove guest/account profiles to resolve a conflict.

## Verification

- `tests/engine/account_profiles.lua`: real profile routing and stale-state
  refusal, including separate guest progress and account-private backups.
- `tests/engine/walker_cloud.lua`: simulated device profiles, serialization,
  source-save mapping, concurrent changes, corrupt files, account changes,
  duplicate-Pokémon checks and failed remote writes.
- `tests/engine/walker_legacy_storage.lua`: legacy migration with verified
  private copies and a simulated residual original after interrupted removal.
- `tools/walker_minigames_check.lua`: the existing five games, daily/run caps,
  scoring, controls, repeated settlement and failed reward persistence.
- `tools/qualify_walker_http.py`: seven phases using real `RetroCloud`, `Task`,
  `WalkerCloud` and LÖVE profile processes against the actual Laravel server
  checkout, an isolated SQLite database and disposable fixture accounts.
  Thirteen assertions passed: upload, restore/advance, resume, conflicting
  branches, foreign-account isolation and server revision enforcement.
  The simulated devices share the test account credential; this does not
  qualify separate device login or public HTTPS operation.
- `tools/qualify_walker_online.py`: the actual LÖVE page renderer at 360 and
  1120 pixels, plus the 360-pixel guest view. Checks control bounds/overlap;
  screenshots were inspected. Social data is synthetic; no real account,
  ROM or production mutation is used by the rendering fixture.

Both qualification tools use `qa_storage.py`, isolated profiles and ephemeral
hosts. Reports remain in `.local/qa/walker-http-<label>` and
`.local/qa/walker-online-render-<label>`. Credentials, databases and user data
must not be committed.

## Still separate work

The five existing minigames do not yet have their own shared real-time friend
duel protocol or a server-authoritative public leaderboard. The new page says
so explicitly. Neither local records nor uploaded snapshots prove fair play
or make walker rewards eligible for competitive prizes.

End-to-end native Pokémon return/delivery across devices, interruption between
writing the source save and walker file, physical step sensors and production
OAuth/HTTPS remain unqualified by these tests. Existing source-save and walker
writes are individually protected; they are not a distributed inventory
transaction. A recovery chooser for concurrent walker branches remains to be
implemented; the current behavior blocks and preserves both copies.
