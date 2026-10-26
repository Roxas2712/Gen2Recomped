# Frame pacing qualification

The foreground HIGH tier may poll during the final 1.5 ms of a software-paced frame; lower tiers and battery keep sleeping. An unfocused window may use a 20 fps presentation cap without raising a lower configured cap. Existing FrameCap rollback fields remain available.

Qualification repairs: add independent `Performance.framePacingSpin` and `backgroundPacing` environment switches; keep LOW/battery spin disabled even when unrelated extra caps are disabled; prevent intentional background pacing from driving PREFER FPS down. The fake scheduler's background check now permits its declared sleep overshoot, rather than expecting a polling deadline from a sleeping path.

All 16 targeted scheduler assertions and 131 stable-source runs passed, including all 53 native suites, every switch disabled individually, all-on/all-off, gallery/hooks, pinned API3 and 17 unchanged external fixtures. See `frame-pacing.json`. This is deterministic scheduler coverage; actual panel jitter, CPU use and energy remain unmeasured until the integrated baseline.
