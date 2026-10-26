-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path = "./?.lua;./?/init.lua;" .. package.path
local F = dofile("tests/link_result/fixture.lua")
local T = require("tests.modkit")
for _, version in ipairs({ "red", "blue", "yellow", "gold", "silver", "crystal", "firered", "leafgreen", "emerald", "ruby", "sapphire" }) do
  local f = F.new(".", version, 3, "unified")
  T.check(require("src.mods.Runtime").wants("link.battle_ended"), "public example installs its completion listener")
  T.check(require("src.mods.Runtime").wants("link.ended"), "public example retains session-end observation")
  dofile("tests/link_result/cases.lua").run(f)
  f.close()
end
for _, mode in ipairs({ { 1, "native" }, { 2, "native" }, { 2, "unified" }, { 3, "unified" } }) do
  local api, format = mode[1], mode[2]
  local f = F.new(".", "red", api, format)
  local scene = f.admit("host")
  local out = f.complete(scene, "win")
  local event = out.results[1]
  if format == "native" then
    T.eq(event.myParty, scene.battle.playerParty, "native callbacks retain the actual disposable own party")
    T.eq(event.theirParty, scene.battle.enemyParty, "native callbacks retain the actual disposable peer party")
  else
    T.neq(event.myParty, scene.battle.playerParty, "unified callbacks receive detached parties")
    T.neq(event.myParty[1], scene.battle.playerParty[1], "unified Pokemon records are detached")
    T.eq(event.myParty[1].status, "PSN", "the additive unified event shares the reference's short status")
    T.eq(event.myParty[1].maxHp, scene.battle.playerParty[1].stats.hp, "unified event exposes the portable maximum HP field")
    event.myParty[1].hp, event.myParty[1].moves[1].pp = -100, -100
    T.eq(scene.battle.playerParty[1].hp, 7, "notification edits do not write native battle health")
    T.eq(scene.battle.playerParty[1].moves[1].pp, 1, "notification edits do not write native battle PP")
  end
  local count = #out.results
  out.off()
  local nextScene = f.admit("guest")
  f.complete(nextScene, "draw")
  T.eq(#out.results, count, "unsubscribe removes only the completion listener")
  T.eq(out.order[#out.order], "session", "session listener survives completion unsubscribe")
  f.close()
end
local none = F.new(".", "red", 3, "unified", true)
local scene = none.admit("guest")
local before = require("src.mods.Merge").deepCopy(scene.game.save.party)
none.complete(scene, "draw")
T.same(scene.game.save.party, before, "no-mod link completion preserves the adventure party")
T.eq(scene.state.battle, nil, "no-mod native battle handle is released")
none.close()
local detached = F.new(".", "red", 3, "unified")
local api = detached.run.loader.apis.portable_link_result
local once = 0
api.events:once("link.battle_ended", function(ctx)
  once = once + 1
  ctx.myParty[1].hp = -99
  ctx.theirParty[1].moves[1].pp = -99
  ctx.myParty[1].native.hp = -99
end, 50)
for _ = 1, 2 do
  local scene = detached.admit("host")
  local out = detached.complete(scene, "win")
  local event = out.results[#out.results]
  T.eq(event.myParty[1].hp, 7, "each listener receives its own detached health record")
  T.eq(event.theirParty[1].moves[1].pp, scene.battle.enemyParty[1].moves[1].pp, "listener PP edits do not leak into peers")
  T.eq(scene.battle.playerParty[1].hp, 7, "native-copy edits cannot change the battle party")
end
T.eq(once, 1, "once listener retires before the next battle")
detached.run.loader.events:removeOwner("portable_link_result")
T.eq(require("src.mods.Runtime").wants("link.battle_ended"), false, "owner removal retires completion subscriptions")
detached.close()
T.finish("native link-battle completion")
