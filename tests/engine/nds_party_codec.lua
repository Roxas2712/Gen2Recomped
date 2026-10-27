package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local P=require('src.link.Protocol');local S=require('src.core.SaveSerializer')
local function copy(v)return assert(S.decode(S.encodeExact(v)))end
for _,version in ipairs({'platinum','black'})do
 local V=require('src.core.GameVersion');V.set(version);local gen=V.generation()
 local data=T.fixtures.fresh();data.constants.gen=gen
 data.constants.natureOrder={};for i=0,24 do data.constants.natureOrder[i+1]='NATURE_'..i end
 for _,d in pairs(data.pokemon)do
  d.baseStats.spatk=d.baseStats.special;d.baseStats.spdef=d.baseStats.special;d.evYield={};d.abilities={'FIRST','SECOND','HIDDEN'};d.genderRatio=127
 end
 T.sdk.loadNone({data=data})
 local mon=require('src.pokemon.Pokemon').new(data,'FIXMON_A',50)
 mon.personality=84;mon.nature=data.constants.natureOrder[gen==5 and 14 or 10];mon.ndsNature=gen==5 and 13 or 9
 mon.gender='female';mon.abilitySlot=gen==5 and 3 or 2;mon.form=0;mon.ot='NATIVE';mon.otId=1234;mon.secretId=60000
 mon.metLocation=500;mon.ndsGame=gen==5 and 21 or 12;mon.ndsRaw=string.rep('\0',136)
 local wire=P.packMon(mon);local restored,why=P.unpackMon(data,wire,{strict=true});assert(restored,why)
 T.eq(restored.personality,84,'DS PID retained '..version)
 T.eq(restored.ndsNature,gen==5 and 13 or 9,'native nature retained '..version)
 T.eq(restored.abilitySlot,gen==5 and 3 or 2,'native ability slot retained '..version)
 T.eq(restored.secretId,60000,'secret trainer identity retained '..version)
 T.eq(restored.metLocation,500,'16-bit met location retained '..version)
 T.eq(restored.ndsRaw,mon.ndsRaw,'binary DS provenance bytes retained through JSON-safe wire '..version)
 local forced=assert(P.unpackMon(data,wire,{strict=true,forceLevel=100}));T.eq(forced.hp,forced.stats.hp,'DS auto-level recomputes native HP '..version)
 T.eq(forced.level,100)
 local poisoned=copy(wire);poisoned.status='TOX'
 T.eq(assert(P.unpackMon(data,poisoned,{strict=true})).status,'TOX','DS toxic status survives native link transfer '..version)
 T.eq(assert(P.unpackMon(data,poisoned,{strict=true,forceLevel=50})).status,nil,'ranked DS copies start healed '..version)
 local bad=copy(wire);bad.evs={hp=255,attack=255,speed=1};T.check(not P.unpackMon(data,bad,{strict=true}),'DS EV overflow refused '..version)
 bad=copy(wire);bad.form=31;T.check(not P.unpackMon(data,bad,{strict=true}),'unknown native form refused '..version)
 bad=copy(wire);bad.ndsRawHex='00';T.check(not P.unpackMon(data,bad,{strict=true}),'truncated source record refused '..version)
 if gen==4 then bad=copy(wire);bad.nature=13;T.check(not P.unpackMon(data,bad,{strict=true}),'Gen 4 PID nature mismatch refused')end
end
T.finish('Native DS party codec')
