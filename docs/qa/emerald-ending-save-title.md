# Emerald League save, title and CONTINUE

Emerald's native ceremony now saves through the authoritative atomic host
writer after its original saving message is drawn. An explicit successful
write permits the ceremony to proceed. Refusal or exception preserves the
old disk bytes, holds the ceremony on its save phase and renders Emerald's
short original Save failed label. Acknowledgement retries through the same
writer; the save fanfare only plays after success.

The save retains Emerald's original CHAMPION_SAVEWARP bit 7. On CONTINUE the
host consumes that bit once and chooses the matching player's bedroom from
the ROM-derived indoor heal locations. It preserves unrelated bits and
party IDs. Older Emerald champion saves also use their correct gender's
room; datasets without that metadata retain the existing load fallback.
RS and other editions retain their existing return flows.

After native THE END the host cancels the exact suspended League script
and returns to Emerald's native title. The existing host main menu and its
CONTINUE preview still require their ordinary input confirmations. The old
League callback cannot run behind the title, add another induction or
change the team. Direct presentation-only Hall callers do not autosave.
`emerald-ending-save-v1` requires imports with the original failure label.

The focused suites pass 568 assertions: 143 Emerald write/rollback/bit/home
checks, 60 Emerald Hall readiness, 287 existing RS ending-save checks and
78 RS Hall readiness checks. Six native gender encodings, missing metadata,
old champion flags, one-shot application, unrelated bits and non-successful
writer results are covered.

Fresh full native validation passes at
`dcfff0ee5463f241cead22a8edd34b5028f5def4`. The runtime is unchanged from
`42f41296854411550be16d6eea2908afb777c6c7`; the later commit corrects only
the driver's input through Emerald's existing CONTINUE preview. The prepared
six-member female fixture verifies the actual GameClear special, two failed
writes and one successful write, one save fanfare, full native Hall/confetti,
all 57 credit pages/five scenes/71 slides, THE END music, title, ordinary
CONTINUE confirmations and correct bedroom. Twenty-two final-renderer
captures pass, including failure messages and home. Draw-time save/RNG,
durable party, single induction/stat and unchanged disk bytes after load
are checked. This does not claim an ordinary Emerald story playthrough or
native parity for its existing host main menu.
