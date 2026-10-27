-- Process lifetime is longer than a mounted game or mod loader. A download
-- worker may still need joining after its owning mod has been unloaded.
-- Keep this registry in the engine, and call it only after the host accepts
-- a real process exit. Requiring it must not start audio or worker services.
local SessionLifecycle = {}
local processShutdowns = {}

function SessionLifecycle.registerProcessShutdown(fn)
  assert(type(fn) == "function", "process shutdown hook must be a function")
  processShutdowns[#processShutdowns + 1] = fn
end

-- These services already belonged to the native love.quit path. Never require
-- an unused service just to stop it, and let one broken callback/worker leave
-- the remaining shutdowns reachable. Game/launcher transitions do not join
-- these workers: the next game still shares this process.
local services = {
  "src.core.ChipAudio",
  "src.update.Check",
  "src.render.ShaderBrowser",
  "src.translation.Service",
  "src.net.Fetch",
}

function SessionLifecycle.endProcess()
  local count = #processShutdowns
  for i = 1, count do pcall(processShutdowns[i]) end
  for _, name in ipairs(services) do
    local service = package.loaded[name]
    if service and type(service.shutdown) == "function" then
      pcall(service.shutdown)
    end
  end
end

return SessionLifecycle
