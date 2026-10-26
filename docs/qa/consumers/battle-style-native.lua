return function(game)
  local U = require("tests.drivers.util")
  local Json = require("src.link.Json")
  local identity = assert(os.getenv("POKEPORT_IDENTITY"))
  assert(love.filesystem.getSaveDirectory():sub(-#identity - 1) == "/" .. identity)
  assert(os.getenv("POKEPORT_SKIP_LEGACY_MIGRATION") == "1")
  assert(not require("src.core.SaveData").isPortable())
  local renderer, version, vendor, device = love.graphics.getRendererInfo()
  print(
    "BATTLE_STYLE_META "
      .. Json.encode({
        renderer = renderer,
        version = version,
        vendor = vendor,
        device = device,
        love = { love.getVersion() },
        gameVersion = require("src.core.GameVersion").get(),
      })
  )
  local e = assert(game.mods.exports.portable_battle_style)
  game.save = require("src.core.SaveData").newGame(game.data.field.boot)
  game.save.options.musicVol = 0
  game.save.options.sfxVol = 0
  game.save.options.pikaVol = 0
  game.save.options.textSpeed = 1
  game.save.options.animations = false
  game:applyOptions(game.save.options)
  U.teleport(game, "PALLET_TOWN", 9, 7, "right")
  local world = game.overworld
  local P = require("src.pokemon.Pokemon")
  local Battle = require("src.battle.BattleState")
  assert(game.data.pokemon.MEW and game.data.moves.TACKLE and game.data.trainers.OPP_YOUNGSTER)
  local rows = {}
  for _, c in ipairs({
    { mode = "set", option = "shift", offer = false },
    { mode = "shift", option = "set", offer = true },
    { mode = "unsubscribe", option = "set", offer = false },
  }) do
    local mon = P.new(game.data, "MEW", 30)
    mon.moves = { { id = "TACKLE", pp = 30 } }
    mon.stats.speed = 500
    mon.stats.attack = 500
    game.save.party = { mon, P.new(game.data, "MEW", 30) }
    game.save.options.battleStyle = c.option
    if c.mode == "unsubscribe" then
      e.off()
    else
      e.set(c.mode)
    end
    local before = e.calls()
    local b = Battle.newTrainer(game, "OPP_YOUNGSTER", 1)
    assert(#b.enemyParty >= 2)
    b.enemy.mon.hp = 1
    b.queue, b.phase, b.afterQueue, b.menuIndex = {}, "menu", "menu", 1
    b.introSlide, b.fx = 0, {}
    b.rng = function(lo)
      return lo or 0
    end
    game.stack.states = { world, b }
    U.tap(game, "a")
    assert(b.phase == "moveSelect", "actual FIGHT input missing")
    U.tap(game, "a")
    local offers = 0
    local seenChoice = {}
    local settled = false
    for _ = 1, 4000 do
      local top = game.stack:top()
      if top ~= b then
        assert(getmetatable(top) == require("src.ui.ChoiceBox"), "unexpected native overlay")
        if not seenChoice[top] then
          seenChoice[top] = true
          offers = offers + 1
          assert(offers == 1 and c.offer, "unexpected SHIFT offer")
          assert(U.shot(game, assert(os.getenv("BATTLE_STYLE_OUT")) .. "/shift-choice.png"))
        end
        U.tap(game, "b")
      elseif b.phase == "menu" and b.enemyIndex == 2 then
        settled = true
        break
      else
        U.tap(game, "a")
      end
    end
    assert(settled, "actual trainer replacement queue did not settle")
    assert((offers == 1) == c.offer, "actual dialog disagrees with mod decision")
    assert(game.save.options.battleStyle == c.option, "mod decision changed persistent option")
    assert(e.calls() - before == (c.mode == "unsubscribe" and 0 or 1), "actual faint must dispatch once")
    assert(U.shot(game, assert(os.getenv("BATTLE_STYLE_OUT")) .. "/" .. c.mode .. "-menu.png"))
    rows[#rows + 1] = {
      mode = c.mode,
      option = c.option,
      offers = offers,
      enemyIndex = b.enemyIndex,
      partySize = #game.save.party,
      calls = e.calls() - before,
    }
  end
  assert(#game.mods.errors == 0)
  print("BATTLE_STYLE_GPU_RESULT " .. Json.encode({ rows = rows, errors = #game.mods.errors }))
end
