# VASC compatibility with the updated native preview

The current Team Omega **Voxel Ascendant 3.0.65-rc.4** package is detected by
the updated preview, but **does not run in Emerald or FireRed**. Both live
tests reproduce the author's Generation 1 restriction. An independent engine
version mismatch also exists. Enabling the mod loader fixed the preview's
blanket mod disable; it did not establish VASC compatibility.

No separate archive named VASC2 was supplied. This check uses the current
[Team Omega Gen2Recomp release](https://github.com/Ascedent-Omega/Voxel-Omega-Ascendant-----Gen2Recomp/releases/tag/v3.0.65-rc.4),
`Voxel-Ascendant-3.0.65-rc.4-Universal.zip`, downloaded in full and verified
against its release SHA256:
`d213aa64fe1f1453f8c0ac99af46629edc91558aaad5c32f5c2ff404c73f4d83`.
The complete unmodified archive contains 26,919 entries. Its root manifest
and entry point match the pinned tag's files byte for byte.

## Live results, 2026-10-24

The actual fused macOS application from the updated
[existing preview](https://github.com/Roxas2712/Gen2Recomped/releases/tag/native-preview-20261024.1)
was executed, with source commit `9939365655d0052ab812b859fe4301fc2e67cda6`
and payload SHA256
`ec5a636cf47d9edb83e93ea0e69c8610ade3ac6c0c7104263ff4243564b1e81c`.
The application passes strict code-sign verification. Packaged engine modules
were used; the external driver supplies test observations and teleport helpers.

| Game | Backend | Actual VASC loader result | Native scene checks |
| --- | --- | --- | --- |
| Emerald | OpenGL | Disabled: unsupported generation 3 | 44 current frames, one fresh OS window proof |
| FireRed | Metal | Disabled: unsupported generation 3 | 41 current frames, one fresh OS window proof |

Both processes confirm `POKEPORT_NO_MODS=0`, discovery of the real
`VOXEL_ASCENDANT` version, no forced-generation override, zero loaded mods,
zero loader errors and no VASC entry exports. Both log:

```text
VOXEL_ASCENDANT is for generation 1; this is generation 3, so it is not loaded
```

Frame checks verify the current rendered frame marker and scene colour
diversity. OS captures target only the window reported by each owned child
process and independently verify freshness and visible scene content. The
captures were also visually inspected: Emerald's Battle Dome and FireRed's
Pallet Town render in the native flat-world renderer. **These are compatibility
rejection tests, not successful VASC rendering or gameplay acceptance.**

## Two independent blockers

1. The [VASC manifest](https://github.com/Ascedent-Omega/Voxel-Omega-Ascendant-----Gen2Recomp/blob/v3.0.65-rc.4/manifest.json)
   declares `games: ["gen1"]` and `generations: [1]`. The preview correctly
   identifies both requested games as generation 3 and declines to load it.
   The [VASC dispatcher](https://github.com/Ascedent-Omega/Voxel-Omega-Ascendant-----Gen2Recomp/blob/v3.0.65-rc.4/main.lua)
   independently keeps the renderer inactive unless the generation is 1.
2. The same manifest requires engine
   `>=0.3.96 <0.4.0 || >=0.8.45 <0.9.0`. The preview reports **0.7.6**.
   Inside each actual packaged process, the engine's own `Semver.satisfies`
   returns false without a parse error, and `ModIndex.compatIssues` reports
   the version warning. The loader's generation check happens first, so this
   warning is recorded separately from the immediate generation rejection.

The manifest requests mod API **2**, matching the preview. There is no API
major mismatch. Passing a version range would not establish that every
required engine interface exists; these runs never execute VASC's entry code.
A version-number change or manifest edit alone cannot supply its missing
Gen3 renderer support.

## Scope and cleanup

Only the fork's task-owned preview application, profile, imported test data,
child processes and windows were used. The complete VASC installation was
removed after the tests, and the previously absent profile mods directory is
absent again. No version or generation gate was bypassed. No engine/mod code
or published release assets were changed for this investigation.

The Origami port stays paused; Gen1 and the player's instance remain untouched.
These are short macOS tests on Apple M3, not Windows hardware tests or VASC
First/Third Person acceptance. KASC was not installed; the root VASC package
is already excluded before its entry point or optional companions can load.

The [sanitized test receipt](qa/native-foundation/vasc-release-compatibility.json)
retains package hashes, both loader outcomes and frame/window checks without
ROM data, extracted graphics, private paths or process/window identifiers.
