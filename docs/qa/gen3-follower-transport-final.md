# Follower merge qualification and transport fixture

The Gen3 follower fix remains isolated from the palette-index series. Qualification against the integrated main/shade branch passed 122 runs: follower ownership assertions, all native suites, switch matrix, pinned-reference API3 and external fixtures.

The Windows CI failure timed cold file-worker creation against a 100ms wall-clock limit. The transport fixture now holds the real worker before its HTTP call and proves that download returns and main can pump while that gate is closed. The existing per-request deadlines, bounded polling assertions, binary publication and cancellation checks remain. The whole-host watchdog is 120 seconds to accommodate CI scheduling; request deadlines remain unchanged.

Actual macOS LOVE 11.5 TLS run: 1,832 assertions and 735 pump ticks passed, including certificate refusal, literal POST bytes, JSON envelope and redirect refusal. No runtime download implementation changed, and no cold-start latency or FPS improvement is claimed.
