# GBA saved weather and rain statistics

Contributions by Roxas2712. See `LICENSE-ROXAS2712.md`.

The five GBA games translate a cycle id when committing saved weather.
Entering a changed saved rain 3 or thunderstorm 5 increments game statistic 40.
Heavy rain 13 and Emerald's abnormal mode 15 leave that statistic unchanged.
`doweather` activates the saved byte separately. Daily calendar updates change
the cycle stage; the next saved-weather commitment resolves that stage. Presentation updates and
draws leave the statistic unchanged.

The common saved-weather setter connects script commands, cycle specials,
map-header application and the native RSE coordinate provider. It preserves
existing counters and compares the meaning of old host saves containing an
unresolved cycle id, so normalization invents no historical rain visits.
The original 24-bit game-stat saturation remains with `Gen3GameStats`.

Prepared contracts cover every ordinary old/new weather pair in all five
editions, both four-day cycles, script/header ownership, deferred activation,
repeat requests, legacy cycle saves and clock/RNG independence. Their execution
and native qualification are recorded separately; source preparation alone
does not establish acceptance or ordinary campaign progress.

Original references:

- [Ruby/Sapphire saved-weather and rain counter](https://github.com/pret/pokeruby/blob/master/src/field_weather_effects.c).
- [Emerald saved-weather and rain counter](https://github.com/pret/pokeemerald/blob/master/src/field_weather_effect.c).
- [FireRed/LeafGreen saved-weather and rain counter](https://github.com/pret/pokefirered/blob/master/src/field_weather_util.c).
