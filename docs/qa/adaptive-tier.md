# PREFER FPS qualification

PREFER FPS starts at the AUTO tier and steps down after two bad windows. It climbs after sustained comfort up to the original ceiling, with a cooldown after each change. Stored presentation choices remain unchanged.

Qualification repairs: observe only frames that were presented; discard decision samples when entering or leaving the option, so a later session cannot inherit old misses. The deterministic tier suite covers those cases in addition to downward steps, cooldown, upward recovery, AUTO ceiling and fixed-tier behavior.

All 125 stable-source runs passed: tier checks, all 53 native suites, the complete performance switch matrix, gallery/hooks, API3 against pinned 535a5ec, and 17 unchanged external fixtures. See `adaptive-tier.json`. Actual heavy-map tier transitions, handheld performance and energy use are not measured in this component qualification.
