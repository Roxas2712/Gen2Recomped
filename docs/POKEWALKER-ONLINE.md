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
- Conflict review binds an explicit choice to the exact account and both
  complete snapshots. Changed previews are refused. Both versions are backed
  up before selection; no wallet, catch or reward lists are combined. The
  native Friends & cloud page exposes review and complete-version choices.
- Native Pokémon transfers, caught-Pokémon delivery, purchases and queued
  events use an account-local durable intent (`walker_transfer.lua`) before
  publishing their source-save and walker writes. A subsequent cold load
  completes interrupted publication once. Verified source receipts prevent
  replay over later gameplay and refuse stale cross-device returns. Corrupt
  or independently changed files fail closed and retain their evidence.
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
- `tests/engine/walker_transfer.lua`: 667 fault/recovery assertions across
  write boundaries, account changes, stale selections, source receipts and
  staged purchase debits including the existing first-purchase reward.
- `tests/native_walker`: five actual LÖVE processes / 28 checks using a fresh
  own authenticated Ruby import and native save files. Failed walker writes
  after source publication recover across a cold restart, with exactly one
  original Pokémon after return. This injects I/O failure; it is not a
  physical power-cut test.
- `tools/qualify_walker_http.py`: ten phases (thirteen with `--native-import`) using real `RetroCloud`, `Task`,
  `WalkerCloud` and LÖVE profile processes against the actual Laravel server
  checkout, an isolated SQLite database and disposable fixture accounts.
  Thirteen phases / 27 assertions passed with the optional authenticated Ruby
  import: upload, restore/advance, resume, conflicting branches, foreign-account
  isolation, server revision enforcement, explicit local/cloud selection, stale
  choice refusal, and native Pokémon send/return between two process profiles.
  The original client cannot duplicate a Pokémon returned by the other client.
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

Physical step sensors, physical power cuts, separate-device production login
and public OAuth/HTTPS remain unqualified. The native two-file recovery intent
and source receipts are local safeguards; this is not a server-authoritative
distributed inventory transaction. Conflicting whole snapshots require explicit
review. Preserve pending journals and backups when upgrading or rolling back.

The actual original PR source is a negative control: refusing the walker write
after the source save was committed returned success while leaving both the PC
and durable walker empty (four assertions). The journal fixes this loss window.
No real accounts, credentials, cartridge data or user saves belong in public QA
reports; all native and HTTP evidence uses disposable profiles and fixture data.
