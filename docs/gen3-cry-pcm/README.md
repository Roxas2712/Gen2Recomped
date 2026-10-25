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
custom cry paths retain their existing renderer. The compressed path now also reconstructs the cartridge cry modes and integer
channel/master gains. Native Sound retains Source ownership, mute, events and
audio-session lifecycle. Logical sample/envelope length bounds playback; the
former minimum 50 ms of padding is not added to these recordings.

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

## Modes and cold effect preparation

`Sound.playCry(data, species, options)` forwards `mode`, signed `pan`, 7-bit
`volume` and explicit `mono` to compressed cry reconstruction. It also accepts
`noDuck` and retains the existing `isolated` Source-clone option. FireRed,
LeafGreen and Emerald have 13 modes; Ruby/Sapphire have six different modes.
Emerald mode 6 uses volume 70, compared with FRLG's 90. Reverse, detuned chorus,
integer frame release, pitch, both channels and logical end bounds are rendered
before playback. Source cache identity includes the dataset, definition and PCM
options. Uncompressed/custom fallback gains are unchanged.

The track VOL -> TrkVolPitSet -> ChnVolSetAsm -> SoundMain integer chain uses
the existing music mixer's master volume of 12. Chorus voices are summed before
channel gain; clipping happens only at the output bus. This removes the earlier
premature flattening of chorus peaks, rather than reducing the user's SFX level.

`Gen3AudioPrep` prepares the actual M4A engine's non-looping effect PCM in
128-sample synthesis/upload steps. Game's real-frame update gives this queue a
2 ms cooperative budget; it does not advance a battle clock or execute a move.
The observed slice may overrun by one checkpoint. Current battlers/party move
sounds and imported animation variants are planned without playback. PCM is
bounded to 48 entries/16 MiB, with at most 64 pending jobs; Source ownership and
volume remain in Sound. Float64 chunk leases preserve exact samples, retain at
most 2 MiB of reusable scratch and isolate a synchronous cache miss from a
paused preparation job. Non-FFI hosts use the same bounded chunk contract.
Dataset/prefix, invalidation, session suspend/resume and
loader lifetime cancel stale work. A real sound request that beats preparation
still renders synchronously and on time. This does not remove every possible
cold miss or implement missing imported sound-task timelines.

ROM-free CI tests cover the decoder, all 51 edition/mode profiles, 7,680 integer
gain cases, the real Sound owner and bounded cold/warm preparation. Private
ordinary API2 ZIP tests use unchanged 0.8.45 or the separate edition-support
source; they are not a full gameplay acceptance of this API3 fork. Complete
battle cry-task routing, all move-sound timing, listening tests and physical iOS
remain open. No complete-port or stable-frame-rate claim is made.

Contributions by **Roxas2712**. Existing upstream/Gen1Recomp rights and credits
remain; the contributor's own additions are offered under
[LICENSE-ROXAS2712.md](../../LICENSE-ROXAS2712.md). No whole-file authorship claim.
