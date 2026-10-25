package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.modkit")
for _, version in ipairs({ "firered", "emerald" }) do
  local rows = dofile("tests/enemy_actions/battle_effect_presentation.lua").run(".", "gen2", version)
  T.eq(#rows, 72, "all native actor/options/protection inputs execute")
  for _, row in ipairs(rows) do
    local last = row.frames[#row.frames]
    T.check(last.done, "actual native effect queue completes")
    for _, frame in ipairs(row.frames) do
      T.eq(frame.rng, 0, "presentation never consumes battle RNG")
    end
    if row.scene and row.case == "ordinary" then
      T.eq(#row.frames, 72, "native poison waits for all six sounds and visual tasks")
      T.eq(row.frames[2].states[row.actor + 1].x, 1, "native initial shake starts on the actual actor")
      T.eq(
        row.frames[27].states[row.actor + 1].coeff,
        0.75,
        "native first color cycle reaches twelve of sixteen"
      )
      T.eq(last.states[row.actor + 1].x, 0, "native shake restores its original coordinate")
      T.eq(last.states[row.actor + 1].coeff, 0, "native palette cycle releases its tint")
      for i, sound in ipairs(row.sounds) do
        T.eq(sound.tick, 1 + (i - 1) * 14, "native loop counter owns the sound timing")
        T.eq(sound.id, version == "firered" and 141 or 148, "native sound index follows the actual edition")
        T.eq(sound.pan, row.actor % 2 == 0 and -64 or 63, "actual output source uses native side panorama")
        T.eq(sound.mono, not row.stereo, "actual output source respects the native sound option")
      end
    else
      T.eq(#row.frames, 1, "native skipped status animation adds no waiting tick")
      T.eq(#row.sounds, 0, "native skipped status animation is silent")
    end
  end
end
T.finish("native GBA status presentation and actual sound controls")
