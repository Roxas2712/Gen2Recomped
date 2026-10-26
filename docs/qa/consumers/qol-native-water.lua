-- Read-only imported Red data, unmodified mod, real world/menu/input modules.
-- Graphics and filesystem remain hardware doubles; no graphical claim.
local T = require("tests.modkit")
local Data = require("src.core.Data")
local Version = require("src.core.GameVersion")
Version.set("red")
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
local files = {}
for _, name in ipairs({
  "manifest.json",
  "main.lua",
  "qol_options.lua",
  "qol_controller_compat.lua",
  "qol_battle_overlays.lua",
  "qol_feature_xp_bar.lua",
  "qol_feature_caught_indicator.lua",
  "qol_feature_easy_interactions.lua",
  "qol_feature_location_banners.lua",
  "transforms.lua",
}) do
  local f = assert(io.open(assert(arg[1]) .. "/" .. name, "rb"))
  files["mods/quality_of_life/" .. name] = f:read("*a")
  f:close()
end
local run
if os.getenv("QOL_DISK") == "1" then
  run = T.sdk.loadMod(assert(arg[1]), { data = Data, dev = true })
else
  run = T.sdk.loadMod("mods/quality_of_life", { data = Data, fs = T.sdk.memfs(files), dev = true })
end
Game.mods = run.loader
assert(#run.errors == 0, table.concat(run.errors, "\n"))
assert(run.loader.exports.quality_of_life, "the unchanged mod must actually run")
local options = {
  qol_easy_interactions = true,
  qol_location_banners = 2,
  qol_exp_bar = "blue",
  qol_caught_indicator = "red",
}
Game.save.options.modOptions = { quality_of_life = options }
local world = require("src.world.OverworldController")
Game.stack:push(world, "PALLET_TOWN", 5, 6, "down")
T.check(Game.stack:top() == world and world.map.id == "PALLET_TOWN", "native imported world entry succeeds")
T.check(
  type(rawget(world, "__qolLocationBannerOverlay")) == "table",
  "native map entry installs the unmodified banner"
)
world:drawUI()
local Input = Game.input
local function press(key)
  Input:keypressed(key)
  Input:step()
  local state = assert(Game.stack:top())
  if state == world then
    world:handleInput()
  else
    state:update(1 / 60)
  end
  Input:keyreleased(key)
  Input:step()
end
-- The mod must delegate START to the original overworld input method.
press("escape")
local start = Game.stack:top()
T.check(
  start ~= world and type(start.items) == "table",
  "unmodified wrapper delegates START to native start menu"
)
press("x")
T.eq(Game.stack:top(), world, "native B input returns to the same live world")
local mon = require("src.pokemon.Pokemon").new(Data, "PIDGEOT", 40)
mon.moves = { { id = "FLY", pp = 15 } }
Game.save.party = { mon }
Game.save.inventory.THUNDERBADGE = 1
assert(world:partyKnows("FLY") == mon, "native HM eligibility requires the ordinary badge")
press("tab")
local field = Game.stack:top()
T.check(field ~= world and field.items[1].label == "FLY", "native SELECT opens the mod field-action popup")
press("x")
T.eq(Game.stack:top(), world, "native cancel closes the field popup")

local Player = require("src.world.Player")
local TextBox = require("src.render.TextBox")
local shore
for y = 1, world.map.heightCells - 2 do
  for x = 1, world.map.widthCells - 2 do
    if
      not shore
      and world.map:isWalkableCell(x, y)
      and not world.map:isWaterCell(x, y)
      and not world:npcAtCell(x, y)
    then
      for _, dir in ipairs({ "down", "right", "left", "up" }) do
        local candidate = Player.new(Data, x, y, dir)
        local fx, fy = candidate:facingCell()
        if
          world.map:inBounds(fx, fy)
          and world.map:isWaterCell(fx, fy)
          and not world:npcAtCell(fx, fy)
          and not world.map:signAtCell(fx, fy)
        then
          shore = { x = x, y = y, facing = dir, fx = fx, fy = fy }
          break
        end
      end
    end
  end
end
assert(shore, "the actual imported map must contain an unobstructed shore")
world.player = Player.new(Data, shore.x, shore.y, shore.facing)
local surfMon = require("src.pokemon.Pokemon").new(Data, "LAPRAS", 40)
surfMon.moves = { { id = "SURF", pp = 15 } }
Game.save.party = { surfMon }
Game.save.inventory.SOULBADGE = 1
Game.save.inventory.SUPER_ROD = 1
Game.save.inventory.GOOD_ROD = 1
Game.save.inventory.OLD_ROD = 1
T.eq(world:useSurfFieldMove(), "ok", "native eligibility confirms imported shore and ordinary Surf badge")
press("z")
local water = Game.stack:top()
T.check(
  water ~= world and water.items and #water.items == 3,
  "native A interaction opens the unmodified combined water menu"
)
T.eq(water.items[1].label, "USE SUPER ROD", "all three native rods choose the strongest owned rod")
T.eq(water.items[2].label, "SURF", "combined water menu offers Surf")
press("x")
T.eq(Game.stack:top(), world, "native B cancels the combined water menu")
T.check(not world.fishing and not world.player.surfing, "B cancel starts neither fishing nor surfing")
press("z")
press("down")
press("down")
T.eq(
  Game.stack:top().items[Game.stack:top().index].label,
  "CANCEL",
  "explicit downward navigation reaches CANCEL in both engines"
)
press("z")
T.eq(Game.stack:top(), world, "explicit CANCEL returns to the native world")
T.check(not world.fishing and not world.player.surfing, "explicit CANCEL starts neither action")

-- The actual rod roll is deterministic; no world method or hook is replaced.
Game.save.inventory.SOULBADGE = nil
local noBiteSeed
for seed = 1, 64 do
  math.randomseed(seed)
  if math.random(0, 255) % 2 == 1 then
    noBiteSeed = seed
    break
  end
end
assert(noBiteSeed, "find a deterministic no-bite random byte")
math.randomseed(noBiteSeed)
press("z")
T.eq(
  getmetatable(Game.stack:top()),
  TextBox,
  "rod-only native A interaction starts the real fishing dialogue"
)
local castPoseSeen = world.fishing ~= nil and world.player.fishing == true
local dialogueTexts = {}
local function completeDialogue()
  for frame = 1, 600 do
    local top = Game.stack:top()
    castPoseSeen = castPoseSeen or (world.fishing ~= nil and world.player.fishing == true)
    if getmetatable(top) ~= TextBox then
      return
    end
    if not dialogueTexts[top] then
      dialogueTexts[top] = true
      print("QOL_DIALOGUE " .. require("src.link.Json").encode(top.pages or {}))
    end
    Input:step()
    top:update(1 / 60)
    if top == Game.stack:top() and (top.done or top.waiting) then
      press("z")
    end
  end
  error("native dialogue exceeded 600 frames")
end
completeDialogue()
T.check(castPoseSeen, "native casting displays the rod pose before the verdict closes")
T.eq(Game.stack:top(), world, "native no-bite dialogue returns to the original world")
T.check(
  world.fishing == nil and world.fishPose == 10,
  "native no-bite releases rod OAM and retains the timed player pose"
)
for _ = 1, 12 do
  Input:step()
  Game.stack:update(1 / 60)
end
T.check(not world.player.fishing, "ordinary native world updates clear the remaining fishing pose")

Game.save.inventory.SOULBADGE = 1
press("z")
press("down")
press("z")
T.eq(getmetatable(Game.stack:top()), TextBox, "native SURF selection opens the cartridge dialogue")
T.check(not world.player.surfing, "native Surf waits for the dialogue before mounting")
completeDialogue()
for _ = 1, 90 do
  Input:step()
  Game.stack:update(1 / 60)
end
T.eq(Game.stack:top(), world, "native Surf transition returns control to the world")
T.check(world.player.surfing == true, "native Surf selection mounts the actual player")
T.eq(world.player.cellX, shore.fx, "native Surf finishes the step onto the water X")
T.eq(world.player.cellY, shore.fy, "native Surf finishes the step onto the water Y")
T.check(
  world.map:isWaterCell(world.player.cellX, world.player.cellY),
  "mounted player occupies imported water"
)
-- Start a second real cast using the cartridge's guaranteed Old Rod bite.
world.player = Player.new(Data, shore.x, shore.y, shore.facing)
Game.save.inventory.SUPER_ROD, Game.save.inventory.GOOD_ROD = nil, nil
Game.save.inventory.SOULBADGE = nil
Game.save.pokedex.owned.MAGIKARP = true
local Growth = require("src.pokemon.Growth")
local def = Data.pokemon[surfMon.species]
local at = Growth.expForLevel(def.growthRate, surfMon.level, Data.growth_rates)
local nextAt = Growth.expForLevel(def.growthRate, surfMon.level + 1, Data.growth_rates)
surfMon.exp = math.floor((at + nextAt) / 2)
local events = T.record.events(run.loader, { only = { ["battle.started"] = true, ["battle.ended"] = true } })
press("z")
completeDialogue()
local Battle = require("src.battle.BattleState")
for _ = 1, 600 do
  if getmetatable(Game.stack:top()) == Battle then
    break
  end
  Input:step()
  Game.stack:update(1 / 60)
end
local battle = Game.stack:top()
assert(getmetatable(battle) == Battle, "native guaranteed bite must enter the actual battle")
T.eq(battle.enemy.mon.species, "MAGIKARP", "native Old Rod bite uses the cartridge species")
T.eq(battle.enemy.mon.level, 5, "native Old Rod bite uses the cartridge level")
T.eq(events:count("battle.started"), 1, "native battle entry emits one start event")
T.check(rawget(battle, "draw") ~= nil, "unmodified QoL installs its draw wrapper on the actual native battle")
local originalRect, originalDraw = love.graphics.rectangle, love.graphics.draw
local blueBars, caughtBalls = 0, 0
love.graphics.rectangle = function(mode, x, y, w, h, ...)
  local r, g, b = love.graphics.getColor()
  if
    mode == "fill"
    and y == 89
    and h == 2
    and w > 0
    and r == 56 / 255
    and g == 144 / 255
    and b == 240 / 255
  then
    blueBars = blueBars + 1
  end
  return originalRect(mode, x, y, w, h, ...)
end
love.graphics.draw = function(image, ...)
  if type(image) == "table" and image.path == "save/mod-derived/quality_of_life/ui/ball.png" then
    caughtBalls = caughtBalls + 1
  end
  return originalDraw(image, ...)
end
for frame = 1, 2400 do
  Input:step()
  Game.stack:update(1 / 60)
  if Game.stack:top() == battle then
    battle:draw()
    if battle.phase == "menu" then
      break
    end
    if frame % 8 == 0 then
      press("z")
    end
  end
end
T.eq(battle.phase, "menu", "native battle intro reaches the ordinary action menu")
T.check(blueBars > 0, "unmodified XP overlay submits blue fill calls on the actual native battle")
T.check(caughtBalls > 0, "unmodified caught indicator submits draw calls on the actual native battle")
local ppBefore = surfMon.moves[1].pp
local expBefore = surfMon.exp
press("z")
T.eq(battle.phase, "moveSelect", "native A opens the real battle move menu")
press("z")
for frame = 1, 3600 do
  Input:step()
  Game.stack:update(1 / 60)
  if Game.stack:top() == battle then
    battle:draw()
    if frame % 8 == 0 then
      press("z")
    end
  elseif Game.stack:top() == world then
    break
  end
end
love.graphics.rectangle, love.graphics.draw = originalRect, originalDraw
T.eq(battle.result, "win", "native selected Surf move wins the guaranteed fishing battle")
T.check(surfMon.moves[1].pp < ppBefore, "native battle spends the selected move PP")
T.check(surfMon.exp > expBefore, "native battle awards experience to the actual party Pokemon")
T.eq(events:count("battle.ended"), 1, "native battle teardown emits one end event")
T.eq(Game.stack:top(), world, "native battle return transition restores the original world")
local overlayErrors = 0
for _, line in ipairs(require("src.core.Logger").history) do
  if tostring(line):find("battle overlay disabled:", 1, true) then
    overlayErrors = overlayErrors + 1
  end
end
T.eq(overlayErrors, 0, "unmodified battle overlays remain enabled without swallowed draw errors")
events:stop()
T.eq(#run.errors, 0, "production water/menu/dialogue/battle paths record no mod errors")
print("QOL_NATIVE_RESULT " .. require("src.link.Json").encode({
  mapId = world.map.id,
  shore = shore,
  fishingComplete = world.fishing == nil,
  player = { x = world.player.cellX, y = world.player.cellY, surfing = world.player.surfing == true },
  depth = #Game.stack.states,
  errors = #run.errors,
  battle = {
    species = battle.enemy.mon.species,
    level = battle.enemy.mon.level,
    result = battle.result,
    expGain = surfMon.exp - expBefore,
    ppSpent = ppBefore - surfMon.moves[1].pp,
    blueBar = blueBars > 0,
    caughtBall = caughtBalls > 0,
    overlayErrors = overlayErrors,
  },
}))
run.release()
T.finish("unchanged QoL native water controller flow")
