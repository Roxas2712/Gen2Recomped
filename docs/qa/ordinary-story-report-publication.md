# Complete ordinary-input story reports

Contributions by Roxas2712. See `LICENSE-ROXAS2712.md`.

The Hoenn ordinary-input driver previously JSON-encoded every recorded command
again after each input. Long playthrough segments repeatedly traversed thousands
of already captured world, party and menu fields. The cost grew with the history.

`tests/drivers/story_report_writer.lua` encodes only new command rows and current
report metadata. It copies the committed JSON prefix as bytes to a temporary file,
appends new rows and the current metadata, then atomically replaces `result.json`.
The published file remains a complete JSON object with the same `commands` array;
existing checkpoint qualification and the small published-input receipt retain
their existing contracts. No game update, battle calculation or input changes.

Committed rows are immutable. Encoder or I/O failure leaves the previous complete
report in place and does not advance the writer's committed position. Retrying
therefore appends each new row once. A fresh writer refuses an existing report,
and sequence gaps or truncation are rejected. This reduces encoding work, while
the complete atomic file replacement still copies the growing prefix each time.

Focused regression: with an owned temporary output directory, run
`STORY_WRITER_TEST_DIR="$RUNNER_TEMP" luajit tests/engine/story_report_writer.lua`.
It covers readers during publication, escaped and UTF-8 text, immutable history,
metadata updates, failed encoding and retry, sequence continuity and bounded
encoding work. Existing receipt and checkpoint tests remain applicable. Local
native qualification must still use an ordinary normal SAVE and fresh CONTINUE;
prepared fixtures do not count as campaign progress.

A local CPU comparison used five successive appends at the end of an actual
690-command Emerald trace (18,424,871 final JSON bytes). Re-encoding took
5.628248 CPU seconds; the incremental writer took 0.138200 seconds, about 40.7
times faster for this publication work. The decoded complete report values
matched. This is a small local harness measurement, not a game frame-rate or
whole-playthrough speed claim.
