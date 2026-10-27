love=require('tests.love_stub')
local M=require('src.world.Gen3RsEncounterRules')
local S=require('src.core.SaveSerializer')
local n=0
local function check(v,why)n=n+1;assert(v,why)end
local version='sapphire';package.loaded['src.core.GameVersion']={get=function()return version end}
for _,v in ipairs({'ruby','sapphire','leafgreen','firered','emerald','gold','silver','crystal','red'})do
  version=v;check(M.active()==(v=='ruby'or v=='sapphire'),'Edition isolation')
end
local behavior=0
local w={player={cellX=2,cellY=3},map={cellBehaviour=function()return behavior end}}
M.restart(w,true)
check(not M.begin(w)and w.rsEncounterImmunity==0,'Idle polling cannot consume immunity')
for i=1,4 do
  behavior=i;M.stepped(w);check(not M.begin(w)and w.rsEncounterImmunity==i,'Four protected completed checks')
  check(not M.begin(w)and w.rsEncounterImmunity==i,'Duplicate polling does not consume another check')
end
behavior=7;M.stepped(w);check(M.begin(w)and w.rsEncounterPrior==4,'Fifth check remembers actual previous metatile')
check(not M.begin(w),'One roll per completed step')
M.restart(w);check(w.rsEncounterImmunity==0 and w.rsEncounterPrevious==7,'Map/battle restart retains previous metatile')
check(not M.begin(w),'Restart itself is not a new step')
for i=1,4 do M.stepped(w);check(not M.begin(w),'Restart protects four new checks')end
M.stepped(w);check(M.begin(w),'Restart permits fifth')
local data={pokemon={LEAD={abilities={'STENCH','ILLUMINATE'}},OTHER={abilities={'ARENA_TRAP'}}}}
local save={party={{species='LEAD',abilitySlot=1}}}
local function adjusted(base,cycle)
  local mod=M.rateMod(data,save,base,cycle)
  return mod and math.floor(base*16*mod[1]/mod[2])or base*16
end
check(adjusted(20)==160,'RS Stench halves')
save.party[1].abilitySlot=2;check(adjusted(20)==640,'RS Illuminate doubles')
save.party[1].isEgg=true;check(adjusted(20)==320,'Egg lead has no field ability')
save.party[1].isEgg=nil;save.party[1].species='OTHER'
check(adjusted(20)==320,'Emerald Arena Trap effect must not leak into RS')
check(adjusted(21,true)==268,'Bicycle rounds after native times16 conversion')
save.gen3Flute='white';check(adjusted(21,true)==402,'White Flute follows bike rounding')
save.party[1].item='CLEANSE_TAG';check(adjusted(21,true)==268,'Held lead Cleanse Tag follows flute')
save.party[1].species='LEAD';save.party[1].abilitySlot=1
check(adjusted(21,true)==134,'Ability is applied after Cleanse Tag')
save.gen3Flute='black';check(adjusted(21,true)==44,'Black Flute, Tag and Stench integer order')
save.party[1].abilitySlot=2;save.gen3Flute='white';save.party[1].item=nil
check(adjusted(255)==2880,'Native maximum rate cap')
save.party={{species='OTHER'},{species='LEAD',abilitySlot=2,item='CLEANSE_TAG'}};save.gen3Flute=nil
check(adjusted(20)==320,'Only party slot one affects the rate')
save.party[1].item='CLEANSE_TAG';save.party[1].hp=0
check(adjusted(20)==213,'Fainted lead still carries its original field item')
local def={grass={rate=21,rateMax=180,slots={{species='NUMEL',min=15,max=16}},buckets={100},bucketSpan=100}}
local before=S.encode(def)
local function rng(values,trace)
  local i=0
  return function(lo,hi)i=i+1;trace[#trace+1]={lo,hi};local v=assert(values[i],'Unexpected RNG call');assert(v>=lo and v<=hi);return v end
end
local trace={};check(M.roll(def,rng({60},trace),nil,nil,1,2)==nil and #trace==1,'Transition 60 rejects before rate/slot RNG')
trace={};local mon=M.roll(def,rng({59,335,0,16},trace),nil,nil,1,2)
check(mon and mon.species=='NUMEL'and mon.level==16,'Transition59, native rate335, slot and actual level')
check(trace[2][1]==0 and trace[2][2]==2879,'Original 2880-point rate denominator')
trace={};check(M.roll(def,rng({336},trace),nil,nil,2,2)==nil and #trace==1,'Same-metatile rate threshold336 rejects without transition RNG')
trace={};mon=M.roll(def,rng({267,0,15},trace),{268,336},nil,2,2)
check(mon and mon.level==15,'Native bike rate267 passes')
trace={};check(M.roll(def,rng({268},trace),{268,336},nil,2,2)==nil,'Native bike rate268 rejects')
trace={};mon=M.roll(def,rng({159,0,15},trace),nil,10,2,2)
check(mon and trace[1][2]==2879,'Public hook rate override retains imported units')
trace={};check(M.roll({grass={rate=0}},rng({},trace),nil,nil,1,2)==nil and #trace==0,'No eligible table/rate spends no RNG')
check(S.encode(def)==before,'Rate/slot view never rewrites imported data')
print('RS_ENCOUNTER_RULE_CHECKS',n)
