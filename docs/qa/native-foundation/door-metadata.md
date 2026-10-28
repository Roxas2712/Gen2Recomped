# Native door descriptor queries

Third-person world construction requested the cartridge door metadata query, which was missing and disabled the presentation renderer. The importer now reads the real descriptor tables for authenticated FireRed, LeafGreen, Emerald, Ruby and Sapphire cartridges, retaining metatile IDs, sound kind, size, tile location and palette slots. The edition-specific generated-cache marker changes; save formats do not change.

The query resolves canonical or native map IDs through the admitted native world, reads the current metatile and semantic behavior, and returns detached descriptor and geometry metadata. Non-door cells, padded/out-of-bounds coordinates, foreign identities, missing imports and retired worlds do not create a door. The compatibility manifest is a detached per-cohort snapshot. Native map cells, warps, save data, simulation clocks and the existing Petalburg slide remain authoritative.

Validation: 66 ROM-free binary-reader assertions, 95 native query assertions, 75 existing slide-observation assertions and the native map/weather/cache regressions pass. All 185 descriptors from the five authenticated cartridges were read successfully (32/32/53/34/34). The frozen current-main composition passes 250 CPU groups. An independent older public composition passes 78 groups using its original native controllers and the existing map/session foundations; only the owned import insertions and detached door module were added. Earlier differing import prerequisites were retained. ROM assets and private source are not published.

This supplies descriptors and read-side queries. General door animation/task/sound coordination, broader edition/scene coverage and stable field FPS remain separate qualifications. The unchanged-consumer rain and camera matrix is being checked independently; CPU checks are not visual acceptance.

Only disposable QA profiles were used. Private presentation files and player saves were not changed. Storage helpers enforced 20 GiB free, above the requested 8 GiB reserve.

Contributions by Roxas2712 — https://github.com/Roxas2712. Original additions are offered under LICENSE-ROXAS2712.md, including specific integration/distribution permission for Cedric / UNDERdecoded with visible credit. Existing upstream/third-party licences and rights remain intact.
