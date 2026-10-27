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

`endMountedSession(version)` retires the native loader (mod hooks, buses,
viewport, jobs and compatibility resource holders), unmounts the version's read
path, and evicts generated data. It leaves process workers running.
`endEditorSession({app=app, version=version})` unloads the editor, evicts its
flat/path-style modules, and ends the mounted session. Editor-unload failure
cannot skip this cleanup. The native Close callback uses the same owner.

These implement Gen1 lifecycle entry points against the fork's existing native
owners. They do not add a second game controller or alias a Gen1-only game reset
implementation. Asset invalidation keeps resources held by live native views
valid; it is not an assertion that every GPU resource has been synchronously
freed.

ROM-free coverage includes real loader registration, loader retirement,
callback/service failure isolation, unused services, accepted native exit,
launcher return and editor quit veto. It does not establish full client, GPU
or release-package acceptance.
