-- Process lifetime is longer than a mounted game or mod loader. A download
-- worker may still need joining after its owning mod has been unloaded.
-- Keep this registry in the engine, and call it only after the host accepts
-- a real process exit. Requiring it must not start audio or worker services.
local SessionLifecycle = {}
local processShutdowns = {}

local function releaseAssets()
  local assets = package.loaded["src.render.Assets"]
  if assets and type(assets.releaseSession) == "function" then
    pcall(assets.releaseSession)
  end
end

function SessionLifecycle.registerProcessShutdown(fn)
  assert(type(fn) == "function", "process shutdown hook must be a function")
  processShutdowns[#processShutdowns + 1] = fn
end

-- A game can end while the launcher and its download/audio workers live on.
-- Native Game is a shared module identity: retire its owned states without
-- evicting that module or unmounting another cartridge here.
function SessionLifecycle.endGameSession(game)
  local function call(name, method, ...)
    local module = package.loaded[name]
    if module and type(module[method]) == "function" then pcall(module[method], ...) end
  end
  call("src.core.Music", "stop")
  call("src.core.Sound", "stop")
  call("src.core.Sound", "setRate", 1)
  call("src.core.ChipAudio", "stopMusic")
  if love and love.audio and love.audio.stop then pcall(love.audio.stop) end
  call("src.render.SecondScreen", "setEnabled", false)
  if not game then return end
  if type(game.reset) == "function" then
    pcall(game.reset, game)
  else
    local stack = game.stack
    if stack then
      local selected = {}
      for i, state in ipairs(stack.states or {}) do selected[i] = state end
      if type(stack.removeAll) == "function" then
        pcall(stack.removeAll, stack, selected)
      elseif type(stack.pop) == "function" then
        -- Bound work even if a mod's exit callback opens another state.
        for _ = 1, #selected do pcall(stack.pop, stack) end
      end
      if type(stack.clearWorld) == "function" then pcall(stack.clearWorld, stack) end
    end
  end
  game.overworld, game.world, game.phase = nil, nil, "boot"
end

-- Retire the native loader before changing the read path. It owns the mod
-- buses, wrapper journal, viewport, jobs and compatibility resource holders.
-- Using that owner also keeps process services alive for the next cartridge.
function SessionLifecycle.endMountedSession(version)
  -- Release while mod-owned caches still contain their resources: loader
  -- teardown invalidates them and restores their engine wrappers afterwards.
  releaseAssets()
  require("src.mods.Loader").teardown()
  if version then require("src.import.CacheFs").unmountVersion(version) end
  require("src.core.Data"):unloadGenerated()
end

local function flushEditorModules()
  local fs = love and love.filesystem
  for name in pairs(package.loaded) do
    if type(name) == "string" then
      local editorPath = name:find("save%-editor") ~= nil
      local flat = not name:find("[./]")
      local editorFile = flat and fs and fs.getInfo and (
        fs.getInfo("tools/save-editor/" .. name .. ".lua")
        or fs.getInfo("tools/save-editor/panels/" .. name .. ".lua"))
      if editorPath or editorFile then package.loaded[name] = nil end
    end
  end
end

function SessionLifecycle.endEditorSession(opts)
  opts = opts or {}
  if opts.app and opts.app.unload then pcall(opts.app.unload) end
  flushEditorModules()
  if opts.version then SessionLifecycle.endMountedSession(opts.version) end
end

-- These services already belonged to the native love.quit path. Never require
-- an unused service just to stop it, and let one broken callback/worker leave
-- the remaining shutdowns reachable. Game/launcher transitions do not join
-- these workers: the next game still shares this process.
local services = {
  "src.core.BuildWorker",
  "src.core.ChipAudio",
  "src.update.Check",
  "src.render.ShaderBrowser",
  "src.translation.Service",
  "src.net.Fetch",
}

function SessionLifecycle.endProcess()
  releaseAssets()
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
