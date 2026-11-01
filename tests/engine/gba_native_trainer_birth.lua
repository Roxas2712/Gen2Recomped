-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Authored ROM bytes through the real importer, then the real native party
-- constructor and public six-argument Pokemon.new boundary. No game assets.
package.path='./?.lua;./?/init.lua;'..package.path
love=require('tests.love_stub')
local T=require('tests.harness')
local E=require('src.import.RomExtractorGen3')
local Birth=require('src.pokemon.Gen3TrainerBirth')
local Cache=require('src.import.Gen3TrainerBirth')
local Fixture=require('tests.checkpoint_fixture')
local Native=require('src.battle.BattleState')
local Pokemon=require('src.pokemon.Pokemon')
local Stats=require('src.pokemon.Stats')
local Serialize=require('src.core.SaveSerializer')
local function imported(version)
  local bytes={}
  for n=1,0x3000 do bytes[n]=0 end
  local function u8(at,value)bytes[at+1]=value end
  local function u16(at,value)u8(at,value%256);u8(at+1,math.floor(value/256))end
  local function u32(at,value)for n=0,3 do u8(at+n,math.floor(value/256^n)%256)end end
  local function name(at,a,b)u8(at,a);u8(at+1,b);u8(at+2,255)end
  name(0x1000+11,201,202);name(0x1000+22,203,204)
  for index=0,3 do
    local at=0x100+index*40;local party=0x2000+index*0x100
    u8(at,index);u8(at+1,1);u8(at+2,index%2==1 and 128 or 0)
    u8(at+24,index==3 and 1 or 0);name(at+4,187+index,197)
    u8(at+32,2);u32(at+36,0x08000000+party)
    local stride=index%2==1 and 16 or 8
    for slot=0,1 do
      local p=party+slot*stride
      u16(p,slot==0 and ({0,64,128,255})[index+1] or 100)
      u16(p+2,20+index);u16(p+4,slot+1)
      if index>=2 then u16(p+6,1)end
      if index%2==1 then
        local offset=index>=2 and 8 or 6
        u16(p+offset,1);u16(p+offset+2,2)
      end
    end
  end
  local chunks={};for n,v in ipairs(bytes)do chunks[n]=string.char(v)end
  local owner=setmetatable({version=version,
    rom=require('src.import.RomGba').new(table.concat(chunks)),
    _speciesIds={[1]='FIXMON_A',[2]='FIXMON_B'},
    _moveIds={[1]='FIX_TACKLE',[2]='FIX_SCRATCH'},
    _constants={itemOrder={[1]='FIX_POTION'}}},E)
  function owner:beginStage()end
  function owner:need(key)return ({gTrainers=0x100,gSpeciesNames=0x1000})[key]end
  function owner:layoutValue(key,default)return key=='numTrainers'and 4 or default end
  function owner:partyStrides()return {[0]=8,[1]=16,[2]=8,[3]=16}end
  function owner:readString()return 'TRANSLATED DISPLAY'end
  function owner:tick()end
  function owner:write()end
  owner:extractTrainers()
  local rows={};for _,r in pairs(owner._trainers)do rows[r.index+1]=r end
  return owner,rows
end
local keys={'hp','attack','defense','speed','spatk','spdef'}
for _,version in ipairs{'ruby','sapphire','emerald','firered','leafgreen'}do
  local owner,rows=imported(version)
  T.check(Cache.valid(version,owner._constants,owner._trainers),version..' actual importer writes complete recipe')
  for index,row in ipairs(rows)do
    local base=index==4 and 128 or index%2==0 and 120 or 136
    local firstHash=186+index+197+201+202
    local secondHash=firstHash+186+index+197+203+204
    T.eq(row.party[1].nativeTrainerBirth.personality,base+firstHash*256,'first original encoded-name PID')
    T.eq(row.party[2].nativeTrainerBirth.personality,base+secondHash*256,'cumulative hash adds trainer name again')
    T.eq(row.party[1].nativeTrainerBirth.fixedIV,({0,7,15,31})[index],'original IV scaling endpoints and intermediate values')
    T.eq(row.party[2].nativeTrainerBirth.fixedIV,12,'second original IV scaling')
    T.eq(row.party[1].item,index>=3 and 'FIX_POTION'or nil,'all four party layouts retain item position')
    T.same(row.party[1].moves,index%2==0 and {'FIX_TACKLE','FIX_SCRATCH'}or nil,'all four party layouts retain move position')
  end
  local saved=rows[1].party[1].nativeTrainerBirth
  rows[1].party[1].nativeTrainerBirth=nil
  T.eq(Cache.valid(version,owner._constants,owner._trainers),false,'old incomplete cache requires upgrade')
  rows[1].party[1].nativeTrainerBirth=saved
  local wrong=version=='ruby'and 'sapphire'or 'ruby'
  T.eq(Cache.valid(wrong,owner._constants,owner._trainers),false,'cross-edition trainer cache rejected')
  for _,policy in ipairs{{1,'native'},{2,'native'},{2,'unified'},{3,'unified'}}do
    local f=Fixture.boot(version,policy[1],policy[2]);local game=f.game
    game.data.constants.gen3TrainerBirth=owner._constants.gen3TrainerBirth
    local natures={};game.data.constants.natureOrder={}
    for n=0,24 do
      local name='NATURE_'..n;game.data.constants.natureOrder[n+1]=name
      natures[name]={modifiers={attack=n%2==0 and 110 or 90,spatk=n%2==0 and 90 or 110}}
    end
    for _,id in ipairs{'FIXMON_A','FIXMON_B'}do
      local def=game.data.pokemon[id]
      def.evYield={hp=0};def.baseStats={hp=55,attack=80,defense=70,speed=65,spatk=90,spdef=60}
      def.abilities={'FIRST','SECOND'};def.genderRatio=127
    end
    Stats.withNatures(natures,function()
      local oldNew,oldRandom=Pokemon.new,love.math.random
      local calls,rolls=0,0
      Pokemon.new=function(a,b,c,d,e,opts)
        calls=calls+1;T.check(opts and opts.gen3TrainerBirth,'six-argument mod wrapper receives native birth')
        return oldNew(a,b,c,d,e,opts)
      end
      love.math.random=function(a,b)
        T.eq(a,0,'only random OT halves are rolled');T.eq(b,65535,'OT random half range')
        rolls=rolls+1;return rolls%2==1 and 12345 or 54321
      end
      local before=Serialize.encode(game.save)
      for _,row in ipairs(rows)do
        local party=Native.buildTrainerParty(game,row.id,1,row.party)
        for i,mon in ipairs(party)do
          local slot=row.party[i];local recipe=slot.nativeTrainerBirth
          T.eq(mon.personality,recipe.personality,'actual native builder retains original trainer PID')
          T.eq(mon.nature,'NATURE_'..(recipe.personality%25),'nature comes from native fixed PID')
          T.eq(mon.abilitySlot,1,'even trainer PID selects original first ability')
          T.eq(Pokemon.genderOf(game.data,mon),recipe.personality%256<127 and 'female'or 'male',
            'native gender uses fixed personality threshold')
          T.eq(Pokemon.isShiny(mon),false,'random native OT excludes original shininess')
          T.eq(mon.item,slot.item,'native builder retains original held item')
          T.eq(mon.hp,mon.stats.hp,'new opponent starts at computed full HP')
          for _,key in ipairs(keys)do
            T.eq(mon.ivs[key],recipe.fixedIV,'all six original fixed IVs')
            T.eq(mon.evs[key],0,'new trainer has zero original EVs')
            local core=math.floor((2*game.data.pokemon[mon.species].baseStats[key]+recipe.fixedIV)*slot.level/100)
            local expected=key=='hp'and core+slot.level+10
              or math.floor((core+5)*(natures[mon.nature].modifiers[key]or 100)/100)
            T.eq(mon.stats[key],expected,'independent original stat formula includes nature last')
          end
          if slot.moves then T.eq(mon.moves[1].id,'FIX_TACKLE','custom move preserved');T.eq(mon.moves[2].id,'FIX_SCRATCH','second custom move preserved')end
        end
      end
      T.eq(calls,8,'exactly one public construction per party member')
      T.eq(rolls,16,'fixed genes consume two OT rolls per member only')
      T.eq(Serialize.encode(game.save),before,'trainer construction leaves complete player save unchanged')
      Pokemon.new,love.math.random=oldNew,oldRandom
      local slot=rows[1].party[1]
      slot.stats={hp=321,attack=123}
      local mon=Native.buildTrainerParty(game,rows[1].id,1,{slot})[1]
      T.same(mon.stats,slot.stats,'authored stat block wins');T.check(mon.stats~=slot.stats,'authored stats are copied')
      slot.stats=nil;slot.dvs={attack=1,defense=2,speed=3,special=4}
      T.eq(Birth.forSlot(game.data,slot),nil,'authored genes retain existing constructor path');slot.dvs=nil
      local prebuilt={species='FIXMON_A',hp=77}
      T.eq(Native.buildTrainerParty(game,rows[1].id,1,{{prebuilt=prebuilt}})[1],prebuilt,'facility/prebuilt individual handed through unchanged')
      game.data.trainers[rows[1].id]=rows[1]
      local hooks=0
      local off=f.loaded.loader.exports.checkpoint_fixture.api.hooks:wrap('trainer.party',function(next,class,index,party)
        hooks=hooks+1
        T.eq(class,rows[1].id,'real trainer.party hook sees native trainer')
        return next(class,index,{party[2]})
      end)
      local battle=Native.newTrainer(game,rows[1].id,1)
      T.eq(hooks,1,'real native battle still calls registered trainer.party hook')
      T.eq(#battle.enemyParty,1,'mod-selected trainer party is retained')
      T.eq(battle.enemyParty[1].personality,rows[1].party[2].nativeTrainerBirth.personality,
        'mod selection carries its original imported individual')
      off()
    end)
    f.close()
  end
end
-- Original NO_SHINY OT retry is observable without spending PID/IV rolls.
local values={136,0,12,34};local n=0
local seed=Birth.seed({constants={}}, {}, {version='emerald',personality=136,fixedIV=31},function()
  n=n+1;return values[n]
end)
T.eq(n,4,'shiny OT pair is rejected and only the OT is rerolled')
T.eq(seed.otId,12+34*65536,'non-shiny second OT is retained')
T.eq(seed.personality,136,'OT retry leaves fixed personality unchanged')
T.finish('original GBA trainer birth across five editions and public constructor boundaries')
