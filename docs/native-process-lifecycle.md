# Process shutdown registration

Portable mods can require `src.core.SessionLifecycle` and register a function
with `registerProcessShutdown(fn)`. Registration retains the closure for the
process lifetime, including after a loader is retired. It does not run the
function or start engine services. `endProcess()` runs the registered functions
in registration order and then stops the native services that were already
loaded. Each call is protected so one failing worker cannot strand the rest.

The accepted `love.quit` path invokes this owner. An editor veto or a return to
the launcher does not shut down process workers. Existing service shutdowns
remain responsible for their own idempotence, as on the previous native exit
path. Callbacks should likewise tolerate a repeated shutdown request.

This implements the Gen1 process-tier contract against the native fork's
existing quit routing and services. Mounted-game/editor teardown still belongs
to the native loader and host; this change does not introduce aliases for
Gen1-only mount or game reset implementations.

ROM-free coverage includes real loader registration, loader retirement,
callback/service failure isolation, unused services, accepted native exit,
launcher return and editor quit veto. It does not establish full client, GPU
or release-package acceptance.
