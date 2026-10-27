# Public true-color rectangle compatibility

The pinned Gen1 reference returns one live rectangle array per pass, clears that array in place and allocates fresh records for later frames. The pooled implementation exposed stale entries through the array length and rewrote retained records.

Public readers now receive the original live-array behavior. Native rendering borrows private pooled records until a public reader observes that pass; public edits and getter overrides remain authoritative. The classic UI mark offset is restored. The existing hotPathHoist switch still disables the private fast path.

Validation: 24 targeted assertions plus all native suites, the performance switch matrix, API3 and external mod fixtures: 121 successful runs with an unchanged source fingerprint. See public-truecolor-rectangles.json. No FPS claim is made.
