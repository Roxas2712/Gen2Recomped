-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
local F = {}
function F.new(root, version, api, format, noMod)
  local T = require("tests.modkit")
  local V = require("src.core.GameVersion")
  V.set(version)
  local files = {}
  for _, name in ipairs({ "main.lua", "manifest.json" }) do
    local f = assert(io.open(root .. "/examples/portable_link_result/" .. name, "rb"))
    files["mods/portable_link_result/" .. name] = f:read("*a"); f:close()
  end
  local Json = require("src.link.Json")
  local manifest = Json.decode(files["mods/portable_link_result/manifest.json"])
  manifest.api, manifest.callback_format = api or 3, format or "unified"
  files["mods/portable_link_result/manifest.json"] = Json.encode(manifest)
  local data = T.fixtures.fresh()
  if V.generation() == 3 then
    for _, def in pairs(data.pokemon) do
      def.baseStats.spatk, def.baseStats.spdef = def.baseStats.special, def.baseStats.special
      def.evYield = {}
    end
  end
  local run = T.sdk.loadMods(noMod and {} or { "mods/portable_link_result" }, {
    data = data, generation = V.generation(), fs = T.sdk.memfs(noMod and {} or files), dev = false,
  })
  assert(#run.errors == 0, table.concat(run.errors, "\n"))
  require("src.battle.TypeChart").load(data)
  T.link.prepare(data)
  local Protocol = require("src.link.Protocol")
  local State = require("src.link.LinkState")
  local Input = require("src.core.Input")
  local function admission(role)
    local game = T.link.fakeGame(data, { "FIXMON_A", "FIXMON_B" }, { name = "LOCAL", level = 30 })
    local peer = T.link.fakeGame(data, { "FIXMON_B", "FIXMON_A" }, { name = "PEER", level = 30 })
    local net, other = require("src.link.Net").loopbackPair()
    -- Newer reference hosts place their native Session around the same
    -- transport. Use it when present; do not emulate its status/FIFO API.
    local hasSession, Session = pcall(require, "src.link.Session")
    if hasSession then net = Session.new(net, { role = role, kind = "battle" }) end
    local state = State.new(game)
    state.net, state.peerName, state.isHost = net, "PEER", role == "host"
    state.stage, state.verdict, state.linkSeed = "battleWait", "full", 327
    game.stack:push(state)
    other:send({ type = "party", mons = Protocol.packParty(peer.save.party), seed = 327 })
    state:update(1 / 60)
    local battle = assert(state.battle, "ordinary link admission did not retain its battle")
    -- The reference also pushes a short versus card. Let its native owner
    -- return rather than removing a foreign screen from the state stack.
    for _ = 1, 2000 do
      if game.stack:top() == battle then break end
      Input.pressed = { a = true }; game.stack:update(1 / 60)
    end
    assert(game.stack:top() == battle, "native versus card did not finish")
    return { game = game, peer = peer, net = net, other = other, state = state, battle = battle }
  end
  local function complete(scene, result)
    local b = scene.battle
    b.playerParty[1].hp, b.playerParty[2].hp = 7, 11
    b.enemyParty[1].hp, b.enemyParty[2].hp = 3, 13
    b.playerParty[1].moves[1].pp = 1
    b.enemyParty[2].moves[1].pp = 2
    b.playerParty[1].status = "PSN"
    b.result = result
    b:finish()
    for _ = 1, 2000 do
      if scene.game.stack:top() == nil then break end
      Input.pressed = { a = true }; scene.game.stack:update(1 / 60)
    end
    assert(scene.game.stack:top() == nil, "native link session did not finish")
    return run.loader.exports.portable_link_result
  end
  return {
    T = T, run = run, data = data, exports = run.loader.exports.portable_link_result,
    admit = admission, complete = complete,
    close = function() run.release() end,
  }
end
return F
