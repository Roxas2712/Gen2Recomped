# Native Mirror Move received-history gates

This test-only branch extends `f9016f1c`; runtime files are unchanged. The
native, API-3 registered and Metronome-to-registered-Mirror matrices now include
a second incoming move that KOs the recipient, plus an opponent self-target.
The KO sequence ends without attempting to act with the fainted recipient.
Every previously captured state, event, held read, RNG draw and animation row
remains in comparison.

The expanded comparison executes **12 workers / 2,208 paired observations**
across FireRed and Emerald, all equal without timeouts or native VM diagnostics.
The actual-host regression adds **994 checks**. A KO preserves the recipient's
earlier successful received-move history; another actor's self-target cannot
overwrite it. The existing miss, immunity, protection, flags, callback mutation,
zero-PP, Pressure, different target, item and Substitute cases remain covered.

This qualification applies to the registered FireRed/Emerald profiles. A
separate exploratory Ruby/Sapphire run at `f9016f1c` executes the unchanged
reference but the feature-stack host rejects those unregistered versions.
Their separate support PRs must be integrated and tested before extending the
claim; the fixture does not invent version registration or substitute profiles.

The full runtime regression is tied to the byte-identical parent and remains
pending until its running process completes. Final combined-fork regression,
workflow coverage, source-bound QA receipt and publication remain subsequent
gates. No Gen1 files, upstream branch or normal game data are modified.
Raw expanded observations remain in `tmp/mirror-history-qa/`; the exploratory
profile reports remain in the workspace's `tmp/mirror-rs-profile-qa/`.
