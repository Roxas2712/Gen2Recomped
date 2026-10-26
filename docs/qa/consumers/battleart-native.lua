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
local Pipelines = require("src.render.Pipelines")
Pipelines.install(Data)
local world = require("src.world.OverworldController")
Game.stack:push(world, "PALLET_TOWN", 5, 6, "down")
T.eq(Game.stack:top(), world, "unchanged Battle Art permits actual imported overworld entry")
local V = assert(exported.lib)
local preset = V.require("LegendaryVisualsPreset")
local community = V.require("CommunityVisuals")
local mesher = V.require("ChunkMesher")
local geometryResults = {}
for _, mode in ipairs({ "off", "auto", "full" }) do
  preset.setting:setIndex(mode == "off" and 1 or mode == "auto" and 3 or 4, Game)
  preset.changed(preset.setting.key)
  T.eq(preset.mode(), mode, "native settings retain Legendary " .. mode)
  T.eq(
    community.buildings:get(),
    mode == "off" and "installed" or "reference",
    "Legendary " .. mode .. " selects the expected building ownership"
  )
  T.eq(
    community.caveDetails:get(),
    mode == "off" and "off" or mode == "auto" and "subtle" or "full",
    "Legendary " .. mode .. " selects expected cave detail"
  )
  for _, mapId in ipairs({ "PALLET_TOWN", "OAKS_LAB" }) do
    local allocBefore, vertsBefore = hardwareStats.allocations, hardwareStats.vertices
    world:setMap(mapId, 5, 6, "down", { via = "boot" })
    T.eq(world.map.id, mapId, "native world enters " .. mapId .. " under " .. mode)
    for _ = 1, 3 do
      Game.input:step()
      Game.stack:update(1 / 60)
      Pipelines.update(1 / 60)
    end
    local vertices, indices, count = mesher.geometry(world.map, true)
    local roomShadowDraws = 0
    if mapId == "OAKS_LAB" then
      V.require("GameCorner").draw(world.map, {
        draw = function(mesh, texture)
          assert(mesh and mesh:getVertexCount() > 0, "room shadow pass receives a nonempty validated mesh")
          roomShadowDraws = roomShadowDraws + 1
        end,
      })
      T.check(roomShadowDraws > 0, "unchanged room shadow pass consumes its actual dedicated meshes")
    end
    local roomMeshes = hardwareStats.allocations - allocBefore
    local roomVertices = hardwareStats.vertices - vertsBefore
    if mapId == "OAKS_LAB" then
      T.check(
        V.require("GameCorner").owns(world.map) and roomMeshes > 0 and roomVertices > 0,
        "unchanged " .. mode .. " generates the dedicated native lab room meshes"
      )
    else
      T.check(
        type(vertices) == "table" and #vertices > 0,
        "unchanged " .. mode .. " generates CPU terrain for " .. mapId
      )
    end
    local valid = true
    for _, vertex in ipairs(vertices) do
      for _, n in ipairs(vertex) do
        if type(n) ~= "number" or n ~= n or math.abs(n) == math.huge then
          valid = false
        end
      end
    end
    for _, index in ipairs(indices or {}) do
      if type(index) ~= "number" or index < 1 or index > #vertices or index % 1 ~= 0 then
        valid = false
      end
    end
    T.check(valid, "CPU geometry contains finite vertices and valid indices for " .. mapId .. " " .. mode)
    geometryResults[#geometryResults + 1] = {
      mode = mode,
      mapId = mapId,
      vertices = #vertices,
      indices = #(indices or {}),
      count = count,
      roomMeshes = roomMeshes,
      roomVertices = roomVertices,
      roomShadowDraws = roomShadowDraws,
    }
    print("BATTLEART_GEOMETRY " .. require("src.link.Json").encode(geometryResults[#geometryResults]))
  end
end
world:setMap("PALLET_TOWN", 5, 6, "down", { via = "boot" })
local mon = require("src.pokemon.Pokemon").new(Data, "LAPRAS", 40)
mon.moves = { { id = "SURF", pp = 15 } }
Game.save.party = { mon }
local Battle = require("src.battle.BattleState")
local events = T.record.events(run.loader, { only = { ["battle.started"] = true, ["battle.ended"] = true } })
local battle = Battle.newWild(Game, "MAGIKARP", 5)
battle.onFinish = function(result)
  world:afterBattle(result, battle)
end
world:pushBattle(battle)
local function press(key)
  Game.input:keypressed(key)
  Game.input:step()
  Game.stack:update(1 / 60)
  Game.input:keyreleased(key)
  Game.input:step()
end
local function battleFrame(frame)
  Game.input:step()
  Game.stack:update(1 / 60)
  Pipelines.update(1 / 60)
  if Game.stack:top() == battle then
    battle:draw()
    if frame % 8 == 0 and battle.phase ~= "menu" and battle.phase ~= "moveSelect" then
      press("z")
    end
  end
end
for frame = 1, 2400 do
  battleFrame(frame)
  if Game.stack:top() == battle and battle.phase == "menu" then
    break
  end
end
T.eq(Game.stack:top(), battle, "native world transition enters the real battle with Battle Art loaded")
T.eq(battle.phase, "menu", "native battle intro reaches the action menu with the unchanged packages")
T.check(not V.require("Voxel3D").available(), "hardware fixture explicitly leaves GPU staging unavailable")
T.eq(
  exported.battleStage.state(battle),
  nil,
  "public staged descriptor yields cleanly to the ordinary battle fallback"
)
T.eq(
  events:count("battle.started"),
  1,
  "unchanged package combination preserves one native battle start event"
)
local ppBefore, expBefore = mon.moves[1].pp, mon.exp
press("z")
T.eq(battle.phase, "moveSelect", "native Fight opens the real move selector")
press("z")
for frame = 1, 3600 do
  battleFrame(frame)
  if Game.stack:top() == world then
    break
  end
end
T.eq(battle.result, "win", "native selected Surf move wins with the unchanged presentation mods loaded")
T.check(
  mon.moves[1].pp < ppBefore and mon.exp > expBefore,
  "native battle preserves PP costs and experience gain"
)
T.eq(events:count("battle.ended"), 1, "unchanged packages preserve one native battle end event")
T.eq(Game.stack:top(), world, "native battle transition restores the original world")
events:stop()
T.eq(#run.errors, 0, "native maps/settings/pipeline/battle updates add no mod errors")
print(
  "BATTLEART_CONSUMER_RESULT "
    .. require("src.link.Json").encode({
      loaded = true,
      version = exported.version,
      combined = combined,
      errors = #run.errors,
      geometry = geometryResults,
      battle = {
        result = battle.result,
        ppSpent = ppBefore - mon.moves[1].pp,
        expGain = mon.exp - expBefore,
        gpuStaged = false,
      },
    })
)
run.release()
T.finish("Battle Art unchanged native consumer")
