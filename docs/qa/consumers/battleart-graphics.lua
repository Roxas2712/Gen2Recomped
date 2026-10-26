return function(game)
  local U = dofile("tests/drivers/util.lua")
  local Json = require("src.link.Json")
  local out = assert(os.getenv("BATTLEART_GPU_OUT"))
  local expected = assert(os.getenv("POKEPORT_IDENTITY"))
  local saveDir = love.filesystem.getSaveDirectory()
  assert(saveDir:sub(-#expected - 1) == "/" .. expected, "graphics run escaped the private test identity")
  assert(not require("src.core.SaveData").isPortable(), "portable persistence must stay disabled")
  local renderer, version, vendor, device = love.graphics.getRendererInfo()
  print(
    "BATTLEART_GPU_META "
      .. Json.encode({
        renderer = renderer,
        version = version,
        vendor = vendor,
        device = device,
        love = { love.getVersion() },
        identity = expected,
        saveDirectory = saveDir,
        gameVersion = require("src.core.GameVersion").get(),
      })
  )
  local host = assert(game.mods.exports.BATTLE_ART_VOXEL_FORK, "Battle Art did not load")
  assert(host.version == "1.11.2", "unexpected Battle Art version")
  assert(game.mods.exports.LEGENDARY_INTERIOR_OVERHAUL, "Legendary Interiors did not load")
  local V = assert(host.lib)
  local P = require("src.render.Pipelines")
  local preset = V.require("LegendaryVisualsPreset")
  local voxel = V.require("VoxelState")
  local mesh = V.require("ChunkMesher")
  V.require("AntiAlias").setting:setIndex(1, game)
  V.require("RenderDistance").setting:setIndex(1, game)
  P.setLevel("tiltshift", 0)
  game.save = require("src.core.SaveData").newGame(game.data.field.boot)
  game.save.options.musicVol = 0
  game.save.options.sfxVol = 0
  game.save.options.pikaVol = 0
  game:applyOptions(game.save.options)
  local results = {}
  local function settle()
    for frame = 1, 1800 do
      U.wait(1)
      if
        frame >= 120
        and voxel.ready
        and not mesh.jobPending(game.overworld.map.id, true)
        and not mesh.jobPending(game.overworld.map.id, false)
      then
        assert(P.worldPipeline() == "voxel", "actual native renderer fell back from voxel")
        return frame
      end
    end
    error("current-map voxel geometry did not become ready within 1800 rendered frames")
  end
  local function shot(name)
    assert(U.shot(game, out .. "/" .. name .. ".png"), "native graphics capture did not land")
  end
  for _, mode in ipairs({ "off", "auto", "full" }) do
    preset.setting:setIndex(mode == "off" and 1 or mode == "auto" and 3 or 4, game)
    preset.changed(preset.setting.key)
    P.setLevel("voxel", 3)
    U.teleport(game, "PALLET_TOWN", 5, 6, "down")
    assert(V.require("Voxel3D").available(), "native voxel shader/depth support unavailable")
    local frames = settle()
    shot("pallet-" .. mode)
    results[#results + 1] = { mode = mode, map = "PALLET_TOWN", readyFrames = frames, voxel = true }
  end
  U.teleport(game, "OAKS_LAB", 5, 6, "down")
  settle()
  shot("oak-lab-full")
  U.teleport(game, "PALLET_TOWN", 5, 6, "down")
  settle()
  P.setLevel("voxel", 6)
  U.wait(90)
  assert(V.require("FirstPerson").engaged(), "native first-person mode did not engage")
  shot("first-person-full")
  local x, y = game.overworld.player.px, game.overworld.player.py
  U.hold(game, "up", 12)
  U.wait(3)
  local moved = game.overworld.player.px ~= x or game.overworld.player.py ~= y
  print(
    "BATTLEART_GPU_FREECAM "
      .. Json.encode({ moved = moved, x = game.overworld.player.px, y = game.overworld.player.py })
  )
  P.setLevel("voxel", 7)
  U.wait(60)
  assert(V.require("FirstPerson").engaged(), "native third-person mode did not engage")
  shot("third-person-full")
  P.setLevel("voxel", 3)
  U.wait(60)
  assert(not V.require("FirstPerson").driving(), "native free-camera input remained captured after exit")
  assert(#game.mods.errors == 0, table.concat(game.mods.errors, "\n"))
  print(
    "BATTLEART_GPU_RESULT "
      .. Json.encode({
        loaded = true,
        voxel = true,
        profiles = results,
        firstPerson = true,
        thirdPerson = true,
        freeMove = moved,
        errors = #game.mods.errors,
      })
  )
end
