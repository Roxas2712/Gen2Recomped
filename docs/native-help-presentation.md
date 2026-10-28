# Native cartridge Help presentation

FR/LG imports now publish verified question/answer references, context lists,
topic order/visibility, original nine-tile decorations and keypad artwork in
`constants.gen3Help`. The structured text catalog remains the only text
decoder and translation authority. Other editions receive no invented Help
resource. Both the resource marker and structured-text revision invalidate
stale GBA imports; Gen2 markers keep their existing behavior.

`src.ui.Gen3HelpMenu` is a real native stack modal. Its list controller is
the existing `ListMenu`; answers retain original extended glyph cells,
keypad icons, placeholders and explicit text positions. Closing, owner
shutdown and dataset/save replacement retire only the owned modal and its
images, including under an unrelated covering screen. Images are created
once per open modal and released on exit or failed construction.

`src.ui.game3.help_system` observes that modal and lends its draw body to a
zero-argument source wrapper during the actual native draw only. Repeated
base calls share one paint. Outside-phase queries cannot advance input or
paint another frame. It does not load a second runtime or retain ROM readers.

Progress filtering reads the real native flag keys, current item registry and
unique caught Kanto dex IDs. HM acquisition flags, map possession and the
post-Brock basic-term order do not mutate any save state.

This is a bounded presentation prerequisite, not complete retail Help:
callers currently supply an explicit native context (1..34). Automatic L/R
activation, first-use tutorial state,
audio ducking and every native context transition are still unqualified.
No global button interception or gameplay flag writes are introduced before
those owners are integrated. Full map battles, terrariums, OS-window output
and interactive frame rate require separate visual/runtime acceptance.

Metadata and numeric interface facts were checked against the pinned primary
pret/pokefirered source at `ce6406d8c2eaf46d543c8a2606de0c3cb1951982`
(`help_system.c`, `help_system_util.c`, `text.c`, `charmap.txt`) and actual
verified FR/LG cartridges. No cartridge prose/pixels or private runtime are
published. Existing address-profile provenance and third-party rights remain.
