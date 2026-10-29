# Download smoke-test worker retirement

The macOS transport job for PR #353 failed while admitting the eighth held
download: `file-download worker queue is full`. The production transport was
byte-identical to the already qualified parent. The test had cancelled and
released earlier requests without waiting for their physical worker responses.
Cancellation deliberately does not return an occupied native queue credit.

The fixture now records real native download IDs and forwards every original
worker result unchanged before acknowledging its completion on a QA channel.
The saturation phase waits for preceding actual responses. A separate barrier
then holds one cancelled worker while seven other jobs fill the remaining
credits. The eighth job must be refused until that worker responds, and must
be admitted afterward. The existing overflow, cancellation, publication and
shutdown checks remain active. Production transport, queue bounds and request
timeouts are unchanged.

## Evidence

Committed composition `b0f3ff0f2c05a4bf28fd6cf3b84d9a2ab2bb0657` passed the
real CPU-only owned-loopback TLS transport fixture on macOS: **1512 checks,
588 pump ticks**, including raw POST bytes, JSON, untrusted-certificate and
redirect refusal, binary GET, 17 MiB file transfer, cancellation, file
preservation and the new worker-credit transition. The test runtime's 134
regular files were compared byte-for-byte with the official LÖVE 11.5 macOS
archive (SHA-256
`6795bb3a1656af6a2fdfe741e150787b481886d3a280327a261a3fdded586913`).

Private receipt: `native-download-retirement-1793245616890031000/receipt.json`.
The managed ephemeral fixture was cleaned after the successful process exit.
This is a transport-test correction, not evidence that every remote sprite
package, selected actor, GPU backend or packaged release has been accepted.
