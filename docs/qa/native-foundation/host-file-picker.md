# Shared native desktop file selection

Contributions by Roxas2712 — https://github.com/Roxas2712.
See LICENSE-ROXAS2712.md for contribution terms and the specific integration
permission for Cedric / UNDERdecoded. Existing rights/notices remain intact.

Source consumers can use `FilePicker.available/open/commands/matches/read/basename`
and the standard image filter. The native importer's by-extension picker uses
that same command builder. Dialogs still launch only through its existing
pointer-release path; importing or querying the module never creates Game or a
save owner. Reads are binary and read-only, with handles closed on read failure.

The builder validates filters and preserves UTF-8 titles as data. POSIX shell
and AppleScript quoting are separate. Windows passes dynamic title/filter data
as byte arrays, preserves the existing no-copy fast path for ASCII paths, and
uses unique non-ASCII staging paths with fail-closed copy errors. A canceled
Linux chooser does not open a second dialog; it selects the available zenity
or kdialog backend before launch. Unsupported hosts retain their existing
mobile/no-picker workflows. Failed dialog reads close their pipe and return
no selected path.

Frozen fork `939f268ed2` passes 76 CPU groups. Exact older-public composition
`d6a78527f9` passes 41 groups. Both include 90 modeled desktop-picker checks,
27 existing pointer-grab checks, 12 no-picker checks and 14 Android picker
checks. The public test's older source-text counter was counting comments as
process calls; it now excludes comments, as the current native test already
does. The actual pointer-release scenarios and single process funnel remain
checked. The public composition retains its existing native shell/importer
bodies and applies only these narrow changes. CI runs the four picker suites.

No real Windows/Linux dialog, desktop-wide UI acceptance or sprite-pack
installation is inferred from command-model tests. QA uses owned profiles,
preserves player saves and enforces 20 GiB free, above the requested 8 GiB.
