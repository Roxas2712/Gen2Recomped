-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Native GBA class actions precede the lower seam; brains select move slots.
local Items=require('src.battle.Gen3TrainerItems')
local Decision=require('src.battle.Gen3TrainerDecision')
local M={}
local function party(battle)
 local out={};for _,group in ipairs({battle.enemyParty or{},battle.enemyPartyB or{}})do
  for _,mon in ipairs(group)do out[#out+1]=mon end
 end;return out
end
function M.action(battle,actor)
 if not(battle.trainer and battle.trainer.aiClass)then return nil end
 local record=require('src.battle.TrainerAI').classFor(battle)
 if not record or(record.kind~=nil and record.kind~='class')then return nil end
 local context=Items.context(battle,actor);if not context then return nil end
 battle.modAiUses=battle.modAiUses or{}
 local left=battle.modAiUses[actor.mon]
 if left==nil then left=tonumber(record.uses)or 0 end
 if left<=0 then return nil end
 local roll=battle.rng(0,255)
 local function switch()
  local held={}
  for _,pos in ipairs({1,3})do local b=battle:battlerAt(pos);if b then held[b.mon]=true end end
  for slot,mon in ipairs(party(battle))do
   if not held[mon]and(tonumber(mon.hp)or 0)>0 and not require('src.pokemon.Party').isEgg(mon)then
    battle.monToSwitchInto=battle.monToSwitchInto or{};battle.monToSwitchInto[context.position]=slot
    return{kind='switch',slot=slot,user='enemy',battler=context.position}
   end
  end
 end
 local function item()
  local key=record.item and Decision.itemKey(battle,record.item)
  return key and Decision.view(battle,actor,Items.stocked(battle,actor,key))or nil
 end
 local action
 if record.switchChance and roll<record.switchChance then action=switch()
 elseif record.onStatus then if actor.mon.status or actor.status or actor.modStatus then action=item()end
 elseif record.chance and roll>=record.chance then action=nil
 elseif record.switch then action=switch()
 elseif record.hpBelow then
  local hp,maxHp=tonumber(actor.mon.hp)or 0,tonumber(actor.mon.stats and actor.mon.stats.hp)or 1
  if hp>=math.floor(maxHp/record.hpBelow)then
   if record.switchBelow and hp<math.floor(maxHp/record.switchBelow)then action=switch()end
  else action=item()end
 else action=item()end
 if action then battle.modAiUses[actor.mon]=left-1 end
 return action
end
local types={NORMAL=0,FIGHTING=1,FLYING=2,POISON=3,GROUND=4,ROCK=5,BUG=6,GHOST=7,STEEL=8,MYSTERY=9,FIRE=10,WATER=11,GRASS=12,ELECTRIC=13,PSYCHIC=14,PSYCHIC_TYPE=14,ICE=15,DRAGON=16,DARK=17}
local function moveView(battle,move)
 local d=battle.data.moves[move.id];if not d then return nil end
 local number=tonumber(d.index or d.numId)
 local id=type(move.id)=='string'and not move.id:match('^MOVE_%d+$')and move.id
  or tostring(d.name or number):upper():gsub('[^%w]+','_'):gsub('^_+',''):gsub('_+$','')
 local kind=tonumber(d.gen3Type)or types[d.type]
 local category=(d.power or 0)==0 and'status'or(kind and kind<=8 and'physical'or'special')
 return{id=id,index=number,num=number,name=d.name,type=d.type,gen3Type=kind,
  power=d.power,accuracy=d.accuracy,pp=d.pp,priority=d.priority or 0,category=d.category or category,
  effect=tonumber(d.gen3Effect)or 0,target=d.target or 0,secondaryChance=d.secondaryChance or 0}
end
function M.brain(battle,actor,bad)
 if battle.kind~='trainer'or actor.isPlayer or not(battle.trainer and battle.trainer.aiClass)then return nil end
 local record=require('src.battle.TrainerAI').classFor(battle)
 if not record or record.kind~='brain'or type(record.brain)~='function'then return nil end
 local rows={}
 for slot=1,4 do
  local move=actor.curMoves[slot]
  if move and battle.data.moves[move.id]then rows[#rows+1]={slot=slot,move=moveView(battle,move),usable=not bad[slot]}end
 end
 local opposite=(actor.position or 1)-1
 local pick=record.brain({battle=battle,user=actor,target=battle:battlerAt(opposite),data=battle.data,rng=battle.rng,moves=rows})
 local slot=type(pick)=='table'and tonumber(pick.slot)or tonumber(pick)
 if not slot or slot%1~=0 or slot<1 or slot>4 or bad[slot]then return nil end
 return actor.curMoves[slot]
end
function M.rows(battle)
 if battle.modAiUses==nil then return nil end
 local out,seen={},{}
 for _,mon in ipairs(party(battle))do
  local left=battle.modAiUses[mon]
  if left~=nil then out[#out+1]={mon=mon,left=left};seen[mon]=true end
 end
 for mon in pairs(battle.modAiUses)do assert(seen[mon],'unknown class-use owner')end
 return out
end
function M.validRows(battle,rows,owned)
 if type(rows)~='table'or not owned[rows]then return false end
 local members,seen={},{}
 for _,mon in ipairs(party(battle))do members[mon]=true end
 local n=0
 for key,row in pairs(rows)do
  n=n+1
  if type(key)~='number'or key%1~=0 or key<1 or key>#rows or type(row)~='table'or not owned[row]
   or not members[row.mon]or seen[row.mon]then return false end
  local left=row.left
  if type(left)~='number'or left%1~=0 or left<0 or left>=math.huge then return false end
  seen[row.mon]=true
 end
 return n==#rows
end
function M.native(rows)
 if rows==nil then return nil end
 local out={};for _,row in ipairs(rows)do out[row.mon]=row.left end;return out
end
return M
