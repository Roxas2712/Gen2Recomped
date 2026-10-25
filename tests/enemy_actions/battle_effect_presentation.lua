-- Real native VM / host queue, complete tick states and measured sound controls.
local M = {}
function M.run(root, backend, version)
  local native = backend == "gen1"
  local f = dofile(root .. "/tests/enemy_actions/assist.lua").fixture(root, backend, version)
  local hardware = dofile(root .. "/tests/native_sound/fixture.lua").install(root, native, f)
  local Anim, Seq, Runtime
  if native then
    Anim, Seq = require("src.core.game3.battle.anim"), require("src.core.game3.battle.anim_seq")
    Runtime = require("src.core.game3.runtime")
    Anim.loadPack({
      version = 5,
      tags = {},
      statusNames = { [0] = "STATUS_PSN" },
      status = {
        [0] = {
          { op = "loopsewithpan", pan = 63, se = version == "firered" and 141 or 148, times = 6, wait = 13 },
          { op = "createvisualtask", task = "ShakeMon2", priority = 2, args = { 0, 1, 0, 18, 2 } },
          {
            op = "createvisualtask",
            task = "BlendColorCycle",
            priority = 2,
            args = { 2, 2, 2, 0, 12, 31774 },
          },
          { op = "end" },
        },
      },
    })
  end
  local rows = {}
  for _, double in ipairs({ false, true }) do
    for actor = 0, double and 3 or 1 do
      for _, scene in ipairs({ false, true }) do
        for _, stereo in ipairs({ false, true }) do
          for _, kind in ipairs({ "ordinary", "substitute", "hidden" }) do
            local b = f.field(double)
            local user, reached, draws = f.actor(actor), false, 0
            user.substituteHP = kind == "substitute" and 100 or nil
            user.mon.status = "PSN"
            b.rng = function()
              draws = draws + 1
              error("presentation cannot draw battle RNG")
            end
            hardware.reset()
            hardware.stereo(stereo)
            if native then
              require("src.core.game3.battle")._st = b
              user.status = "PSN"
              user.semiInvulnerable = kind == "hidden" and "ON_AIR" or nil
              Runtime.session = { version = version, options = { battleScene = scene and 0 or 1 } }
              Anim.reset({ headless = false, double = double })
              for id = 0, double and 3 or 1 do
                Anim.present(id).visible = true
              end
              Anim.setSubstitute(actor, kind == "substitute")
              if kind == "hidden" then
                Anim.present(actor).visible = false
              end
              Seq.beginEvents(
                { { kind = "anim", anim = "status", name = "POISON", attackerId = actor, targetId = actor } },
                function() end
              )
            else
              f.game.save.options.animations = scene
              user.invulnerable = kind == "hidden" or nil
              b.picFx = kind == "hidden" and { [user] = { hidden = true } } or nil
              b.current, b.waitFrames, b.nextInsert = nil, nil, 0
              b._gbaEffectPresentation = nil
              b.queue = {
                {
                  anim = "POISON",
                  gbaNativeEffect = true,
                  attackerPosition = actor,
                  targetPosition = actor,
                  attackerIsPlayer = user.isPlayer,
                },
                {
                  fn = function()
                    reached = true
                  end,
                },
              }
            end
            local frames, done = {}, false
            for tick = 0, 200 do
              hardware.tick(tick)
              if native then
                if tick > 0 then
                  Anim.update(1 / 60)
                end
                if not Anim.busy() then
                  done = Seq.update()
                end
              else
                b:updateQueue()
                done = reached
              end
              local states = {}
              for id = 0, double and 3 or 1 do
                local a = f.actor(id)
                local state
                if native then
                  local p = Anim.present(id)
                  state = {
                    x = p.ox or 0,
                    y = p.oy or 0,
                    alpha = p.alpha or 1,
                    visible = p.visible ~= false,
                    substitute = p.substitute or false,
                    monbg = p.monbg or false,
                    coeff = p.blendCoeff or 0,
                    color = p.blendColor or { 0, 0, 0 },
                  }
                else
                  local x, y = b:gen3AnimShake(a)
                  local r, g, blue, coeff = b:gen3AnimTint(a)
                  state = {
                    x = x,
                    y = y,
                    alpha = 1,
                    visible = not (b.picFx and b.picFx[a] and b.picFx[a].hidden),
                    substitute = b:substituteVisible(a),
                    monbg = false,
                    coeff = coeff or 0,
                    color = { r or 0, g or 0, blue or 0 },
                  }
                end
                state.hp, state.substituteHP = a.mon.hp, a.substituteHP or 0
                state.status = a.mon.status
                states[#states + 1] = state
              end
              frames[#frames + 1] = { tick = tick, done = done, states = states, rng = draws }
              if done then
                break
              end
            end
            assert(done, "native status animation must finish")
            f.T.eq(
              #hardware.trace(),
              scene and kind == "ordinary" and 6 or 0,
              "actual native poison sound sequence"
            )
            rows[#rows + 1] = {
              double = double,
              actor = actor,
              scene = scene,
              stereo = stereo,
              case = kind,
              frames = frames,
              sounds = hardware.trace(),
            }
          end
        end
      end
    end
  end
  hardware.close()
  f.close()
  return rows
end
return M
