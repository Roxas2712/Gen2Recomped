# Native effect callback context

`src.core.game3.battle.effect_ctx.current()` observes the actual native
primary, custom-perform or damaging callback scope. The native effect
registry supplies the original callback/context and executes it once.
Nested native calls restore the parent's observation and preserve all
return values. Errors remove the scope before propagating.

The observation supplies live typed user/target views and an adapter whose
`foeOf` resolves a real opposite-side battler, including four-slot doubles
and an empty opposite flank. A self-targeting move does not turn its team
message into an own-team reference. `moveId` is the cartridge index;
`move` returns detached primitive fields of the current native move record.
`opts.phase` describes the native callback category. Queries consume no
random values; an explicit active `rng` call uses the same native RNG.

The descriptor validates its original edition/data/save/stack/loader and
registry cohort. Outside that native callback, user/target observations
are absent and a retained RNG handle rejects use. Scope cleanup clears
native references even when a client retains its descriptor or adapter.

This observes the existing executor instead of importing another engine's
effect stack/pool. Native callbacks provide the scopes. Default unloaded
and non-GBA paths execute their original callbacks without a source context.
The public text consumer and battle/session primitives require the separately
offered native presentation stack. Complete battle text/effect coverage,
map/terrarium visuals and interactive performance remain separate work.
