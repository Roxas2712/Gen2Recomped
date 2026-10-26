return function(game)
  local U = dofile("tests/drivers/util.lua")
  local Json = require("src.link.Json")
  local out = assert(os.getenv("BATTLEART_GPU_OUT"))
  local identity = assert(os.getenv("POKEPORT_IDENTITY"))
  local saveDirectory = love.filesystem.getSaveDirectory()
  assert(saveDirectory:sub(-#identity - 1) == "/" .. identity)
  assert(not require("src.core.SaveData").isPortable())
  local renderer, version, vendor, device = love.graphics.getRendererInfo()
  print("BATTLEART_GPU_META " .. Json.encode({
    renderer = renderer,
    version = version,
    vendor = vendor,
    device = device,
    love = { love.getVersion() },
    identity = identity,
    saveDirectory = saveDirectory,
    gameVersion = require("src.core.GameVersion").get(),
  }))
  local host = assert(game.mods.exports.BATTLE_ART_VOXEL_FORK)
  assert(host.version == "1.11.2" and game.mods.exports.LEGENDARY_INTERIOR_OVERHAUL)
  local V = assert(host.lib)
  local P = require("src.render.Pipelines")
  local preset = V.require("LegendaryVisualsPreset")
  V.require("AntiAlias").setting:setIndex(1, game)
  V.require("RenderDistance").setting:setIndex(1, game)
  P.setLevel("tiltshift", 0)
  game.save = require("src.core.SaveData").newGame(game.data.field.boot)
  game.save.options.musicVol = 0
  game.save.options.sfxVol = 0
  game.save.options.pikaVol = 0
  game:applyOptions(game.save.options)
  preset.setting:setIndex(4, game)
  preset.changed(preset.setting.key)
  V.require("DayNight").setting:setIndex(2, game)
  V.require("OverworldBattle").setting:setIndex(1, game)
  P.setLevel("voxel", 3)
  U.teleport(game, "PALLET_TOWN", 9, 7, "right")
  local world = game.overworld
  for x = 6, 12 do
    assert(
      world.map:isWalkableCell(x, 7) and not world.map:isWaterCell(x, 7),
      "camera corridor is obstructed"
    )
  end
  for frame = 1, 1800 do
    U.wait(1)
    if
      frame >= 120
      and V.require("VoxelState").ready
      and not V.require("ChunkMesher").jobPending(world.map.id, true)
      and not V.require("ChunkMesher").jobPending(world.map.id, false)
    then
      break
    end
    assert(frame < 1800, "terrain did not settle")
  end
  assert(V.require("Voxel3D").available() and P.worldPipeline() == "voxel")
  local function shot(name)
    assert(U.shot(game, out .. "/" .. name .. ".png"))
    print("BATTLEART_GPU_SHOT " .. name)
  end
  P.setLevel("voxel", 6)
  U.wait(90)
  assert(V.require("FirstPerson").engaged())
  shot("first-person-open")
  P.setLevel("voxel", 7)
  U.wait(90)
  assert(V.require("FirstPerson").engaged())
  shot("third-person-open")
  P.setLevel("voxel", 3)
  U.wait(60)
  assert(not V.require("FirstPerson").driving())
  local mon = require("src.pokemon.Pokemon").new(game.data, "LAPRAS", 40)
  mon.moves = { { id = "SURF", pp = 15 } }
  game.save.party = { mon }
  local ppBefore, expBefore = mon.moves[1].pp, mon.exp
  local seenMessages = {}
  local function observeText(b)
    local text = b.current and b.current.text
    if type(text) == "string" and not seenMessages[text] then
      seenMessages[text] = true
      print("BATTLEART_GPU_TEXT " .. Json.encode({ text = text }))
    end
  end
  local battle = require("src.battle.BattleState").newWild(game, "MAGIKARP", 5)
  battle.onFinish = function(result)
    world:afterBattle(result, battle)
  end
  world:pushBattle(battle)
  for frame = 1, 2400 do
    U.wait(1)
    observeText(battle)
    if game.stack:top() == battle and battle.phase == "menu" then
      break
    end
    if frame % 8 == 0 then
      U.tap(game, "a")
    end
    assert(frame < 2400, "battle intro did not reach menu")
  end
  U.wait(60)
  local stage = assert(host.battleStage.state(battle), "native battle fell back to 2D")
  assert(stage.staged and stage.ready and stage.ownership.arena)
  shot("staged-battle-menu")
  U.tap(game, "a")
  U.wait(2)
  assert(battle.phase == "moveSelect", "Fight did not open the move selector")
  shot("staged-battle-moves")
  U.tap(game, "a")
  local capturedAction = false
  for frame = 1, 3600 do
    U.wait(1)
    observeText(battle)
    if
      not capturedAction
      and mon.moves[1].pp < ppBefore
      and game.stack:top() == battle
      and (battle.charIndex or 0) >= 5
    then
      shot("staged-battle-action")
      capturedAction = true
    end
    if game.stack:top() == world then
      break
    end
    if frame % 8 == 0 and battle.phase ~= "menu" and battle.phase ~= "moveSelect" then
      U.tap(game, "a")
    end
    assert(frame < 3600, "native battle did not return to the world")
  end
  assert(capturedAction and battle.result == "win")
  assert(mon.moves[1].pp == ppBefore - 1 and mon.exp > expBefore)
  assert(game.stack:top() == world and host.battleStage.state(battle) == nil)
  U.wait(120)
  shot("returned-world")
  assert(#game.mods.errors == 0, table.concat(game.mods.errors, "\n"))
  print("BATTLEART_GPU_RESULT " .. Json.encode({
    loaded = true,
    voxel = true,
    errors = #game.mods.errors,
    firstPerson = true,
    thirdPerson = true,
    cameraLocation = { 9, 7 },
    battle = {
      staged = stage.staged,
      ready = stage.ready,
      result = battle.result,
      ppSpent = ppBefore - mon.moves[1].pp,
      expGain = mon.exp - expBefore,
      returnedWorld = game.stack:top() == world,
      stageReleased = true,
    },
  }))
end
