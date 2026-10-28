-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Native gSentPokesToOpponent has one sent-in mask per opposing flank.
-- Store party indices so logical checkpoints need no extra object aliases.
local M={}
local function active(b)
  return require('src.core.GameVersion').isGen3()and b.isDouble and b:isDouble()
end
local function foeIndex(b,foe)
  for i,mon in ipairs(b:benchFor(false,foe.position))do if mon==foe.mon then return i end end
end
function M.observe(b)
  if not active(b)then return end
  local records=b.gen3ExpParticipants or{};b.gen3ExpParticipants=records
  for _,pos in ipairs{1,3}do
    local foe=b:battlerAt(pos)
    if foe and foe.mon and foe.mon.hp>0 then
      local index=foeIndex(b,foe)
      if index then
        local row=records[pos]
        if not row or row.foeIndex~=index then row={foeIndex=index,players={}};records[pos]=row end
        for _,slot in ipairs{0,2}do
          local actor=b:battlerAt(slot)
          if actor and actor.mon and actor.mon.hp>0 and not actor.ally then
            for i,mon in ipairs(b.game.save.party)do if actor.mon==mon then row.players[i]=true;break end end
          end
        end
      end
    end
  end
end
function M.forFallen(b,foe)
  if not active(b)then return end
  local rows=b.gen3ExpParticipants
  local row=rows and rows[foe.position]
  if not row or row.foeIndex~=foeIndex(b,foe)then return end
  local players={}
  for i in pairs(row.players)do
    local mon=b.game.save.party[i]
    if mon and mon.hp>0 then players[mon]=true end
  end
  return players
end
return M
