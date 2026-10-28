# Native RS League save and title return

Ruby and Sapphire previously finished the ceremony without an automatic
League save and resumed the old script at home after THE END. The original
RS ending saves before presenting the party, resets after THE END and spends
its special return bit when CONTINUE loads the bedroom.

The native Hall of Fame now bridges its save request to the host atomic
writer when entered by GameClear. Its saving message must reach the final
renderer before IO. Both a false return and an exception preserve the prior
durable file, suppress the success sound and hold the ceremony on the ROM's
save-error text. Acknowledgement permits another explicit attempt. Only a
successful write permits the party presentation and subsequent credits.
Direct presentation-only callers retain their existing non-saving behavior.

`Gen3RsEndingSave` writes RS bit 0 and a versioned return marker using the
gender-specific bedroom already derived from ROM heal locations. It preserves
other bits and rolls its fields back on refusal. CONTINUE checks that marker
against the active ROM's bedroom before consuming it in RAM. Unknown markers,
older unmarked saves and other editions keep their existing behavior. It
never uses the opening truck as the post-League destination.

GameClear remains the single owner of induction counts and Champion ribbons.
The reference controller's numeric save/stats views remain private. After THE
END, a successfully saved RS ending retires its exact suspended script and
returns through the host title/CONTINUE path. The old host home/gift callback
continues to serve other editions; RS follows its original reset sequence.

## Verification

Runtime `0d414de17d8b97a8eff16410ee69d2a97aa7ed7c` implements the behavior.
Integrated source `ce893e7e5e5e4633d403d478312b7705ac182238` also contains
the current credits CI expectations and corrected test timing/identity checks.
Both prepared native fixtures pass with unchanged frozen inputs:

| Edition | Prepared player | Complete native acceptance |
| --- | --- | --- |
| Ruby | Girl | Three write attempts (false, exception, success), one success sound, six team members, confetti, player portrait, all 52 credit pages, five cycling scenes, 68 Pokémon slides, THE END, title, actual CONTINUE to the girl's ROM bedroom |
| Sapphire | Boy | Same complete sequence, actual CONTINUE to the boy's ROM bedroom |

Each run records 21 final-renderer captures and checks that drawing preserves
save bytes and gameplay RNG. Failed writes leave the existing disk snapshot
unchanged. The successful snapshot contains the induction exactly once;
CONTINUE preserves its party and does not rewrite that snapshot. The original
League script does not execute behind the title screen.

The focused CPU contracts pass 427 assertions: 287 save/refusal/retry/home
checks, 78 Hall of Fame readiness checks and 62 credits checks. All 35 contract
tool unit tests pass, including complete-report comparison and rejection of
unrelated drift. The final head adds this documentation only.

This is prepared ending-flow acceptance, not another ordinary full-story run.
The prior ordinary Sapphire completion predates this native presentation and
save flow. Full RS team-history storage/viewing, Emerald's native movie and
the remaining ordinary edition playthroughs remain separate work. No ROMs,
generated assets, private saves or captures are published.
