# Console archive admission

Contributions by Roxas2712. Based on PR #402.

The native ZIP installer exposes `NX_MAX_ZIP_BYTES` (64 MiB) and rejects known
oversized Switch inputs before allocating their archive body or mounting them.
It checks dropped-file sizes, external-file lengths and merged-filesystem
metadata. Unknown-size console reads use a bounded one-byte overflow probe.
Handles close on refusal. Desktop read limits and provider call shapes stay
unchanged.

The ROM-free `nx_mod_archive_preflight` suite checks rejection before body reads,
the exact boundary, mount/replacement exclusion, closed handles, unknown-size
reads and desktop compatibility. Existing launcher/status and release-selection
suites also pass. Actual installation is not attempted in these tests.

This is the concrete size-admission part of the installer audit. It does not
implement cooperative installation, cancellation, atomic directory replacement
or inbox scan jobs, nor certify an actual Switch device or arbitrary archive.
