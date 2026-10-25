-- Actual native world VM and host lowering/runner; only source hardware is owned.
local M = {}
function M.run(root, backend, version)
  local native = backend == "gen1"
  local f = dofile(root .. "/tests/enemy_actions/assist.lua").fixture(root, backend, version)
  local runtime, savedSession
  if native then
    runtime = require("src.core.game3.runtime")
    savedSession, runtime.session = runtime.session, { version = version }
    assert(require("src.core.game3.profile").forSession(nil).id == version)
  end
  local hardware = dofile(root .. "/tests/native_sound/fixture.lua").install(root, native, f)
  local rows = {}
  for _, case in ipairs({
    { name = "silent" },
    { name = "native-player-one", play = true },
    { name = "native-player-two", play = true, player = 2 },
    { name = "special-player-three", play = true, player = 3 },
    { name = "file-override", override = true },
    { name = "native-and-file-override", play = true, override = true },
  }) do
    hardware.clear()
    hardware.player(141, case.player or 1)
    hardware.tick(0)
    if case.play then
      if native then
        require("src.core.game3.audio").playSe(141, { pan = -64 })
      else
        require("src.core.Sound").playId(f.data, 141, { pan = -64 })
      end
    end
    if case.override then
      hardware.override(164, "file")
      if native then
        require("src.core.game3.audio").playSe(164)
      else
        require("src.core.Sound").playId(f.data, 164)
      end
    end
    local runner, advanced
    if native then
      runner = require("src.core.game3.scripting.vm").new({
        scripts = {
          OWNED_WAIT = { { op = "waitse" }, { op = "setvar", 0x4001, 1 }, { op = "end" } },
        },
      })
      assert(runner:start("OWNED_WAIT"))
      advanced = function()
        return require("src.core.game3.scripting.flags").getVar(runner.store, runner.ctx, 0x4001) == 1
      end
    else
      local data = {
        map_scripts = {
          source = "RomExtractorGen3",
          scripts = {
            OWNED_WAIT = { { "waitse" }, { "setvar", 0x4001, 1 }, { "end" } },
          },
        },
      }
      local commands = assert(require("src.script.Gen3ScriptVM").compile(data, "OWNED_WAIT"))
      runner = require("src.script.ScriptRunner").new(f.game, {})
      runner:run(commands)
      advanced = function()
        return require("src.script.Gen3Commands").getVar(f.game.save, 0x4001) == 1
      end
    end
    local frames = {}
    for tick = 0, 4 do
      hardware.tick(tick)
      if tick == 3 then
        if native then
          require("src.core.game3.audio").stopSe()
        else
          require("src.core.Sound").stopSe(f.data)
        end
      end
      if tick > 0 then
        if native then
          runner:tick()
        else
          runner:update()
        end
      end
      frames[#frames + 1] = {
        tick = tick,
        running = runner:isRunning(),
        advanced = advanced(),
        active = hardware.active(),
        queries = hardware.queries(),
      }
    end
    assert(frames[#frames].advanced, "actual script must reach its post-wait variable write")
    rows[#rows + 1] = { case = case.name, frames = frames, sounds = hardware.trace() }
    if not native then
      require("src.script.Gen3Commands").setVar(f.game.save, 0x4001, 0)
    end
  end
  hardware.clear()
  hardware.close()
  if native then
    runtime.session = savedSession
  end
  f.close()
  return rows
end
return M
