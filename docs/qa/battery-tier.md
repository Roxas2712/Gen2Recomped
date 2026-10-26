# PREFER BATTERY qualification

The battery option resolves to LOW and overlays a 30 fps ceiling and reduced presentation caps. Existing LOW caps and persisted user choices remain unchanged.

Qualification repairs: `caps("battery")` now agrees with `applyOptions`; the private reused overlay follows later edits/removals in public LOW and BATTERY cap tables. Independent `lowTierBudget=0` rollback is explicitly covered instead of assuming extra caps are active in every matrix column.

All 125 stable-source qualification runs passed: 78 tier assertions, all 53 native suites, complete switch matrix, gallery/hooks, pinned API3 and 17 unchanged external fixtures. See `battery-tier.json`. The ten-minute LOW/battery energy comparison is not measured; no power-saving percentage is claimed.
