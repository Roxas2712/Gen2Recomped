-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
local C = {}
function C.run(f)
  local T, rows = f.T, {}
  if f.exports.supported ~= nil then
    T.eq(f.exports.supported, true, "completed native link parties are advertised")
  end
  for _, role in ipairs({ "host", "guest" }) do
    for _, outcome in ipairs({ { "win" }, { "lose" }, { "draw" }, { "ended" }, {} }) do
      local result = outcome[1]
      local n = #f.exports.results
      local scene = f.admit(role)
      local before = require("src.mods.Merge").deepCopy(scene.game.save.party)
      T.eq(n, #f.exports.results, "no event during party admission")
      local out = f.complete(scene, result)
      T.eq(#out.results, n + 1, "one completion event per admitted link battle")
      local event = out.results[n + 1]
      T.eq(event.result, result or "ended", "native outcome and absent-result fallback are retained")
      T.eq(event.role, role, "parties use the local participant perspective")
      T.eq(event.peerName, "PEER", "peer identity comes from negotiation")
      T.eq(#event.myParty, 2, "own bench is included")
      T.eq(#event.theirParty, 2, "peer bench is included")
      T.eq(event.myParty[1].hp, 7, "active battle damage survives teardown")
      T.eq(event.myParty[2].hp, 11, "own bench damage survives teardown")
      T.eq(event.theirParty[1].hp, 3, "peer active damage survives teardown")
      T.eq(event.theirParty[2].hp, 13, "peer bench damage survives teardown")
      T.eq(event.myParty[1].moves[1].pp, 1, "own final PP survives teardown")
      T.eq(event.theirParty[2].moves[1].pp, 2, "peer final PP survives teardown")
      T.same(scene.game.save.party, before, "event observes battle copies without damaging the saved party")
      T.eq(out.order[#out.order - 1], "battle", "battle notification precedes link-session end")
      T.eq(out.order[#out.order], "session", "ordinary link-session end is retained")
      T.eq(scene.state.battle, nil, "completed native battle handle is released")
      rows[#rows + 1] = {
        result = event.result, role = event.role, peerName = event.peerName,
        my = { event.myParty[1].hp, event.myParty[2].hp, event.myParty[1].moves[1].pp },
        theirs = { event.theirParty[1].hp, event.theirParty[2].hp, event.theirParty[2].moves[1].pp },
        species = event.myParty[1].species, status = event.myParty[1].status,
      }
    end
  end
  T.eq(#f.run.errors, 0, "completion consumers have no swallowed errors")
  return rows
end
return C
