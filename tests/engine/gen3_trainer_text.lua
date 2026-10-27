-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local Strings=require('src.core.Strings')
local Controller=require('src.battle.Gen3TrainerController') -- before catalogs load
local Fixture=dofile('tests/charge_required/fixture.lua')
local copy=require('src.mods.Merge').deepCopy
local messages={
 use={'STRINGID_TRAINER1USEDITEM','%s\nused %s!','USE:%s:%s'},
 health={'STRINGID_PKMNSITEMRESTOREDHEALTH',"%s's item\nrestored health!",'HEAL:%s'},
 confusion={'STRINGID_PKMNSITEMSNAPPEDOUT','%s snapped out\nof confusion!','CONFUSION:%s'},
 paralysis={'STRINGID_PKMNSITEMCUREDPARALYSIS','%s was cured\nof paralysis!','PARALYSIS:%s'},
 freeze={'STRINGID_PKMNSITEMDEFROSTEDIT','%s thawed out!','FREEZE:%s'},
 burn={'STRINGID_PKMNSITEMHEALEDBURN',"%s's burn\nwas healed!",'BURN:%s'},
 poison={'STRINGID_PKMNSITEMCUREDPOISON','%s was cured\nof poison!','POISON:%s'},
 sleep={'STRINGID_PKMNSITEMWOKEIT','%s woke up!','SLEEP:%s'},
 focus={'STRINGID_PKMNUSEDXTOGETPUMPED','%s used an item\nto get pumped!','FOCUS:%s'},
 stat={'STRINGID_USINGITEMSTATOFPKMNROSE','Using %s, the %s\nof %s rose!','STAT:%s:%s:%s'},
 mist={'STRINGID_PKMNSHROUDEDINMIST','%s became\nshrouded in MIST!','MIST:%s'},
 pump={'STRINGID_PKMNGETTINGPUMPED','%s is getting\npumped!','PUMP:%s'},
 flee={'_WildFledText','Wild %s\nfled!','FLEE:%s'},
}
local cases={
 {key='health',item=13,name='POTION',bytes={0,0,0,0,4,0,20}},
 {key='confusion',item=800,name='CONFUSION CURE',bytes={0,0,0,1,0,0}},
 {key='paralysis',item=801,name='PARALYSIS CURE',status='PAR',bytes={0,0,0,2,0,0}},
 {key='freeze',item=802,name='FREEZE CURE',status='FRZ',bytes={0,0,0,4,0,0}},
 {key='burn',item=803,name='BURN CURE',status='BRN',bytes={0,0,0,8,0,0}},
 {key='poison',item=804,name='POISON CURE',status='PSN',bytes={0,0,0,16,0,0}},
 {key='sleep',item=805,name='SLEEP CURE',status='SLP',bytes={0,0,0,32,0,0}},
 {key='focus',item=806,name='DIRE HIT',bytes={16,0,0,0,0,0}},
 {key='stat',item=807,name='X ATTACK',bytes={1,0,0,0,0,0}},
 {key='mist',item=808,name='GUARD SPEC',bytes={0,0,0,128,0,0}},
 {key='pump',item=808,name='GUARD SPEC',double=true,bytes={0,0,0,128,0,0}},
 {key='flee',item=13,name='POTION',run=true,bytes={0,0,0,0,4,0,20}},
 {key='health',item=13,name='POTION',rom=true,bytes={0,0,0,0,4,0,20}},
}
for _,edition in ipairs({'firered','leafgreen','ruby','sapphire','emerald'})do
 for _,tag in ipairs({'FIRST','RELOADED',false})do
  local f=Fixture.new('.','gen2',edition,3,'unified',false,false,'portable_enemy_action',function(data)
   data.items={};data.strings={};data.constants.generation=3;data.constants.gen3ItemEffects={}
   for _,case in ipairs(cases)do
    local key=('ITEM_%03d'):format(case.item)
    data.items[key]={id=key,index=case.item,name=case.name}
    data.constants.gen3ItemEffects[key]={bytes=case.bytes}
   end
  end,function(files)
   local entry={'return function(mod)','local running=false','mod.exports.api=mod',
    'mod.exports.run=function(value)running=value end',
    "mod.hooks:wrap('battle.enemy_switch_or_item',function(next,battle) local chosen=next(battle); if running and type(chosen)=='table'then chosen.kind='run' end; return chosen end)"}
   if tag then
    for _,message in pairs(messages)do
     entry[#entry+1]=('assert(mod.content.strings:override(%q,%q))'):format(message[2],tag..':'..message[3])
    end
    entry[#entry+1]=('assert(mod.content.strings:override(%q,%q))'):format('Enemy %s',tag..':ENEMY:%s')
    entry[#entry+1]=('assert(mod.content.strings:override(%q,%q))'):format('ATTACK',tag..':ATTACK')
   end
   entry[#entry+1]='end';files['mods/portable_enemy_action/main.lua']=table.concat(entry,'\n')
  end)
  Strings.load(f.data)
  local function translated(key,...)
   local row=messages[key];return string.format(tag and tag..':'..row[3]or row[2],...)
  end
  for _,case in ipairs(cases)do
   for _,message in pairs(messages)do f.data.text[message[1]]=nil end
   local b=f.fresh('TACKLE').battle
   local key=('ITEM_%03d'):format(case.item)
   b.kind,b.trainer,b.enemyParty='trainer',{name='TEXT TRAINER',items={key}},{b.enemy.mon}
   b:syncSides()
   if case.double then
    local players={b.player.mon,copy(b.player.mon)}
    f.game.save.party,b.playerParty,b.playerPartyIndices=players,players,{1,2}
    b.enemyParty[2]=copy(b.enemy.mon);b.double=true;b:sendOutSecondPair()
   end
   local actor=b:battlerAt(case.double and 3 or 1)
   actor.mon.hp,actor.mon.stats.hp,actor.turnsOut=10,400,0
   actor.mon.status=case.status
   if case.key=='confusion'then actor.confusedTurns=5 end
   f.e.run(case.run or false)
   if case.rom then
    f.data.text[messages.use[1]]='ROM {TRAINER}/{ITEM}'
    f.data.text[messages.health[1]]='ROM {USER}'
   end
   local action=b:enemyAction(actor)
   T.check(action and action.gen3TrainerAction,'actual public lower seam selects an action')
   T.eq(action and action.gen3TrainerPosition,case.double and 3 or 1,'text remains with its actual controller')
   T.eq(require('src.battle.Gen3TrainerItems').history(b).slots[1].spent,true,'selection spends actual item stock')
   b.queue,b.nextInsert={},0
   b:executeAction(actor,b.player,action)
   local lines={};for _,row in ipairs(b.queue)do if row.text then lines[#lines+1]=row.text end end
   local who=tag and tag..':ENEMY:'..actor.name or'Enemy '..actor.name
   if case.run then
    T.same(lines,{translated('flee',actor.name)},'queued original run uses the live catalog')
    T.eq(b.result,'run','translated flee still ends the native controller action')
   else
    local first=case.rom and'ROM TEXT TRAINER/'..case.name or translated('use','TEXT TRAINER',case.name)
    local second=case.rom and'ROM '..who
      or case.key=='stat'and translated('stat',case.name,tag and tag..':ATTACK'or'ATTACK',who)
      or translated(case.key,who)
    T.same(lines,{first,second},'actual controller uses current catalog or native ROM precedence: '..case.key)
   end
  end
  f.close();Strings.load({})
 end
end
T.finish('native GBA trainer prose through public translation mods and ROM labels')
