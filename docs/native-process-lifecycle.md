# Process shutdown registration

`src.core.SessionLifecycle.registerProcessShutdown(fn)` retains a process-lifetime
callback without starting services or running the callback during registration.
Portable download workers can close and join at the accepted native `love.quit`
boundary, even after their mod loader has been retired. `endProcess()` invokes
callbacks in registration order and then stops already-loaded native services.
Each shutdown is isolated so one faulty worker cannot strand the rest.

An unsaved editor can veto exit. If the editor accepts exit, native process
cleanup continues; previously its `false` return also bypassed that cleanup.
Callbacks should tolerate repeated shutdown requests, like the native services.
This does not alias Gen1-specific mounted-game or editor reset implementations.

The focused ROM-free suites exercise real loader registration/retirement,
failure isolation, actual native quit callback routing, editor acceptance/veto
and existing audio/update worker shutdown. They do not establish whole-client,
GPU, platform package or full engine parity acceptance.
