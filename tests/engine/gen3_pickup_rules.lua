-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit');local V=require('src.core.GameVersion')
local Pickup=require('src.pokemon.Gen3Pickup');local S=require('src.core.SaveSerializer')
local function fixture(edition)
 V.set(edition)
 local items={};for i=1,300 do items['ITEM_'..i]={index=i}end
 local data={items=items,pokemon={FINDER={abilities={'PICKUP'}},OTHER={abilities={'RUN AWAY','PICKUP'}}},constants={}}
 local r={schema=1,edition=edition,romSha1=V.info(edition).sha1,style=edition=='emerald'and'level'or'fixed'}
 if r.style=='fixed'then
  r.items={};for i=1,((edition=='firered'or edition=='leafgreen')and 16 or 10)do r.items[i]=i end
  r.thresholds=(edition=='firered'or edition=='leafgreen')and{15,25,35,45,55,65,75,80,85,90,95,96,97,98,99}
    or{30,40,50,60,70,80,90,95,99}
 else
  r.common={};r.rare={};for i=1,18 do r.common[i]=i end;for i=1,11 do r.rare[i]=100+i end
  r.thresholds={30,40,50,60,70,80,90,94,98}
  r.pyramid={level50={},open={},thresholds={30,40,50,60,70,80,85,90,95,100}}
  for i=1,200 do r.pyramid.level50[i]=i;r.pyramid.open[i]=i+100 end
 end
 data.constants.gen3Pickup=r
 local mon={species='FINDER',level=1,hp=0,abilitySlot=1}
 local save={party={mon}};local calls={}
 local b={data=data,game={save=save},result='win',kind='wild',rng=function(lo,hi)
  calls[#calls+1]={lo,hi};return#calls==1 and 0 or 99
 end}
 return b,mon,r,calls
end
for _,edition in ipairs{'ruby','sapphire','firered','leafgreen'}do
 local counts={};local b,mon,r=fixture(edition)
 for roll=0,99 do
  local n=0;b._gen3PickupDone=nil;mon.item=nil
  -- Use raw values whose residues are the desired independent chance/table rolls.
  b.rng=function(lo,hi)T.eq(lo,0);T.eq(hi,65535);n=n+1;return n==1 and 65530 or 65400+roll end
  Pickup.afterBattle(b)
  counts[mon.item]=(counts[mon.item]or 0)+1;T.eq(n,2)
 end
 local weights=(edition=='firered'or edition=='leafgreen')and{15,10,10,10,10,10,10,5,5,5,5,1,1,1,1,1}
   or{30,10,10,10,10,10,10,5,4,1}
 for i,n in ipairs(weights)do T.eq(counts['ITEM_'..i],n,edition..' original fixed-table frequency '..i)end
end
for level=1,100 do
 for _,case in ipairs{{0,1},{29,1},{30,2},{97,9},{98,102},{99,101}}do
  local b,mon=fixture('emerald');mon.level=level
  local n=0;b.rng=function()n=n+1;return n==1 and 0 or case[1]end
  Pickup.afterBattle(b)
  T.eq(mon.item,'ITEM_'..(math.floor((level-1)/10)+case[2]),'Emerald level '..level..' roll '..case[1])
  T.eq(n,2)
 end
end
do
 local b,mon,_,calls=fixture('ruby');b.rng=function(lo,hi)calls[#calls+1]={lo,hi};return 65535 end
 Pickup.afterBattle(b);T.eq(mon.item,nil);T.eq(#calls,1,'failed 10% check consumes no table roll')
end
for _,case in ipairs{'held','egg','ability','loss','run','caught','link','demo','pokedude','legacy','foreign','badcuts','missingitem','gen1','gen2','gen4'}do
 local b,mon,r,calls=fixture('ruby')
 if case=='held'then mon.item='ITEM_2'
 elseif case=='egg'then mon.isEgg=true
 elseif case=='ability'then mon.species='OTHER'
 elseif case=='loss'then b.result='lose'
 elseif case=='run'or case=='caught'then b.result=case
 elseif case=='link'then b.kind='link'
 elseif case=='demo'then b.demo=true
 elseif case=='pokedude'then b.pokedudeDemo={}
 elseif case=='legacy'then b.data.constants.gen3Pickup=nil
 elseif case=='foreign'then r.edition='sapphire'
 elseif case=='badcuts'then r.thresholds[1]=r.thresholds[2]
 elseif case=='missingitem'then b.data.items.ITEM_10=nil
 elseif case=='gen1'then V.set('red')elseif case=='gen2'then V.set('crystal')elseif case=='gen4'then V.set('platinum')end
 local before=S.encode(b.game.save);Pickup.afterBattle(b)
 T.eq(#calls,0,case..' consumes no Pickup RNG');T.eq(S.encode(b.game.save),before,case..' leaves party/save unchanged')
end
do
 local b,mon,_,calls=fixture('ruby')
 b.game.save.party={mon,{species='FINDER',hp=0,level=5},{species='FINDER',isEgg=true},
   {species='FINDER',item='ITEM_2'},{species='OTHER',abilitySlot=2,hp=5},{species='FINDER',hp=5}}
 b.player={mon=mon,abilityOverride='NONE'}
 b.rng=function(lo,hi)calls[#calls+1]={lo,hi};return 0 end
 Pickup.afterBattle(b);T.eq(#calls,8,'four eligible party slots, including fainted and nonparticipants')
 for _,i in ipairs{1,2,5,6}do T.eq(b.game.save.party[i].item,'ITEM_1')end
 T.eq(b.game.save.party[3].item,nil);T.eq(b.game.save.party[4].item,'ITEM_2')
end
for _,map in ipairs{'MAP_G26_N36','MAP_G26_N37','MAP_G26_N39'}do
 local b,mon,_,calls=fixture('emerald');b.game.overworld={map={id=map}}
 Pickup.afterBattle(b);T.eq(mon.item,nil);T.eq(#calls,0,'Pike forbids Pickup')
end
for _,mode in ipairs{0,1}do
 for _,wins in ipairs{0,7,133,140,9999}do
  local b,mon,_,calls=fixture('emerald');b.game.overworld={map={id='MAP_G26_N26'}}
  b.game.save.gen3Frontier={data={mode},facStreaks={[6]={['0:'..mode]=wins}}}
  Pickup.afterBattle(b)
  local expected=math.min(19,math.floor(wins/7))*10+10+mode*100
  T.eq(mon.item,'ITEM_'..expected,'Pyramid mode/round including capped final round')
  T.eq(#calls,2,'Pyramid uses the same two raw RNG calls')
 end
end
do
 local b,mon=fixture('emerald');Pickup.afterBattle(b)
 T.eq(b.game.save.gen3Frontier,nil,'ordinary outside Pickup cannot create frontier save state')
end
T.finish('Original GBA Pickup probability boundaries, party eligibility, RNG and Emerald facilities')
