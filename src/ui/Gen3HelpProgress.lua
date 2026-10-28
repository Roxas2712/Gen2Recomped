-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Declarative FR/LG Help interface facts from pinned pret/pokefirered
-- help_system.c and constants/flags.h, ce6406d8c2eaf46d543c8a2606de0c3cb1951982.
-- Read native save/registry data only; never write progress or run scripts.
local P={}
local limits={44,48,43,7,35}
local groups={
 [1]={
  {true,'1 2 3 5 8 34 38 41 42 43'},
  {0x2CF,'4'},{0x891,'6 10 16 19 22 35 36'},{0x895,'7'},{0x8A4,'11 24'},
  {0x828,'9 13 14 15 17 18 20 26 29 31 37'},{0x829,'21 23'},
  {0x820,'12 25 27 30 32 33'},{'hm','28 40'},{0x29B,'39'},{0x892,'44'}},
 [2]={
  {true,'6 10 11 12 19 20 21 22 23 24 25 26 27 28 29 31 36 38 39 40 41 42 45 46 47'},
  {0x829,'1 30 37'},{'map','14'},{0x828,'2 3 5 7 8 9 13 32 33 35 43 44'},
  {'caught','4 34'},{0x820,'15'},{'hm','16 17'},{0x271,'18'},{0x82C,'48'}},
 [3]={
  {0x828,'1 2 4 5 6 7 8 9 10 11 12 13 16 19 20 21'},
  {0x8A4,'3 15 18 39'},{'hm','36 37'}},
 [4]={{0x820,'5'},{0x821,'6'}},
}
local gates={}
for topic,rows in pairs(groups)do
 gates[topic]={}
 for _,row in ipairs(rows)do for id in row[2]:gmatch('%d+')do
  id=tonumber(id);assert(not gates[topic][id],'duplicate Help gate');gates[topic][id]=row[1]
 end end
end
function P.flag(game,id)
 local value=game.save and game.save.flags and game.save.flags[('FLAG_G3_%04X'):format(id)]
 return value==true or value==1
end
function P.allowed(game,topic,id)
 if not(limits[topic]and type(id)=='number'and id%1==0 and id>=1 and id<=limits[topic])then return false end
 local gate=gates[topic]and gates[topic][id]
 if gate==nil then return topic>=3 end
 if gate==true then return true end
 if type(gate)=='number'then return P.flag(game,gate)end
 if gate=='hm'then
  for _,flag in ipairs{0x237,0x238,0x239,0x23A,0x23B,0x2EF,0x1F1}do if P.flag(game,flag)then return true end end
 elseif gate=='map'then
  local key=game.data.constants.itemOrder and game.data.constants.itemOrder[361]
  return key~=nil and(tonumber((game.save.inventory or{})[key])or 0)>0
 elseif gate=='caught'then
  local unique,count={},0
  for key,owned in pairs(game.save.pokedex and game.save.pokedex.caught or{})do
   local mon=game.data.pokemon and game.data.pokemon[key];local dex=mon and mon.dex
   if (owned==true or owned==1)and type(dex)=='number'and dex>=1 and dex<=151 and not unique[dex]then
    unique[dex]=true;count=count+1;if count>1 then return true end
   end
  end
 end
 return false
end
function P.items(game,facts,context,topic)
 local out,seen={},{}
 local basic=topic==3 and P.flag(game,0x4B0)
 local basics={};if basic then for _,id in ipairs(facts.basicTerms)do basics[id]=true end end
 for _,id in ipairs(facts.contexts[context][topic])do
  if not basics[id]and not seen[id]and P.allowed(game,topic,id)then out[#out+1]=id;seen[id]=true end
 end
 if basic then for _,id in ipairs(facts.basicTerms)do if not seen[id]then out[#out+1]=id;seen[id]=true end end end
 return out
end
return P
