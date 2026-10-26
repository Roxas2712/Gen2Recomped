package.path = "./?.lua;./?/init.lua;" .. package.path
-- External unchanged-package consumer; hardware and persistence are doubles.
local T = require("tests.modkit")
local source = assert(arg[1])
local assets = assert(arg[2])
local combined = arg[3] == "combined"
local roots = { BATTLE_ART_VOXEL_FORK = source .. "/battleart" }
if combined then
  roots.LEGENDARY_INTERIOR_OVERHAUL = source .. "/interiors"
end
local names = {}
for name in pairs(roots) do
  names[#names + 1] = name
end
table.sort(names)
local mem = {}
local originalOpen = io.open
io.open = function(path, mode, ...)
  assert(mode == nil or mode == "r" or mode == "rb", "external consumer forbids disk writes")
  if type(path) == "string" and path:sub(1, 17) == "assets/generated/" then
    path = assets .. "/" .. path:sub(18)
  end
  if type(path) == "string" then
    for name, root in pairs(roots) do
      local prefix = "mods/" .. name .. "/"
      if path:sub(1, #prefix) == prefix then
        path = root .. "/" .. path:sub(#prefix + 1)
        break
      end
    end
  end
  return originalOpen(path, mode, ...)
end
local function resolve(path)
  for name, root in pairs(roots) do
    local prefix = "mods/" .. name
    if path == prefix then
      return root
    end
    if path:sub(1, #prefix + 1) == prefix .. "/" then
      assert(not path:find("..", 1, true), "mod path traversal")
      return root .. path:sub(#prefix + 1)
    end
  end
end
local fs = {}
function fs.read(path)
  local disk = resolve(path)
  if not disk then
    return mem[path]
  end
  local f = originalOpen(disk, "rb")
  if not f then
    return nil
  end
  local body = f:read("*a")
  f:close()
  return body
end
function fs.write(path, body)
  assert(not resolve(path), "unchanged packages are read-only")
  mem[path] = body
  return true
end
function fs.getInfo(path)
  if path == "mods" then
    return { type = "directory" }
  end
  local disk = resolve(path)
  if disk then
    if T.fs.isDir(disk) then
      return { type = "directory" }
    end
    local f = originalOpen(disk, "rb")
    if not f then
      return nil
    end
    f:close()
    return { type = "file" }
  end
  if mem[path] then
    return { type = "file" }
  end
end
function fs.getDirectoryItems(path)
  if path == "mods" then
    return names
  end
  local disk = resolve(path)
  return disk and T.fs.listDir(disk) or {}
end
function fs.load(path)
  local body = fs.read(path)
  if not body then
    return nil, "missing: " .. path
  end
  return (loadstring or load)(body, "@" .. path)
end
love.filesystem.read, love.filesystem.write = fs.read, fs.write
love.filesystem.getInfo, love.filesystem.getDirectoryItems, love.filesystem.load =
  fs.getInfo, fs.getDirectoryItems, fs.load
-- Keep other filesystem operations inside the same in-memory hardware model.
love.filesystem.append = function(path, body)
  return fs.write(path, (mem[path] or "") .. body)
end
love.filesystem.remove = function(path)
  assert(not resolve(path))
  mem[path] = nil
  return true
end
love.filesystem.getSaveDirectory = function()
  return "/virtual-consumer-save"
end
local hardwareStats
if arg[4] and arg[4] ~= "" then
  hardwareStats = dofile(assert(arg[5]))(arg[4])
end
local Version = require("src.core.GameVersion")
Version.set("red")
local Data = require("src.core.Data")
Data:load()
require("src.render.Font").load(Data)
require("src.core.Strings").load(Data)
require("src.ui.Theme").load(Data)
local Game = require("src.core.Game")
Game.data = Data
Game.input = require("src.core.Input")
Game.input:init()
Game.stack = require("src.core.StateStack")
Game.stack:init()
Game.save =
  require("src.core.SaveData").newGame({ version = "red", startMap = "PALLET_TOWN", startX = 5, startY = 6 })
Game.renderer = {
  worldViewSize = function()
    return 160, 144
  end,
}
local paths = {}
for _, name in ipairs(names) do
  paths[#paths + 1] = "mods/" .. name
end
local run = T.sdk.loadMods(paths, { data = Data, fs = fs, dev = true })
Game.mods = run.loader
for _, err in ipairs(run.errors) do
  print("CONSUMER_LOADER_ERROR " .. tostring(err))
end
T.eq(#run.errors, 0, "unchanged published packages load without errors")
local exported = run.loader.exports.BATTLE_ART_VOXEL_FORK
T.check(type(exported) == "table", "Battle Art entry executes and exports its public provider")
if not exported then
  run.release()
  T.finish("Battle Art unchanged native consumer")
  return
end
T.eq(exported.version, "1.11.2", "published host version is exactly the pinned release")
T.check(
  exported.battleStage and exported.battlePresentation and exported.voxel_companion,
  "unchanged host exports the actual presentation providers"
)
if combined then
  T.check(run.loader.exports.LEGENDARY_INTERIOR_OVERHAUL, "unchanged Legendary Interiors actually executes")
end
local V = assert(exported.lib)
local companion = assert(V.companion)
local Runtime = require("src.mods.Runtime")
local function frameHooks()
  local n = 0
  for _, entry in ipairs(Runtime.hooks.chains["core.update"] or {}) do
    if entry.owner == "BATTLE_ART_VOXEL_FORK" then
      n = n + 1
    end
  end
  return n
end
T.eq(companion:status().state, "running", "actual companion dispatcher starts on mods.loaded")
local before = frameHooks()
T.check(before > 0, "actual companion owns a frame wrapper before quit")
local PH = require("src.core.PlatformHooks")
if type(PH.quitToLauncher) ~= "function" then
  T.check(false, "native quit decision must dispatch the unchanged cleanup hook")
  run.release()
  T.finish("Battle Art unchanged quit consumer")
  return
end
local decisions = 0
local function vanilla()
  decisions = decisions + 1
  return false
end
T.eq(PH.quitToLauncher(vanilla), false, "actual unchanged quit cleanup forwards native exit")
T.eq(decisions, 1, "actual package calls downstream decision exactly once")
T.eq(companion:status().state, "disposed", "actual unchanged companion dispatcher is disposed")
local after = frameHooks()
T.check(after < before, "actual unchanged package retires its frame wrappers")
T.eq(PH.quitToLauncher(vanilla), false, "repeat decision retains exit and cleanup remains idempotent")
T.eq(decisions, 2, "repeat quit forwards once")
T.eq(frameHooks(), after, "repeat cleanup does not remove another wrapper")
T.eq(#run.errors, 0, "actual package quit adds no mod errors")
print(
  "BATTLEART_QUIT_RESULT "
    .. require("src.link.Json").encode({
      combined = combined,
      started = true,
      disposed = companion:status().state == "disposed",
      removedFrameHooks = before - frameHooks(),
      decisions = decisions,
      errors = #run.errors,
    })
)
run.release()
T.finish("Battle Art unchanged quit consumer")
