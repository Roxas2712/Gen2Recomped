-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Registered public brains in actual controllers; no direct move-view calls.
local C={}
function C.run(root,backend,edition,mode)
 local input=dofile(root..'/tests/gen3_trainer_types/imported.lua')
 local T=require('tests.modkit');local rows={}
 for _,encoding in ipairs(input.encodings)do
  local originals
  local f=dofile(root..'/tests/charge_required/fixture.lua').new(root,backend,edition,3,'unified',false,false,'portable_enemy_action',function(data,_,_,rom,names)
   if backend=='gen1'then
    for _,row in ipairs(input.records())do
     rom[row.number]={effect=0,power=row.power,type=row.kind,accuracy=95,pp=10,
      priority=row.priority,secondaryChance=15,target=0,flags=51}
     data.gen3Moves._rom[row.number]=rom[row.number]
     names[row.number]=row.name;data.gen3Pokemon._moveNames[row.number]=row.name
    end
   else
    local imported,constants=input.import(encoding)
    data.constants.types,data.constants.typeOrder=constants.types,constants.typeOrder
    for key,def in pairs(imported)do data.moves[key]=def end
    originals=require('src.mods.Merge').deepCopy(imported)
   end
  end,function(files)
   files['mods/portable_enemy_action/main.lua']=[[
return function(mod)
 mod.exports.calls=0
 assert(mod.content.ai_classes:register('TYPE_BRAIN',{kind='brain',brain=function(ctx)
  mod.exports.calls=mod.exports.calls+1;mod.exports.views=ctx.moves
  for _,row in ipairs(ctx.moves)do if row.usable and row.move.category=='physical'then return row.slot end end
  for _,row in ipairs(ctx.moves)do if row.usable and row.move.category=='status'then return row.slot end end
  for _,row in ipairs(ctx.moves)do if row.usable then return row.slot end end
 end}))
end
]]
  end)
  local State,Commands,registry,previous
  if backend=='gen1'then
   State,Commands=require('src.core.game3.battle.state'),require('src.core.game3.battle.commands')
   registry=require('src.core.game3.battle.mod_registries');previous=registry.data();registry.bind(f.data)
  end
  local copy=require('src.mods.Merge').deepCopy
  local records=input.records()
  for first=1,#records+1,4 do
   local b=f.fresh('TACKLE').battle
   local party={b.enemy.mon,copy(b.enemy.mon),copy(b.enemy.mon)}
   local players={b.player.mon,copy(b.player.mon)}
   local two=mode:find('two-trainer',1,true)~=nil
   if backend=='gen1'then
    if mode~='single'then b=State.new({wild=false,double=true,playerParty=players,foeParty=party,foeHalf=two and 1 or nil})end
    b.wild,b.foeParty,b.trainerItems,b.aiClass=false,party,{},'TYPE_BRAIN'
   else
    b.kind,b.enemyParty,b.trainer='trainer',two and{party[1]}or party,{name='TYPE BRAIN',items={},aiClass='TYPE_BRAIN'}
    b:syncSides()
    if mode~='single'then
     f.game.save.party,b.playerParty,b.playerPartyIndices=players,players,{1,2};b.double=true;b:sendOutSecondPair()
     if two then
      f.data.trainers.TYPE_SECOND={name='SECOND',items={},parties={{{prebuilt=copy(party[2])},{prebuilt=copy(party[3])}}}}
      T.check(b:addOpponentTrainer('TYPE_SECOND'),'native second trainer admitted')
     end
    end
   end
   local position=mode:find('right',1,true)and 3 or 1
   if mode:find('empty-left',1,true)then
    if backend=='gen1'then b.battlers[1]=nil;b.absent=b.absent or{};b.absent[1]=true
    else b:placeBattler(1,nil);b:syncSides()end
   end
   local actor
   if backend=='gen1'then actor=State.battler(b,position)else actor=b:battlerAt(position)end
   local nums,moves,pp={},{},{}
   local blocked=first<=#records and first%8==5
   local batch={}
   if first>#records then batch={records[2],records[14],records[15],records[1]}
   else for at=first,math.min(first+3,#records)do batch[#batch+1]=records[at]end end
   for _,record in ipairs(batch)do
    local slot=#nums+1;local num=record.number;local amount=blocked and slot==1 and 0 or 10
    nums[slot],moves[slot],pp[slot]=num,{id=('MOVE_%03d'):format(num),pp=amount},amount
   end
   if backend=='gen1'then actor.mon.moves,actor.mon.pp,actor.mon.maxPp=nums,pp,{10,10,10,10}
   else actor.mon.moves,actor.curMoves=moves,moves end
   actor.mon.hp,actor.mon.maxHp=400,400;actor.mon.stats=actor.mon.stats or{};actor.mon.stats.hp=400
   -- No spare living party member: default switch policy is outside this contract.
   for _,group in ipairs({b.foeParty or{},b.enemyParty or{},b.enemyPartyB or{}})do
    for _,mon in ipairs(group)do if mon~=actor.mon then mon.hp=0 end end
   end
   b.rng=function(lo)return lo or 0 end
   f.e.calls,f.e.views=0,nil
   local action
   if backend=='gen1'then action=Commands.enemyAction(b,position)else action=b:enemyAction(actor)end
   T.eq(f.e.calls,1,'exactly one actual registered brain call')
   T.eq(type(f.e.views),'table','actual controller supplies move views')
   local chosen=backend=='gen1'and action.move or action.id and f.data.moves[action.id].index
   rows[#rows+1]={encoding=encoding,first=first,numbers=nums,blocked=blocked,chosen=chosen,moves=f.e.views}
  end
  if originals then
   for key,old in pairs(originals)do T.same(f.data.moves[key],old,'move views retain importer-owned records')end
  end
  if registry then registry.bind(previous)end
  f.close()
 end
 return rows
end
return C
