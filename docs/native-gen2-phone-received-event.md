# Native incoming phone notification

Gold, Silver and Crystal now emit `phone.call_received` after the actual
overworld controller queues an admitted incoming call. Both random calls and
queued special calls use this boundary. Rejected candidates, outgoing calls
and other generations do not emit it. The callback is an observation, not a
veto; returning false or editing its descriptor does not redirect the queued
receive program or change the saved caller.

The notification follows the read-only reference's PhoneRing.script boundary
at `535a5ec088c1ae1bf4d91dd3e35a56f64cf46d91`:
`call`, `contact`, `name`, `className`, `special` and `scriptKey`.
Names come from the actual native contact/trainer roster. The detached call
descriptor has incoming direction, native numeric contact ID and actual
script key; canonical trainer class/member metadata is included when known.
This engine retains native extracted script keys rather than inventing
unavailable symbol labels. Special notifications use the queued wrapper key,
which can differ from the contact's ordinary receive script.

The callback catalog advertises this event only for native Gen2. Native API1/2
and unified API2/3 share delivery; unified callback records keep their normal
detached observation semantics. Unsubscribe, entry rollback and teardown use
the existing event-owner journal.

487 focused synthetic checks run actual controller admission and queueScript, the real
incoming selector, Gen2ScriptVM and ScriptRunner in all three editions and
four API/content combinations. Only audio IO, RTC-facing time and RNG are
controlled. The controller's process-local Game binding is installed and
restored by the test; protected player instances are never used. Tests cover
random/special descriptors, actual queued program execution/completion,
observer mutations and false returns, rejected candidates, outgoing calls,
unsubscribe, rollback and other-generation isolation.

This does not reproduce the complete PhoneRing dialogue/choreography, add the
legacy Phone facade, establish Mom shopping-call production, or prove full
story/hardware acceptance. Those remain separate work.

Original contributions by Roxas2712; existing reference, upstream and
third-party rights and credits remain applicable. See NOTICE.md and
LICENSE-ROXAS2712.md.
