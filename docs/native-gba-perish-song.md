# Native GBA Perish Song lifecycle

Perish Song now uses the observed Gen1 GBA lifecycle in FireRed, LeafGreen,
Ruby, Sapphire and Emerald. Its USER target byte starts one whole-field
effect: every present battler without Soundproof receives the counter, an
existing counter is retained, and a substitute does not shield the recipient.

The residual owner prints the current count and then decrements it. Three
completed residuals leave a living battler with count zero; the following
residual causes the faint. That zero decision is available to native trainer
controllers and survives public checkpoint capture and reconstruction.
Ordinary switching removes the counter from the incoming battler.

The builtin record is adapted before mods capture it, so public delegation
uses the same complete implementation. An authored override remains in
control. Shared legacy records and older generations retain their existing
behavior. Native text labels and source catalog fallbacks remain available.

Residual faints enqueue their removal and EXP work. GBA doubles now perform
an additional replacement sweep after those queued removals, so the next
menu has its actual reserves. The existing synchronous replacement sweep
and `battle.turn_ended` timing are retained.

Native GBA battle revision **21** distinguishes these rules from revision 20.
The fixture fingerprint is `7aae08076971bcc3`; older-generation digests retain
`e33d251961f2a41d`. Peers with older native rules cannot negotiate a full
lockstep battle. The party codec is unchanged. This supersedes the revision
20 runtime guard documented for the earlier native BGM component.

## Validation and reproduction

```sh
python3 tools/gen3_mist_contract.py --effect perish \
  --reference-root /path/to/Gen1Recomp \
  --lua /path/to/luajit \
  --output /path/to/new/qa/output
```

The shared contract compares five effect profiles in each of four field
modes across five editions: 100 typed action/residual observations from 40
native workers. The reference checkout stays clean and read-only. Local QA
uses `tools/qa_storage.py`; `--qa-tools-root` can select the primary checkout's
QA helper.

The standard quick tier additionally exercises public native/delegated/
authored effects, real menu rounds through the zero window, ordinary escape
and expiry replacements, byte-identical cold checkpoint continuations, native
loopback turn hashes and old-peer admission. The loopback cases cover both
ordinary and Soundproof recipients; they also verify that peer choices do
not invoke the trainer AI continuation.

This component does not implement autonomous trainer switch policy or its
landed-move history producers. The shared GBA mod capability remains pending
those and the other controller/gameplay qualifications; it is not enabled by
this change.
