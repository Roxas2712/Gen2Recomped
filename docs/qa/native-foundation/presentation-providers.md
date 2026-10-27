# Native presentation providers

Contributions by Roxas2712 — https://github.com/Roxas2712.
See LICENSE-ROXAS2712.md for the contribution terms and specific integration
permission for Cedric / UNDERdecoded. Existing notices and rights remain intact.

`src.ui.game3.presentation` and the native compositor share one
`NativePresentation` owner. API version 1 supports provider registration,
enablement, drawing/notifications, widgets, deferred layers, window completion
and health observations. Registration records the calling mod owner independently
of its provider ID, so ordinary mod cleanup retires both. Replaced registrations
have distinct disposer identities.

The native Game frame admits the current source game view. Its data, save, loader,
edition, stack identity and entire state sequence must remain current until each
paint. A retired view also invalidates the frame. The service owns no simulation,
input queue, save format, imported image or extra rendering loop.

Native modal groups offer `ui_stack` layers without moving world or battle scene
owners into the UI pass. The compositor flushes them on its current window target
before the native battle transition, veil and final output. The existing explicit
compose-hook takeover flushes after that hook returns. A provider's `present`
callback controls its own window layout; fallback uses the native UI surface and
the compositor's fitting policy. It keeps capture/postprocess targets bound.

Widget and deferred native painters are once-only leases, including their return
tuples. Provider failure or mid-frame disable/removal returns admitted work to the
native fallback. A swallowed native error still fails the frame. Graphics state,
canvas, scissor, leaked pushes and callback ownership are fenced. Finished leases
release their native closure and frame references; nested layers during flush
paint inline. Limits are 64 registered providers and 128 queued layers per frame;
additional layers paint immediately. Session shutdown drops stale callbacks.

Only `nativeUiStack` and `windowLayers` are advertised. PC, bag, naming, summary,
battle paper devices and other themed families need their actual native call
sites and context projections before their feature flags can become true. This
foundation deliberately does not enable an experimental theme or claim those
families are complete. Other generations keep their existing compositor.

Frozen fork `f4f6a295a7` passes 48 CPU groups, including 538 provider checks.
Owned-output run `70560fd6d9` passes 1,682 checks across 240 frames on each of
Metal and OpenGL: five editions, logical widths 240/320, target DPI 1/2, two
window sizes, fallback/error cases and nested painting. Unchanged-mod run
`1eb7007342-firered` completes a real trainer, five view changes and native
move-swap/restore/cancel input with exit 0 and idle cleanup. The older-public
composition `1dbf66c04e` independently passes 31 CPU groups with the same 538
provider checks. Its separate owned-output run `461c91ab60` also passes 1,682
checks across 240 frames on each backend.

Earlier trainer benchmark `58ae54db42-firered`, source `1830bd24b6`, records
240 readback-free intervals per view averaging about 60 FPS in paper, native
and terrarium views. Its driver finished, but the wrapper failed in a later
macOS screen-lock diagnostic timeout. A separate recovery receipt retains
that failure and the source association; it does not relabel the run accepted.
The diagnostic starter now records that optional timeout rather than discarding
native completion metadata.

These checks establish bounded frame and integration behavior, not complete
family, full-game, all-edition visual, OS-window or sustained performance parity.
QA uses fresh owned profiles, preserves player saves and retains at least 20 GiB
free.
