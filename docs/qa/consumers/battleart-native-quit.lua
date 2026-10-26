return function(game)
  local U = dofile("tests/drivers/util.lua")
  local Json = require("src.link.Json")
  local identity = assert(os.getenv("POKEPORT_IDENTITY"))
  local saveDir = love.filesystem.getSaveDirectory()
  assert(saveDir:sub(-#identity - 1) == "/" .. identity)
  assert(not require("src.core.SaveData").isPortable())
  local renderer, version, vendor, device = love.graphics.getRendererInfo()
  print(
    "BATTLEART_GPU_META "
      .. Json.encode({
        renderer = renderer,
        version = version,
        vendor = vendor,
        device = device,
        love = { love.getVersion() },
        identity = identity,
        saveDirectory = saveDir,
        gameVersion = require("src.core.GameVersion").get(),
      })
  )
  local host = assert(game.mods.exports.BATTLE_ART_VOXEL_FORK)
  assert(host.version == "1.11.2" and game.mods.exports.LEGENDARY_INTERIOR_OVERHAUL)
  local V = assert(host.lib)
  local P = require("src.render.Pipelines")
  V.require("AntiAlias").setting:setIndex(1, game)
  V.require("RenderDistance").setting:setIndex(1, game)
  P.setLevel("tiltshift", 0)
  game.save = require("src.core.SaveData").newGame(game.data.field.boot)
  game.save.options.musicVol = 0
  game.save.options.sfxVol = 0
  game.save.options.pikaVol = 0
  game:applyOptions(game.save.options)
  local preset = V.require("LegendaryVisualsPreset")
  preset.setting:setIndex(4, game)
  preset.changed(preset.setting.key)
  P.setLevel("voxel", 3)
  U.teleport(game, "PALLET_TOWN", 9, 7, "right")
  for frame = 1, 1800 do
    U.wait(1)
    if
      frame >= 120
      and V.require("VoxelState").ready
      and not V.require("ChunkMesher").jobPending("PALLET_TOWN", true)
      and not V.require("ChunkMesher").jobPending("PALLET_TOWN", false)
    then
      break
    end
    assert(frame < 1800, "native world geometry did not settle")
  end
  assert(V.require("Voxel3D").available() and P.worldPipeline() == "voxel")
  assert(U.shot(game, assert(os.getenv("BATTLEART_GPU_OUT")) .. "/before-native-quit.png"))
  local Runtime = require("src.mods.Runtime")
  local companion = assert(V.companion)
  local function frameHooks()
    local n = 0
    for _, entry in ipairs(Runtime.hooks.chains["core.update"] or {}) do
      if entry.owner == "BATTLE_ART_VOXEL_FORK" then
        n = n + 1
      end
    end
    return n
  end
  assert(companion:status().state == "running")
  Runtime.hooks:wrap("core.quit_to_launcher", function(next)
    local before = frameHooks()
    local decision = next()
    local disposed = companion:status().state == "disposed"
    assert(disposed and decision == false and frameHooks() < before)
    print(
      "QUIT_NATIVE_GPU_RESULT "
        .. Json.encode({
          disposed = disposed,
          decision = decision,
          frameHooksBefore = before,
          frameHooksAfter = frameHooks(),
          errors = #game.mods.errors,
        })
    )
    return decision
  end, 100000, "qa_quit_observer")
  print(
    "BATTLEART_GPU_RESULT "
      .. Json.encode({ loaded = true, voxel = true, errors = #game.mods.errors, awaitingActualLoveQuit = true })
  )
end
