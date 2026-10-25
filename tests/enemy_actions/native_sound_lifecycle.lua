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
    { name = "native-then-role", steps = { { 141, -64 }, { 164, nil, false, true } } },
    { name = "role-then-native", steps = { { 164, nil, false, true }, { 141, -64 } } },
    { name = "same-id-independent-players", steps = { { 141, -64 }, { 141, -64, false, false, 2 } } },
    {
      name = "replace-after-clone",
      steps = { { 141, -64 }, { 141, -64, false, false, 2 }, { 164, 63, false, false, 2 } },
    },
  }
  local rows = {}
  for _, case in ipairs(cases) do
    hardware.clear()
    hardware.player(141, 1)
    hardware.player(148, 1)
    hardware.player(164, case.otherPlayer or 1)
    local states = {}
    for tick, step in ipairs(case.steps) do
      if step[5] then
        hardware.player(step[1], step[5])
      end
      hardware.tick(tick)
      hardware.stereo(not step[3])
      if step[4] then
        hardware.role(step[1], "OWNED_ROLE_" .. step[1])
      end
      if native then
        assert(require("src.core.game3.audio").playSe(step[1], { pan = step[2] }))
      elseif step[4] then
        assert(require("src.core.Sound").play(f.data, "OWNED_ROLE_" .. step[1]))
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
