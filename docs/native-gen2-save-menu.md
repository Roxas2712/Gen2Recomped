# Native Gen2 save dialogue

Gen2 START now opens `Gen2SaveMenu`, an actual state over the native text
printer and save pipeline. The public `src.ui.gen2.SaveMenu` spelling names
this same owner. Screen registry overrides retain authority over the native
`Gen2SaveMenu` entry.

An existing active save slot requires a second overwrite answer. B/NO cannot
write. The timed saving message uses MID text cadence without held-button
acceleration; the write follows sixteen post-text logic frames. The saved
message follows another thirty-two frames and retains a thirty-frame tail,
waiting for its returned save sound with a bounded host failure escape.
Completion and writing are each guarded against duplicate calls.

The default operation calls `Game:writeSave`, retaining save-write vetoes,
live overworld capture, metadata/resume capture, mod notifications and the
existing safe serializer. Explicit alternate snapshots use `SaveData.save`;
an injected writer receives the selected snapshot. Failed or throwing writes
cannot produce a successful completion message. Slot detection uses the
same active-slot lookup as native saving; an indeterminate lookup asks for
overwrite confirmation. The panel counts native badge and owned-Dex records.

ROM-free integration tests exercise Gold/Silver/Crystal through actual stack,
text printer, START input, screen resolution and the native Game writer,
including refusal, overwrite, fixed timing, duplicate suppression, writer
failure and a real save-hook veto. Gen1 retains its existing dialogue path.
Real-cartridge save/reload, unchanged-mod presentation, exact reference text
raster/typewriter helper APIs and full save/link parity remain unverified.
This state does not change save-format or link-protocol numbers.

Original contributions by Roxas2712; existing upstream and third-party rights
and credits remain applicable. See NOTICE.md and LICENSE-ROXAS2712.md.
