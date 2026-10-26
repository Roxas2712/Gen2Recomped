package.path='./?.lua;'..package.path
love=require('tests.love_stub')
local S=require('src.core.SaveSerializer');local Stats=require('src.pokemon.Stats')
local D=require('src.import.GiftDesigner');local P=require('src.storage.GiftPokemon')
local n=0;local function check(v,m) assert(v,m);n=n+1 end
local f=D.init({});D.action(f,'giftTab:Stats');f.giftIVs='31, 30, 29, 28, 27, 26';f.giftEVs='6,252,0,252,0,0';f.giftMoves='Thunder Shock, Fly';f.giftOT='WINNER';f.giftTID='1234';f.giftSID='5432';f.giftNature='3';f.giftAbility='2';f.giftGender='female';f.giftShiny=true
local payload=assert(D.payload(f))
check(payload.pokemon.ivs.spdef==26 and payload.moves[1]=='THUNDERSHOCK' and payload.moves[2]=='FLY','editor preserves complete stats and canonicalizes human move names')
f.giftIVs='31,31';check(not D.payload(f),'partial stat tuples cannot silently become random values');f.giftIVs=''
D.action(f,'giftPreset:old_sea_map');local event=assert(D.payload(f));check(event.preset=='old_sea_map' and event.dex==nil and event.pokemon==nil,'choosing a locked event excludes stale custom fields')
local def={genderRatio=127,abilities={'STATIC','LIGHTNINGROD'}};local order={};for i=1,25 do order[i]='NATURE_'..(i-1) end
local data={pokemon={PIKACHU=def},items={LEFTOVERS={name='Leftovers'},POKE_BALL={name='Poke Ball'}},constants={natureOrder=order}}
local state=27;local function rng(lo,hi) state=state*48271%2147483647;return lo+state%(hi-lo+1) end
payload.pokemon.held_item='LEFTOVERS';payload.pokemon.ball='POKEBALL'
local entry={origin={generation=3,shiny=true,reward=payload}}
local original={species='PIKACHU',ot='RetroRecomp',otId=2712,ivs={},evs={},level=5,happiness=70}
local mon=assert(P.apply(S.decode(S.encode(original)),entry,data,'emerald',rng))
check(mon.ot=='WINNER' and mon.otId==5432*65536+1234 and mon.nickname==nil,'OT and packed trainer IDs materialize into the native record')
check(Stats.isShinyGen3(mon.personality,mon.otId) and mon.personality%25==3 and mon.personality%2==1 and mon.personality%256<127,'generated PID simultaneously satisfies shiny, nature, ability and gender')
check(mon.ivs.spdef==26 and mon.evs.attack==252 and mon.ball=='POKE_BALL' and mon.heldItem=='LEFTOVERS','full values and native item identifiers survive materialization')
local again=assert(P.apply(S.decode(S.encode(original)),entry,data,'emerald',function(lo,hi) return lo end))
check(Stats.isShinyGen3(again.personality,again.otId),'identity construction works without a lucky random draw')
payload.pokemon.pid=0;check(not P.apply(S.decode(S.encode(original)),entry,data,'emerald',rng),'a contradictory explicit PID fails with a clear error')
payload.pokemon.pid=nil;payload.pokemon.held_item='ABILITYCAPSULE';check(not P.apply(S.decode(S.encode(original)),entry,data,'emerald',rng),'an unavailable native item is never invented')
local legacy={origin={generation=2,shiny=true,reward={pokemon={dvs={attack=1,defense=1,speed=1,special=1}}}}}
check(not P.apply(S.decode(S.encode(original)),legacy,data,'crystal',rng),'non-shiny explicit DVs cannot masquerade as a shiny')
package.loaded['src.script.Gen3Commands']={flagKey=function(v) return ('FLAG_G3_%04X'):format(v) end,EON_TICKET_VAR=0x403F}
package.loaded['src.core.Logger']={info=function() end}
local ev=require('src.pokewalker.WalkerEvents')
local ticketData={constants={gen3SSTidal={destinations={{item='OLD_SEA_MAP',flags={0x8D6},name='Faraway Island'}}}},items={OLD_SEA_MAP={name='Old Sea Map'}}}
local save={inventory={},flags={}}
check(ev.deliverGift(save,ticketData,'old_sea_map','emerald')==true and save.inventory.OLD_SEA_MAP==1 and save.flags.FLAG_G3_08D6 and save.flags.FLAG_G3_013C,'Old Sea Map grants both the native dock unlock and received flag plus the ticket')
check(not ev.deliverGift({inventory={}},ticketData,'old_sea_map','ruby'),'the Faraway Island event cannot be applied to Ruby')
local defMon={dex=151,baseStats={hp=100,attack=100,defense=100,speed=100,special=100},growthRate='MEDIUM_FAST',level1Moves={'POUND'},learnset={},catchRate=45}
local monData={pokemon={MEW=defMon},moves={POUND={name='Pound',pp=35,power=40}},items={},constants={}}
local R=require('src.storage.GiftReward')
local historical={source={version='red'},origin={kind='retrorecomp_gift',pool='native-gifts-v1',generation=1,shiny=false,isEgg=false,seed=string.rep('a',64),claim_date='2026-10-26',reward={preset='mew_vc'}},mon={species='DEX_151',level=5,moves={},ot='RetroRecomp'},canonical={dex=151,moves={}}}
local oldRandom=math.random
local first=assert(R.build(historical,'MEW',monData,'red'));local second=assert(R.build(historical,'MEW',monData,'red'))
check(first.ot=='GF' and first.otId==22796 and first.moves[1].id=='POUND','historical Mew retains the sourced OT, trainer ID and move')
check(S.encode(first)==S.encode(second) and math.random==oldRandom,'preset recovery is deterministic and restores the global RNG')
love.data={hash=function(_,bytes) local hash=5381;for i=1,#bytes do hash=(hash*33+bytes:byte(i))%4294967296 end;return string.rep(('%08x'):format(hash),8) end,encode=function(_,_,b) return b end}
local B=require('src.storage.PokemonBank');local I=require('src.storage.GiftItems')
local gift={schema=1,source={version='red',slot='gift'},origin={kind='retrorecomp_gift',recordId=string.rep('a',64),reward={kind='item',item='RARECANDY',quantity=3}},mon={species='DEX_0',level=5,moves={}},canonical={dex=0,moves={}}}
local bytes=S.encode(gift);local receipt={id='11111111-1111-4111-8111-111111111111',kind='item',edition='red',entry=bytes,digest=love.data.hash('sha256',bytes)}
local itemData={items={RARE_CANDY={name='Rare Candy'}},constants={}}
local draft={inventory={}}
check(I.apply(receipt,draft,itemData,'red') and draft.inventory.RARE_CANDY==3 and draft.retroGiftClaims[receipt.id]==receipt.digest,'item delivery records quantity and claim identity in the save lineage')
check(not I.apply(receipt,draft,itemData,'red') and draft.inventory.RARE_CANDY==3,'replaying the same receipt cannot add items to the same save lineage twice')
check(not I.apply(receipt,{inventory={}},itemData,'crystal'),'an item receipt cannot be delivered to another edition')
local originalSave={inventory={}};local originalBytes=S.encode(originalSave)
package.loaded['src.storage.AccountStorage']={check=function() return true end}
local read,commit=B.readSave,B.commitDraft
B.readSave=function() return originalSave end;B.commitDraft=function(version,slot,copy) check(copy.inventory.RARE_CANDY==3,'committed draft contains its item');return 'new-slot' end
check(I.deliver(receipt,'red','slot1',itemData)=='new-slot' and S.encode(originalSave)==originalBytes,'delivery writes a new slot without changing the original save')
B.readSave=read;B.commitDraft=commit
local Generator=require('src.storage.GiftGenerator')
for gen=1,5 do
 local special=assert(Generator.roll(gen,true,false,function(lo) return lo end))
 local ordinary=assert(Generator.roll(gen,false,false,function(lo) return lo end))
 check(special.dex>=Generator.RANGES[gen][1] and special.dex<=Generator.RANGES[gen][2] and ordinary.dex==(gen==5 and 495 or Generator.RANGES[gen][1]), 'generation '..gen..' quick generators use that generation’s species pool')
 if gen>=2 then check(assert(Generator.roll(gen,true,true)).egg and assert(Generator.roll(gen,false,true)).egg,'both egg buttons generate for generation '..gen) end
end
check(not Generator.roll(1,true,true),'Gen 1 never generates an egg')
local quick=D.init({giftSelected={crystal=true},giftTitle=''})
D.action(quick,'giftGen:3');D.action(quick,'giftRoll:legendaryEgg')
local rolled=assert(D.payload(quick));check(quick.giftSelected.emerald and rolled.egg and rolled.dex>=252 and rolled.dex<=386,'admin quick roll populates the editable form and the matching generation edition')
print('Gift editor: '..n..' checks passed')
