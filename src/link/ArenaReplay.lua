-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Operator-side reconstruction. No client damage, stats or RNG state is used.
local Replay = {}
local function integer(v, lo, hi)
  return type(v) == 'number' and v % 1 == 0 and v >= lo and v <= hi
end
local function stream(rows)
  assert(type(rows) == 'table' and #rows <= 40000, 'Invalid transcript')
  local out = { actions = {}, batons = {}, hashes = {} }
  for i, row in ipairs(rows) do
    assert(row.sequence == i and type(row.body) == 'table', 'Transcript sequence is incomplete')
    local m = row.body
    if m.type == 'action' then out.actions[#out.actions + 1] = m
    elseif m.type == 'baton_pass' then out.batons[#out.batons + 1] = m
    elseif m.type == 'hash' then
      assert(integer(m.turn, 1, 10000) and not out.hashes[m.turn], 'Duplicate or invalid turn hash')
      out.hashes[m.turn] = m
    elseif m.type == 'forfeit' then error('Clock forfeits require a server-owned clock')
    elseif m.type ~= 'hello' and m.type ~= 'start_battle' and m.type ~= 'party'
      and m.type ~= 'battle_start' and m.type ~= 'bye' and m.type ~= 'ready' then
      error('Unsupported transcript message: ' .. tostring(m.type))
    end
  end
  return out
end
Replay.stream=stream
function Replay.run(game, job)
  assert(job.schema == 1 and integer(job.seed, 1, 1073741824), 'Invalid replay seed')
  assert(type(job.teams) == 'table' and #job.teams == 2, 'Replay needs exactly two teams')
  local host, guest = job.teams[1], job.teams[2]
  assert(host.account ~= guest.account, 'Self battle')
  local fingerprint = require('src.link.Handshake').hello(game, 'battle').fingerprint
  assert(host.fingerprint == fingerprint and guest.fingerprint == fingerprint, 'Server native data differs from the selected teams')
  local hs, gs = stream(host.messages), stream(guest.messages)
  assert(#hs.actions <= 10000 and #gs.actions <= 10000, 'Too many turns')
  local proof, battle
  local net = { update = function() end, poll = function() return {} end, send = function() end, close = function() end }
  battle = assert(require('src.link.LinkBattle').newHost(game, net, {
    myParty = host.party, theirParty = guest.party, seed = job.seed, forceLevel = job.level,
    strict = true, verdict = 'full', replay = true, theirName = 'RIVAL',
    onFinished = function(result) proof = result end,
  }))
  game.stack:push(battle)
  local nextTurn, hb, gb = 1, 1, 1
  for _ = 1, 2000000 do
    if proof then break end
    local input = game.input
    input.pressed = { a = battle.phase == 'messages' }
    if battle.phase == 'menu' and not battle.result then
      assert(hs.actions[nextTurn] and gs.actions[nextTurn], 'Transcript ended before the battle')
      battle:replayTurn(hs.actions[nextTurn], gs.actions[nextTurn])
      nextTurn = nextTurn + 1
    end
    for _, side in ipairs({ {hs, 'host'}, {gs, 'guest'} }) do
      local n = side[2] == 'host' and hb or gb
      local packet = side[1].batons[n]
      if packet and packet.turn == (battle.turnCount or 0) then
        assert(packet.actor == side[2], 'Baton choice belongs to another player')
        assert(require('src.link.Gen3BatonChoice').receive(battle, packet, side[2]), 'Invalid Baton Pass choice')
        if side[2] == 'host' then hb = hb + 1 else gb = gb + 1 end
      end
    end
    game.stack:update(1 / 60)
  end
  assert(proof and (proof.result == 'win' or proof.result == 'lose'), 'Replay did not finish with a winner')
  assert(nextTurn - 1 == #hs.actions and nextTurn - 1 == #gs.actions, 'Transcript has actions after the battle')
  assert(hb > #hs.batons and gb > #gs.batons, 'Unused Baton Pass choices')
  for turn = 1, proof.turns do
    for _, s in ipairs({hs, gs}) do
      local packet, parts = s.hashes[turn], battle.localParts[turn]
      -- Final KOs finish before emitting the last hash. Earlier turns must
      -- agree with the independent reconstruction, not merely each other.
      if parts and (turn < proof.turns or packet) then
        assert(packet and packet.value == battle.localHashes[turn] and type(packet.parts) == 'table'
          and packet.parts.actives == parts.actives and packet.parts.bench == parts.bench, 'Native replay diverged at turn ' .. turn)
      end
    end
  end
  return {winner = proof.result == 'win' and host.account or guest.account,
    turns = proof.turns, digest = proof.digest, status = 'complete'}
end
return Replay
