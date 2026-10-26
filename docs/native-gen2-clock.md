# Shared native Gen2 RTC

The Pokégear previously displayed elapsed play time while world palettes,
object time masks and script variables used the host clock. The native
`Gen2Clock` now provides the same saved RTC-base reads to these consumers,
the native happiness evolution gate and observational encounter summaries.
The existing `src.core.gen2.Clock` name resolves to this native module.
`world.hour()`, `world.minute()` and `world.weekday()` read that same save.

`setTime(save, hour, minute)` stores `rtc.startMinute`, an offset from the
host RTC, rather than a frozen hour. `setWeekday` stores `rtc.startDay` and
keeps the older native `g2DayOffset` field synchronized. Old saves without
an RTC base retain their host-hour and existing weekday-offset behavior.
Read calls never create clock data. Invalid/non-finite writes are rejected.
The normal native save codec preserves the offsets; play time is separate.

World palettes, object-load period bits and `VAR_HOUR` share the saved hour;
the normal object-load freeze still applies. An explicit palette-query hour
retains precedence. The existing `world.tod` hook remains a presentation
override and does not rewrite the saved RTC. A raw scene-clock query uses
the current native save, independently of a room's forced palette.
AUTO neighbours share the effective clock presentation while the entered
map also follows AUTO. From a pinned room/cave, an AUTO neighbour instead
uses the saved RTC; that room's unused world-TOD hook is not a neighbour
palette override. This keeps explicit native/external hour queries aligned.

`clock.day_changed` is produced by actual weekday reads, including the live
world clock poll. It reports `day`, `previous` and `reason` (`rollover` or
`set`). A save's first observation is silent. Observations are per save,
reentrant-safe, subscription-aware and retired on mod/edition reload.
Native API 1/2 and unified API 2/3 use the normal event dispatch boundaries;
other generations do not advertise this native GSC seam.

The clock card, native script readers, evolution time gate and world methods
are exercised directly in synthetic engine tests, including minute wrap,
weekly rollover, save roundtrip, RTC-versus-play-time display, both callback
paths and actual mod loading. Graphics IO alone is replaced for the clock
card. These checks do not establish a complete original-story clock-setting
sequence, DST, battery-backed SRAM RTC conversion, all daily scheduling or
fresh GPU acceptance for this change. Existing daily date keys still use
host calendar dates; lottery weekday selection now shares the saved weekday.

The public contract is compared with the read-only Gen1Recomp reference;
the implementation is native fork code. No VASC implementation, private
assets, game text or ROM-derived clock data is included.
