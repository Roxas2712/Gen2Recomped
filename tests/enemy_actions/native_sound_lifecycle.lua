-- Sequential commands use real native audio and real host M4A sources.
-- Only the speaker hardware is owned; no audio device or normal cache is used.
local M = {}
function M.run(root, backend, version)
  local native = backend == "gen1"
  local f = dofile(root .. "/tests/enemy_actions/assist.lua").fixture(root, backend, version)
  local hardware = dofile(root .. "/tests/native_sound/fixture.lua").install(root, native, f)
  local cases = {
    { name = "same-id-same-controls", steps = { { 141, -64 }, { 141, -64 } } },
    { name = "same-id-pan-switch", steps = { { 141, -64 }, { 141, 63 } } },
    { name = "different-id-same-player", steps = { { 141, -64 }, { 164, 63 } } },
    { name = "independent-players", otherPlayer = 2, steps = { { 141, -64 }, { 164, 63 } } },
    { name = "replace-one-player", otherPlayer = 2, steps = { { 141, -64 }, { 164, 63 }, { 148, -64 } } },
    { name = "same-id-mono-switch", steps = { { 141, -64 }, { 141, -64, true } } },
  }
  local rows = {}
  for _, case in ipairs(cases) do
    hardware.clear()
    hardware.player(164, case.otherPlayer or 1)
    local states = {}
    for tick, step in ipairs(case.steps) do
      hardware.tick(tick)
      hardware.stereo(not step[3])
      if native then
        assert(require("src.core.game3.audio").playSe(step[1], { pan = step[2] }))
      else
        assert(require("src.core.Sound").playId(f.data, step[1], { pan = step[2], mono = step[3] or false }))
      end
      states[#states + 1] = hardware.active()
    end
    rows[#rows + 1] = { case = case.name, states = states, sounds = hardware.trace() }
  end
  hardware.clear()
  hardware.close()
  f.close()
  return rows
end
return M
