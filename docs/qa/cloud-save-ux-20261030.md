# Cloud save feedback and safe re-import — 30 October 2026

Integration and qualification: Roxas2712. Existing engine and contributor rights
remain unchanged. No ROM, player save, credential or imported artwork is committed.

A Windows report showed only “paused”. Without its build/log, this does not
establish the precise failure on that machine. Inspection identified two concrete
problems: cloud saves used raw absolute file reads instead of the account-scoped
persistence filesystem, and optional cache/exact-state/Bank failures could erase
the visible acknowledgement of an already completed normal-save transfer.

## Changes

- `SaveData.readSlotBytes` reads raw bytes through the existing policy and profile
  filesystem, validates slot identity and distinguishes unreadable from empty.
- Cloud sync completes normal saves before exact states and other optional data.
  Link metadata is checkpointed after acknowledged normal transfers. Normal file
  failures retain their reason; exact-state failures have a separate tally.
- The primary in-game upload and single-slot launcher sync transfer normal progress
  only. Exact suspend upload remains an explicit, separate Beta action. Batch
  restore still includes exact states when available. Missing exact states skip
  unnecessary head requests when the store index proves they are absent.
- Launcher and overlay retain a normal-save acknowledgement when an optional
  request fails, times out or is cancelled. Partial status is distinct from both
  complete success and a real save failure. Retry preserves the original slot.
- The library exposes the actual reason and a direct retry button. Known session,
  access, size, quota and rate-limit responses have actionable messages. The
  reviewed new UI text has German translations.
- A changed local save invalidates an earlier green cloud badge. Writing identical
  bytes preserves its acknowledgement; saving new progress requires a new upload.
- Windows prefers the existing native HTTPS module when available; curl remains
  the compatibility path. Sensitive request validation applies before worker or
  native dispatch. Credentials do not become shell arguments or request files.
  Native module API reference: [lua-https](https://github.com/love2d/lua-https).
- Re-import confirmation occurs after identifying the selected RPG cartridge,
  before detaching/rebuilding its cache, including drag/drop and stale caches.
  Picking or cancelling a file keeps the installed game playable. Explicit mobile
  replacement searches use a temporary readiness view without disabling Play.
  Pinball and 3DS replacement entry points use the same review. Cancel/Escape,
  duplicate input, a changed account and an intervening transfer are guarded.

## Evidence

- 97/97 launcher suites, 118 syntax checks; German source audit: 1,115 strings in
  27 views, none missing. Additional targeted checks cover the final mobile-pick,
  normal-only, late-timeout and metadata-write paths.
- Six real HTTPS client checks against the existing Laravel application using
  disposable SQLite storage, test accounts and two distinct sessions for one
  account: upload, second-device restore, normal upload with an injected exact
  failure, restore of updated progress, foreign-account isolation and revoked
  credentials. HTTPS uses a locally trusted, temporary localhost certificate;
  the application server and object storage are real, not an in-memory server.
- Three native macOS UI checks: visible error and inline retry; re-import review,
  double-click guard and Escape preserving readiness; explicit confirmation.
  The full-storage error shown in screenshots is an intentional UI fixture,
  **not a finding about the user's quota**. Original image captures remain private.
- Windows native-API contracts use a simulated OS and API fixture, including a
  profile path containing Unicode, spaces, percent and exclamation characters.
  They are not a physical Windows, production-cloud or native-gameplay test.

The exact user's Windows failure still needs a run of the updated client on
that machine. No claim of successful Windows live operation or production
deployment follows from these tests. Existing modded exact-continuation and
cross-platform battle-handoff limitations remain unchanged.

## Reproduce

Run `tools/run_retro_launcher_contract.py --keep-going` with LuaJIT or
`RETRO_QA_LUA_LIBRARY`. Optional installed Bank/rumble inputs add their existing
contracts. Run `tools/qualify_cloud_save_http.py --server /path/to/server --php
/path/to/php --lua-library /path/to/LuaJIT` against a local checkout containing
the existing `tests/Fixtures/pinball_http.php` fixture. The helper pins inputs,
uses isolated profiles and database, enforces QA storage limits and never uses
production tokens. Native visual evidence uses
`tests/drivers/legacy_cloud_ux.lua` in a managed, credential-free `oasc-…qa…`
profile. Detailed logs and input/source hashes remain in private QA output.

No server migration or server-code change is required by this client change.
