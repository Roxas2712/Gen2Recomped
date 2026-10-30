# Cancellable native mod installation

Contributions by Roxas2712. Existing mod manifests, code, native APIs and synchronous
`LauncherMods` entry points retain their format and behavior. The native launcher
now uses cooperative jobs for ZIP picks, drops, batches, inbox/folder scans,
downloaded releases and cloud profile backup/restore/commit.

The launcher displays progress and Cancel. Escape and gamepad Back/B also cancel.
Other package edits and Play are blocked while an installation is active.
Download cancellation retires the existing download worker; a late worker result
cannot start installation. Mobile picker success and source consumption wait until
the job has closed the archive and reached its terminal result.

## Publication and cancellation

Archive reads, package copies, byte-for-byte readback, retained `baseroms/` imports
and cleanup run in 256 KiB chunks. `stepInstall` uses a soft 6 ms frame budget;
individual filesystem calls, ZIP mounting and the small commit cannot be preempted.
Desktop archives are staged to disk, rather than copied wholesale into Lua memory.
Switch retains the 64 MiB compressed archive admission limit.

Before publication, cancelling leaves the current package untouched and removes
only installer-owned staging files. At commit, the old directory is renamed into
a recovery area and the verified package is renamed into place, without yielding
between those operations and the metadata commit. The installer then refuses late
cancellation and finishes cleanup. A batch keeps earlier fully committed packages;
the notice reports their count. A cloud profile instead preserves a complete
backup and restores the prior package stack and activation if the transfer fails
or is cancelled. Pinned profile versions are checked before publication.

The writable root is captured per job and rechecked across every yield. Download
destinations are also bound at request time. Jobs never borrow `CacheFs.prefix`.
Source checkouts and packages outside the chosen writable root are refused before
replacement. They remain usable at their existing location. Select/import a ZIP
into the intended data folder rather than overwriting such a location.

## Interrupted processes

Bounded data-only JSON receipts live under `mod-install-journal/`. Unique work
areas live under `mod-install-staging/`. The launcher recovers these on entry,
before Play. An uncommitted exchange restores the old complete package; a committed
exchange retains the new package and resumes cleanup. The existing native profile
recovery format remains supported, including incomplete backup preparation and
interrupted profile rollback/cleanup.

Recovery validates roots, IDs, states, manifest identity and confined paths before
moving packages. Unexpected or changed metadata preserves the recovery files and
blocks Play instead of guessing which files to remove. Process shutdown closes
handles and mounts but leaves durable recovery for the next launch. No global
profile, mod, cache or download-directory sweep is used.

## Job API

`beginInstallZip(source, opts)`, `beginInstallMany(sources, opts)`,
`beginInstallInbox(first)`, `beginInstallFolder(path)` and
`beginInstallFromRelease(id, release, path, expectedGame, expectedVersion)` return
a job, or `nil, reason` when another job is active. Options and release metadata
are detached from the caller. Borrowed source paths are never removed by the job;
download-owned files are retired only after their handles are released.

`stepInstall(job, budgetSeconds)` returns `running, progress` or
`done, result, detail, versionOrWarning`. Results follow the corresponding native
synchronous API. `cancelInstall(job)` returns false once publication has begun;
otherwise keep stepping until terminal cleanup completes. `installBusy()` includes
cleanup. `beginRecoverInstalls`, `beginBackupProfile`, `beginRestoreProfile` and
`beginFinishProfile` use the same scheduler. `releaseStaleInstalls` is the process
shutdown boundary, not a successful cancellation result.

## Qualification

ROM-free engine tests cover cancellation at read/copy/verification/ready boundaries,
copy/close/publish/options faults, simulated process interruption, native Gen2
loader/events, caller mutation, source-root guards, batch cancellation, download
retirement, launcher input guards, deferred mobile consumption and profile rollback.

`python3 tools/qualify_mod_installer.py --love /path/to/love` additionally tests real
ZIP mounting, filesystem directory exchange, default and custom data roots, corrupt
and incompatible packages, readback, restart recovery and profile IO in a new QA
identity. The public `Cancellable mod installer` workflow runs those filesystem
tests on Linux, macOS and Windows and publishes evidence. No ROM, live catalogue,
user mod or player installation is used. These checks qualify installation and
preservation of native mod contracts; they do not certify every third-party mod's
gameplay or the physical mobile/Switch picker UI.
