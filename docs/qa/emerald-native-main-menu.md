# Emerald common main menu

Emerald previously entered the generic host menu and required a second
CONTINUE confirmation after displaying its save preview. The native adapter
uses the exact original `rse/main_menu_rse.lua` from Gen1Recomp
`fb7b0366efcb85e703e9e6d5a8a24d01456a109b`. Individual provenance and the
reference's existing GPLv3/additional terms are retained.

The selected Emerald ROM supplies sixteen original labels, the already
imported full normal font, twenty user frames and native title palette.
Panels, dimming, gender inks, cursor clamping and fades belong to the
original controller. The active host save is read once on entry; CONTINUE
invokes its existing callback directly. The shared RS save-summary builder
accepts Emerald's own constants without changing its default RS behavior.
Pokédex visibility uses Emerald's flag; owned species are deduplicated under
the native regional/national gates.

NEW GAME, OPTION, title cancel and launcher EXIT keep their host callbacks.
Options return updates both the original scene's frame index and private
chrome. Custom mod rows, labels and callbacks retain the host presentation.
Mystery Gift/Events gameplay and its additional unlocked rows remain a
separate integration; this adapter covers the existing common host rows.
The host clock supplies RTC, and host save slots remain authoritative.

`emerald-native-main-menu-v1` invalidates only Emerald's old cache. Boot
readiness requires all sixteen labels in addition to movie/Hall resources.
No generated assets, cartridge text or player saves are included.

Four focused suites pass 202 assertions: original-symbol label extraction,
readiness composition, save-view gates, original geometry, frame return,
mod fallback, and existing movie/Hall resource contracts. Native acceptance
is recorded separately after running the final renderer fixture.
