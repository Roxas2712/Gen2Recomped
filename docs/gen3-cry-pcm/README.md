# Compressed Gen 3 cry recordings

Retail FireRed/LeafGreen/Emerald/Ruby/Sapphire each contain 388 compressed
GFDPCM recordings (WaveData type 1, cry instrument type 0x20). The existing
M4A cry renderer treated their encoded bytes as signed PCM and continued
past each compressed blob into neighbouring ROM data. This is a data-format
bug, independent of volume settings or mods.

`Gen3CryPCM` follows the cartridge decoder's 33-byte/64-sample blocks: initial
sample, low nibble, then high/low pairs, independent block seeds and byte-wrap
stores. It clips the decoded output to the declared logical sample count and
rejects truncated recognized data. Uncompressed, chip, file and unfamiliar
custom cry paths retain their existing renderer. Sample rate, default pitch,
output duration, native gain, stereo channels, Sound cache/Source ownership,
mute, music ducking and audio-session lifecycle are preserved.

Reconstruction uses linear interpolation rather than repeated sample steps.
This matches the DirectSound music path used by the original OASC runtime;
it reduces upsampling images without changing the recording's pitch or speed.
This is a presentation choice, not a claim of bit-exact GBA analogue output.
The native cache does not need re-importing: compressed data is already present.

## Reproduction

ROM-free boundaries:

```
luajit tests/engine/gen3_cry_pcm.lua
```

Independent owned-cartridge oracle:

```
python3 tools/check_gen3_cries.py --rom <owned-US-ROM> --luajit <luajit>
```

The Python reader independently finds and validates both full mirrored tables,
decodes every byte using ARM/STRB semantics, and supplies a binary oracle to
the actual Lua module. All 388 recordings per edition match. Seven native
M4A renderer cases per cartridge additionally compare all resampled values;
these use a headless SoundData boundary, not an actual audio device. Optional
`--original-sample <private-original-runtime-module>` compares its decoded
recordings as well. No ROM, oracle PCM, extracted artwork/audio or private
engine code is included in this contribution. Per-record receipts are adjacent.

The original OASC decoder saturates at theoretical overflow boundaries.
The full logical retail samples in these five cartridges do not cross them:
zero changed sample bytes there. A preliminary 19-record count included block
padding beyond logical sample ends and is explicitly superseded. Synthetic
wrap/truncation/block-reset controls cover that boundary. This source-edge
correction must not be presented as the cause of bad retail OASC playback.

Actual ordinary API-2 OASC ZIP tests on the unchanged 0.8.45 and separate
edition-support source are recorded in the private port repository; they are
separate from this fork's headless checks. This contribution does not certify
full fork gameplay or physical iOS, change existing source-volume choices,
implement the original OASC's complete cry-mode/chorus/pan policy, or fix cold
M4A attack-effect synthesis. Those remain separate contracts.

Contributions by **Roxas2712**. Existing upstream/Gen1Recomp rights and credits
remain; the contributor's own additions are offered under
[LICENSE-ROXAS2712.md](../../LICENSE-ROXAS2712.md). No whole-file authorship claim.
