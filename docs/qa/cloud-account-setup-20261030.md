# Automatic account cloud — 30 October 2026

Integration: Roxas2712. Existing engine and contributor rights remain unchanged.
No ROM, user progress, account credential or test database is committed.

## Player workflow

Sign in to the existing ModCompass account in the app. Automatic normal-save
sync is recommended in the login/registration form. Confirmed, approved accounts
on a clean device get a private progress profile automatically. An existing
explicit opt-out made with this setup version is remembered.

If unassigned local or guest progress exists, choose once whether to use that
progress or start a separate profile for the account's cloud saves. Adoption
keeps the original files in place. A claimed guest directory becomes private;
signing out uses the next unclaimed guest directory. Another account cannot
read the claimed progress. Installed game packages remain shared locally;
progress, mod settings and pending uploads are account-scoped.

Normal saves enqueue durable background work after a successful local commit.
The upload never replaces the running slot. Offline/network errors retain the
queue, use bounded retry backoff and survive restarting the app. An older
upload cannot acknowledge newer progress saved while it was in flight. Changed
saves found at startup are discovered from the persisted link hashes as well.
Turning automatic sync off stops sending and keeps pending work.

Signing in restores cloud progress before automatically starting a requested
game. Partial failures/conflicts remain visible for review. A fresh edition
selects its newest restored save; subsequent restores preserve a deliberate
active-slot choice. Cloud restores do not re-enqueue themselves. Locally stamped
profile metadata and remote byte hashes are tracked separately to avoid false
conflicts and needless uploads.

Normal automatic saves and explicit exact/portable suspends remain separate.
The exact runtime snapshot still needs its existing compatible engine/import/mod
support and explicit save/upload action. Normal background uploads do not imply
that the current unsaved battle frame is available on another device. Before a
device switch, wait for the cloud acknowledgement.

## Configuration and rollout

- Existing account/session endpoints and object storage are used. No new server
  migration, provider account, API key or sync folder is needed for ModCompass.
- `cloudService='retro'`, `cloudAutoSync=true`, `cloudSetupVersion=1` enable the
  new account workflow. Existing installed users can use **Set up automatic
  account cloud** in Settings or Cloud & devices without signing out.
- Private imported-game uploads remain a separate opt-in. This does not turn on
  ROM uploads. Artwork, mod downloads and other optional transfers retain their
  own settings.
- `cloud_outbox.lua` is private to the progress profile. It contains account ID,
  edition/slot, revision and retry bookkeeping, not save bytes or credentials.
  A damaged/unreadable journal is preserved with an error, not silently replaced.
- Save-link metadata is checkpointed before the first network write and after
  restored files. Equal server/local bytes safely acknowledge a lost response.
  Restored records additionally store `localHash`; older link files still work.
- Background eligibility checks do not open the account UI. Manual all-save and
  overlay transfers wait for an active automatic upload to finish.
- The existing Android bridge is preferred when provided; bundled `https` is
  used on all platforms that include it. Older desktop runtimes retain curl.
  Optional `cloud_clients.lua` configures only Google/OneDrive OAuth; its absence
  does not disable ModCompass. Provider/folder choices live under Advanced.
- Release packages must include the updated source plus either their supported
  native HTTPS/Android bridge or a functioning legacy desktop curl transport.
  Account login does not require secrets packaged with the app.

## Evidence and limits

- Public Windows port: 91 launcher suites and 102 syntax checks passed. Targeted follow-ups cover
  latest-save selection, upload acknowledgements, restored local metadata,
  normal-save commit hooks, ownership/privacy and waiting before game startup.
- German source audit: 1,081 reviewed strings in 27 views, none missing. Other
  languages retain the existing translation/fallback mechanisms.
- Nine real local HTTPS scenarios against the existing Laravel server use
  isolated SQLite storage, accounts and two separate sessions/profiles for one
  account. They cover upload/restore, updated progress, normal success with an
  injected optional exact-state failure, queued offline work, process restart,
  automatic real-HTTPS retry, second-device restore, foreign-account isolation
  and a revoked token. The headless queue scheduler is a fixture; HTTP, TLS,
  Laravel, authentication and object persistence are real.
- Earlier native macOS checks exercise the preceding UI/Task/HTTP implementation
  and the anonymous public account-policy endpoint. They do not qualify the
  final Windows executable. Its build/runtime evidence is recorded separately
  in docs/qa/windows-cloud-demo-20261030.md.
- Windows/Linux/iOS/Android/NX/UWP HTTPS routing is covered by platform/API
  fixtures. The final Windows EXE additionally passed nine native headless
  checks on Windows Server 2025, including real anonymous background HTTPS and
  Unicode filesystem/profile discovery. This does not establish the player's
  physical Windows, phone or console success,
  internet two-device gameplay, or exact modded battle continuation.

No production server change is required or claimed for this client extension.
The specifically reported Windows “paused” failure still needs confirmation
with that machine's updated build and logs if it persists.
