return function(game)
  local U = require("tests.drivers.util")
  local Json = require("src.link.Json")
  local identity = assert(os.getenv("POKEPORT_IDENTITY"))
  assert(love.filesystem.getSaveDirectory():sub(-#identity - 1) == "/" .. identity)
  assert(os.getenv("POKEPORT_SKIP_LEGACY_MIGRATION") == "1")
  assert(not require("src.core.SaveData").isPortable())
  local renderer, version, vendor, device = love.graphics.getRendererInfo()
  print(
    "CATCH_NICKNAME_META "
      .. Json.encode({
        renderer = renderer,
        version = version,
        vendor = vendor,
        device = device,
        love = { love.getVersion() },
        gameVersion = require("src.core.GameVersion").get(),
      })
  )
  local e = assert(game.mods.exports.portable_catch_nickname)
  local P = require("src.pokemon.Pokemon")
  local Battle = require("src.battle.BattleState")
  local Choice = require("src.ui.ChoiceBox")
  local Naming = require("src.ui.NamingScreen")
  local PartyMenu = require("src.ui.PartyMenu")
  local out = assert(os.getenv("CATCH_NICKNAME_OUT"))
  game.save = require("src.core.SaveData").newGame(game.data.field.boot)
  game.save.options.musicVol = 0
  game.save.options.sfxVol = 0
  game.save.options.pikaVol = 0
  game.save.options.textSpeed = 1
  game.save.options.animations = false
  game:applyOptions(game.save.options)
  U.teleport(game, "PALLET_TOWN", 9, 7, "right")
  local world = game.overworld
  assert(game.data.pokemon.MEW and game.data.pokemon.RATTATA and game.data.items.MASTER_BALL)
  local rows = {}
  local scenarios = {
    { tag = "party-skip", destination = "party", value = false, name = false, questions = 0 },
    { tag = "party-supplied", destination = "party", value = "SCOUT", name = "SCOUT", questions = 0 },
    { tag = "box-supplied", destination = "box", value = "BOXSCOUT", name = "BOXSCOUT", questions = 0 },
    { tag = "box-forward", destination = "box", value = "forward", name = "A", questions = 1, typeName = true },
    { tag = "unsubscribe", destination = "party", name = false, questions = 1 },
  }
  for _, c in ipairs(scenarios) do
    game.save.party = {}
    for _ = 1, c.destination == "party" and 1 or 6 do
      game.save.party[#game.save.party + 1] = P.new(game.data, "MEW", 30)
    end
    game.save.boxes = nil
    game.save.box = nil
    game.save.currentBox = 1
    game.save.inventory = { MASTER_BALL = 2 }
    game.save.pokedex.owned.RATTATA = true
    game.save.pokedex.seen.RATTATA = true
    if c.tag == "unsubscribe" then
      e.off()
    else
      e.set(c.value)
    end
    local before = e.calls()
    local b = Battle.newWild(game, "RATTATA", 3)
    local caught = b.enemy.mon
    b.queue, b.phase, b.afterQueue, b.menuIndex = {}, "menu", "menu", 1
    b.introSlide, b.fx = 0, {}
    b.rng = function(lo)
      return lo or 0
    end
    local completed, event, eventName
    b.onFinish = function(result)
      completed = result
    end
    local off = require("src.mods.Runtime").events:on("pokemon.caught", function(ctx)
      event, eventName = ctx, ctx.mon.nickname
    end)
    game.stack.states = { world, b }
    U.tap(game, "down")
    U.tap(game, "a")
    for _ = 1, 60 do
      if game.stack:top() ~= b then
        break
      end
      U.wait(1)
    end
    assert(game.stack:top() ~= b, "native ITEM did not open bag")
    if c.tag == "party-skip" then
      assert(U.shot(game, out .. "/battle-bag.png"))
    end
    local used = false
    for _ = 1, 60 do
      if game.stack:top() == b and b.phase == "messages" then
        used = true
        break
      end
      U.tap(game, "a")
    end
    assert(used, "native bag did not use Master Ball")
    local questions, namingCount = 0, 0
    local seenChoice, seenNaming = {}, {}
    local settled = false
    for _ = 1, 5000 do
      local top = game.stack:top()
      if getmetatable(top) == Choice then
        if not seenChoice[top] then
          seenChoice[top] = true
          questions = questions + 1
          assert(questions == c.questions, "unexpected native nickname question")
          assert(U.shot(game, out .. "/" .. c.tag .. "-question.png"))
        end
        U.tap(game, c.typeName and "a" or "b")
      elseif getmetatable(top) == Naming then
        if not seenNaming[top] then
          seenNaming[top] = true
          namingCount = namingCount + 1
          assert(c.typeName and namingCount == 1, "unexpected native naming screen")
          U.wait(2)
          U.tap(game, "a")
          assert(#top.glyphs == 1 and top.glyphs[1] == "A", "native keyboard did not type A")
          assert(U.shot(game, out .. "/box-naming-A.png"))
          U.tap(game, "start")
        else
          U.wait(1)
        end
      elseif top == world and completed == "caught" then
        settled = true
        break
      else
        U.tap(game, "a")
      end
    end
    off()
    assert(settled, "native catch/nickname/transfer queue did not finish")
    local stored = c.destination == "party" and game.save.party[2] or game.save.boxes[1][1]
    assert(stored == caught and event and event.mon == caught, "native recipient identity changed")
    assert((stored.nickname or false) == c.name, "stored nickname disagrees with decision")
    assert(questions == c.questions and namingCount == (c.typeName and 1 or 0))
    assert(game.save.inventory.MASTER_BALL == 1, "native ball spend must remain exactly one")
    assert(event.destination == c.destination and game.save.pokedex.owned.RATTATA)
    assert(e.calls() - before == (c.tag == "unsubscribe" and 0 or 1), "native hook dispatch count")
    if c.tag == "party-supplied" then
      game.stack:push(PartyMenu.new(game))
      U.wait(2)
      assert(U.shot(game, out .. "/party-supplied.png"))
      for _ = 1, 60 do
        if game.stack:top() == world then
          break
        end
        U.tap(game, "b")
      end
      assert(game.stack:top() == world, "native party menu did not close")
    end
    rows[#rows + 1] = {
      tag = c.tag,
      destination = event.destination,
      nickname = stored.nickname or false,
      eventNickname = eventName or false,
      questions = questions,
      namingScreens = namingCount,
      ballCount = game.save.inventory.MASTER_BALL,
      calls = e.calls() - before,
      result = completed,
    }
  end
  assert(#game.mods.errors == 0)
  print("CATCH_NICKNAME_GPU_RESULT " .. Json.encode({ rows = rows, errors = #game.mods.errors }))
end
