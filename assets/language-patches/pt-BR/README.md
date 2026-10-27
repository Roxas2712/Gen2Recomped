# Offline Brazilian Portuguese

These twelve BPS deltas reconstruct the exact existing Uni-Language PT-BR
language inputs from the player's supported US cartridges. They cover Red,
Blue, Yellow, Gold, Silver, Crystal (US 1.0 and 1.1), Ruby, Sapphire, FireRed,
LeafGreen and Emerald. No full cartridge image is shipped or downloaded.
The native engine reads the reconstructed image only as a translation source;
gameplay still uses the original imported US game and stable gameplay IDs.

`index.json` pins every patch's SHA-256 and size, US input SHA-1/MD5/size,
target SHA-1/MD5/size, import IDs and original translation provenance. The
engine verifies these identities plus BPS CRC32 checks before atomically
publishing the language source in the user's private optional-import store.
Source cartridges are read-only. Nothing is patched in place.

## Translation credits

The translations remain the work of their respective authors. This
integration and rebasing do not claim ownership or relicense their work.
Original notices are retained byte for byte in `notices/` when supplied.

| Editions | Original translation | Source |
| --- | --- | --- |
| Red / Blue | Hydhyro | [pokeazul-ptbr](https://github.com/hydhyro/pokeazul-ptbr), commit `98cec899e9add15d32dd7879f70ac4c9c42d9963` |
| Yellow | Hydhyro | [pokeamarelo-ptbr](https://github.com/hydhyro/pokeamarelo-ptbr), commit `fbb76167ed98a014380280668e518893104c3a81` |
| Gold / Silver | R_Lopes / Night_Shadown / Fserve | [Gold archive](https://www.zophar.net/translations/gameboy/brazilian-portuguese/pok-mon-gold-version.html), [Silver archive](https://traducoesroms.github.io/traducoes/game-boy-color/pokemon-silver-version_r_lopes-night_shadown-fserve/) |
| Crystal | R_Lopes; revision by R_Lopes / Fserve | [Crystal archive](https://www.zophar.net/translations/gameboy/brazilian-portuguese/pok-mon-crystal-version.html) |
| Ruby / Sapphire language source | OJ Abreu | [Original project](https://www.brgames.org/traducao/483/pokemon-ruby), [archived BPS](https://github.com/RetroAchievements/RAPatches/blob/main/GBA/Translation/Portuguese/790-PokemonRuby-Portuguese.zip) |
| FireRed / LeafGreen | Breno | [Author's release](https://www.romhacking.net.br/index.php?topic=3337.0) |
| Emerald | Zambrakas | [Archived BPS](https://github.com/RetroAchievements/RAPatches/blob/main/GBA/Translation/Portuguese/668-PokemonEmerald-Portuguese.zip) |

Roxas2712 authored the native integration, validation and delta builder.
Their code license does not extend to third-party translation or game data.
Upstream game/decompilation project credits and rights remain applicable.

## Reproduction using private inputs

1. Supply your own exact US cartridge images and construct the translated
   images using the pinned public translation sources/patches. Original
   patch SHA-256 values are in `index.json`. Ruby's archived BPS differs from
   the originally documented IPS but produces the same pinned target; its
   acquisition digest is recorded separately.
2. Gold/Silver apply their archived IPS to their US base. Crystal's original
   IPS uses US 1.1; reconstruct that base with `pret/pokecrystal` and verify
   SHA-1 `f2f52230b536214ef7c9924f483392993e226cfb`. FireRed/LeafGreen use
   the US 1.1 builds from `pret/pokefirered`; their respective SHA-1 values
   are `dd5945db9b930750cb39d00c84da8571feebf417` and
   `7862c67bdecbe21d1d69ce082ce34327e1c6ed5e`.
   Apply Breno's IPS patches to those bases. Pair the resulting target with
   the supported US 1.0 input when producing the distributable delta.
3. Build Hydhyro's pinned Red/Blue and Yellow sources using RGBDS 0.6.1.
   The Yellow snapshot ignores eight unchanged `.map` prerequisites. Restore
   them from the player's exact US Yellow image before building:

   | File under `gfx/` | Offset (hex) | Bytes |
   | --- | --- | --- |
   | `surfing_pikachu/unknown_f8946.map` | `f8946` | 200 |
   | `surfing_pikachu/unknown_f90bc.map` | `f90bc` | 240 |
   | `surfing_pikachu/unknown_f91ac.map` | `f91ac` | 15 |
   | `surfing_pikachu/unknown_f91bb.map` | `f91bb` | 13 |
   | `surfing_pikachu/unknown_f91c8.map` | `f91c8` | 72 |
   | `intro/unknown_f9b6e.map` | `f9b6e` | 120 |
   | `intro/unknown_f9be6.map` | `f9be6` | 12 |
   | `intro/unknown_f9bf2.map` | `f9bf2` | 4 |

4. Create a private JSON list with entries containing `game`, `base`,
   `target`, `expectedBaseSha1`, `expectedTargetSha1` and `provenance`.
   For Crystal 1.1 also set `baseImportId` to `crystal_en_rev1`. Pair
   Sapphire's own US base with the existing shared Ruby/PT target. Use the
   same provenance values as the index. Never commit the private input list
   or cartridge images.
5. Run `python3 tools/ptbr_patch_builder.py --inputs /private/inputs.json
   --output assets/language-patches/pt-BR`. The builder checks exact inputs
   and outputs only deltas and metadata. It never downloads cartridge images.
6. Run the guarded acceptance commands documented in
   `docs/native-rom-language-packs.md`, including US-only game and first-run
   UI tests. A matching target digest is mandatory; changing a digest to
   accommodate an incorrectly rebuilt translation is not a repair.

Only the development reproduction needs the original translation tooling
or alternate revisions. Players use the included deltas and their supported
US cartridge directly, including Sapphire and US-1.0 FireRed/LeafGreen.
