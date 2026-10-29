-- Wire conformance against the pinned source, plus native commit ownership.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local V=require('src.core.GameVersion')
local L=require('src.features.Gen1Link3')
local Copy=require('src.mods.Merge').deepCopy
local Json=require('src.link.Json')
local previous=V.get()
local oldGame=package.loaded['src.core.Game']
local bundle=require('src.features.gen1_gsc.Bundle').new()
local function oracle(bridges)
 local chunk=assert(loadfile('tests/fixtures/gen1_interfaces/vendor/src/link/Protocol.lua'))
 local env=setmetatable({require=function(name)
   if bridges and bridges[name]then return bridges[name]end
   if name=='src.link.Fingerprint'or name=='src.link.Wire'then return bundle:require(name)end
   return require(name)
 end},{__index=_G})
 setfenv(chunk,env);return chunk()
end
for _,version in ipairs{'red','crystal'}do
 V.set(version)
 local gen=V.generation()
 local data=T.fixtures.fresh()
 local Pokemon=require('src.pokemon.Pokemon')
 local mon=Pokemon.new(data,'FIXMON_A',30)
 mon.ot,mon.otId,mon.nickname='TRAINER',1234,'LINKMON'
 mon.extra={consumer={number=7}}
 local codec=L.codec(data,gen)
 local peerMon=Copy(mon);peerMon.otId=4321
 if gen==2 then
   mon.happiness,mon.pokerus=203,35
   mon.caughtLevel,mon.caughtTime,mon.caughtLocation,mon.caughtByGender=12,2,17,'girl'
 end
 local packet=assert(codec.packMon(mon))
 local source=Copy(mon)
 if gen==2 then source.experience=mon.exp;source.exp=nil;source.status=nil end
 local ref=oracle()
 local expected=gen==1 and ref.packMon(source)or ref.packMon2(source)
 T.same(packet,expected,version..' actual upstream wire encoding')
 local long=Copy(mon);long.extra={text=string.rep('x',65)}
 T.eq(codec.packMon(long),nil,'source transport cannot silently truncate extension strings')
 local restored=assert(codec.unpackMon(data,Json.decode(Json.encode(expected))))
 T.eq(restored.exp,mon.exp,'source experience arrives in native field')
 T.same(restored.dvs,mon.dvs,'classic genotype survives')
 T.same(restored.extra,mon.extra,'extension namespace survives')
 local par=Copy(mon);par.status='PAR'
 local parWire=assert(codec.packMon(par))
 T.eq(parWire.status,gen==2 and 'paralyze'or 'PAR','generation-specific status vocabulary')
 T.eq(assert(codec.unpackMon(nil,parWire)).status,'PAR','source status returns to native status')
 if gen==2 then
   T.eq(restored.caughtByGender,'girl','caught gender preserved')
   local egg=Copy(mon);egg.isEgg=true;egg.eggSteps=512
   local eggPacket=assert(codec.packMon(egg));T.eq(eggPacket.eggSteps,2,'native steps become whole source egg cycles')
   T.eq(assert(codec.unpackMon(nil,eggPacket)).eggSteps,512,'source cycles become native remaining steps')
   egg.eggSteps=513;T.eq(codec.packMon(egg),nil,'fractional source cycle rejects without losing steps')
   local invalid=Copy(expected);invalid.caughtTime=9
   T.eq(codec.unpackMon(nil,invalid),nil,'out-of-range caught fields rejected')
   local opaque=Copy(mon);opaque.caughtData=123
   T.eq(codec.packMon(opaque),nil,'opaque caught metadata cannot be dropped silently')
 end
 local game={data=data,save={party={mon}},mods=nil}
 package.loaded['src.core.Game']=game
 local hello={protocol=3,generation=gen,engineVersion=require('src.core.Version').engine..'.foreign',name='SOURCE'}
 local ownHello=assert(L.hello(game))
 T.eq(ownHello.protocol,3,'protocol3 advertisement is explicitly selected')
 T.eq(ownHello.engineVersion,require('src.core.Version').engine,'native engine release stays honest')
 T.eq(require('src.link.Handshake').PROTOCOL,2,'default protocol is unchanged')
 local s=assert(L.newTrade(game,hello))
 T.eq(game.linkSession,s,'session owns native link lease')
 T.eq(s:opening().type,'party','actual GB party envelope')
 s:handle{type='party',mons={assert(codec.packMon(peerMon))}}
 T.eq(s.stage,'picking','strict source packet admitted')
 s:handle{type='pick',index=1};assert(s:pick(1))
 T.eq(s.stage,'confirming','both selected real slots')
 assert(s:confirm(true));T.eq(s:confirm(false),nil,'sent confirmation cannot be reversed');s:handle{type='confirm',ok=true}
 T.eq(s.stage,'done','both confirmations required')
 local received=assert(s:apply(game))
 T.eq(received.otId,4321,'native party receives peer ownership')
 if gen==2 then T.eq(received.experience,received.exp,'received native GSC records keep live source fields')end
 T.eq(game.save.party[1],received,'native commit updates one selected slot')
 T.eq(game.linkSession,nil,'completed lease released')
 T.eq(s:apply(game),nil,'duplicate commit refused')
 local function fresh()
   game.save.party={Copy(mon)}
   return assert(L.newTrade(game,hello))
 end
 local early=fresh();early:handle{type='pick',cancel=true}
 T.eq(early.stage,'cancelled','cancel cannot precede peer party')
 local duplicate=fresh();duplicate:handle{type='party',mons={packet}};duplicate:handle{type='party',mons={packet}}
 T.eq(duplicate.stage,'cancelled','duplicate party aborts rather than replacing offer')
 local custom=Copy(mon);setmetatable(custom,{__index=function()return 0 end})
 T.eq(codec.packMon(custom),nil,'arbitrary metatables cannot masquerade as native field views')
 local changed=fresh();game.save.party[1].otId=99
 changed:handle{type='party',mons={packet}}
 T.eq(changed.stage,'cancelled','local ownership change invalidates snapshot')
 local retire=fresh();package.loaded['src.core.Game']={}
 retire:handle{type='party',mons={packet}}
 T.eq(retire.stage,'cancelled','retired game cannot trade')
 package.loaded['src.core.Game']=game
 local declined=fresh();declined:handle{type='party',mons={packet}};declined:pick(1);declined:handle{type='pick',index=1}
 declined:confirm(false);declined:handle{type='confirm',ok=true}
 T.eq(declined.stage,'declined','decline does not commit')
 assert(declined:reset());T.eq(declined.stage,'picking','declined offer can restart')
 declined:cancelPick();declined:handle{type='pick',cancel=true}
 T.eq(game.linkSession,nil,'mutual cancel releases native lease')
 local features=require('src.features.Gen1Compatibility')
 local loader={}
 local opt=features.forHost(function()return game end,data,loader,'probe')
 local leased=assert(opt.link3.newTrade(hello))
 features.retire(loader,'probe')
 T.eq(game.linkSession,nil,'mod rollback releases its native trade lease')
 T.eq(leased:pick(1),nil,'retired feature cannot submit another selection')
end
for _,version in ipairs{'firered','emerald'}do
 local f=require('tests.enemy_actions.party_codec').fixture('.','gen2',version,'canonical')
 f.data.constants.abilities={ABILITY_6={index=6},ABILITY_11={index=11}}
 f.data.constants.abilityOrder=nil
 local Stats,Pokemon=require('src.pokemon.Stats'),require('src.pokemon.Pokemon')
 Stats.setNatures(f.data.constants.natures)
 local m=Pokemon.new(f.data,f.codecIds[60],30)
 Pokemon.applySeed(f.data,m,{personality=100001,ivs={hp=31,attack=29,defense=27,speed=25,spatk=23,spdef=21}})
 m.evs={hp=0,attack=0,defense=0,speed=0,spatk=0,spdef=0}
 m.moves={{id=f.ids.TACKLE,pp=10,ppUps=3}}
 m.abilitySlot,m.ot,m.otId,m.secretId,m.nickname=2,'TRAINER',1234,5678,'PÖKEMON'
 f.data.items.CODEC_BALL={index=4};m.ball='CODEC_BALL'
 f.data.constants.itemOrder={[4]='CODEC_BALL'}
 local codec=L.codec(f.data,3)
 local wire=assert(codec.packMon(m))
 T.eq(wire.species,60,'cartridge species index, not National Dex label')
 T.eq(wire.moves[1].id,33,'cartridge move index')
 T.eq(wire.ability,6,'actual alternate ability id')
 local pk={speciesOf=function(mon)return mon.species end,abilities=function()return{11,6}end,
  abilityId=function()return 6 end,isEgg=function(mon)return mon.isEgg==true end,
  gender=function(_,pid)return pid%256<127 and 'F'or 'M'end,baseFriendship=function()return 70 end,
  moveIdAt=function(mon,i)return mon.moves[i]and mon.moves[i].id end,movePp=function()return 35 end}
 local ref=oracle{['src.core.game3.pokemon']=pk,
  ['src.core.game3.rse.ribbons']={word=function(mon)return mon.ribbons or 0 end},
  ['src.core.game3.battle.adapter']={normStatus=function(s)return s end}}
 local source={species=60,personality=100001,level=30,exp=m.exp,hp=m.hp,
  ot='TRAINER',otId=1234,otSecretId=5678,nickname='PÖKEMON',abilityNum=1,
  ivs={hp=31,atk=29,def=27,spe=25,spa=23,spd=21},evs={hp=0,atk=0,def=0,spe=0,spa=0,spd=0},
  moves={{id=33,pp=10,ppUps=3}},pokeball=4}
 T.same(wire,ref.packMon3(source),version..' actual upstream Game3 packet')
 local received=assert(codec.unpackMon(nil,ref.packMon3(source)))
 T.same(received.ivs,m.ivs,'six native IVs survive source Game3 packet')
 T.eq(received.secretId,5678,'source secret id preserves shiny ownership')
 local X=require('src.features.Gen1GbaExchange')
 local peer=Copy(wire);peer.otId=4321
 local x=assert(X.new(codec,wire,peer,{seat=0,afterRound=3}))
 local y=assert(X.new(codec,peer,wire,{seat=1,afterRound=3}))
 local xb,yb=assert(x:block()),assert(y:block())
 local xc,yc=assert(x:receive(yb)),assert(y:receive(xb))
 T.eq(xc.digest,yc.digest,'seat order yields equal two-engine digest')
 T.eq(xc.digest,ref.tradeDigest(ref.wireMon3(wire),ref.wireMon3(peer)),'exact pinned digest algorithm')
 T.eq(x:accept{type='trade_commit',n=3,digests={xc.digest,yc.digest}},nil,'stale round rejected')
 T.eq(x:accept{type='trade_commit',n=4,digests={xc.digest,'wrong'}},nil,'both relay digests required')
 local committed,receipt=x:accept{type='trade_commit',n=4,digests={xc.digest,yc.digest}}
 T.eq(committed.otId,4321,'verified peer candidate returned')
 T.eq(receipt.nativeWrites,0,'block verifier never writes native saves')
 T.eq(x:accept{type='trade_commit',n=5,digests={xc.digest,yc.digest}},nil,'duplicate commit rejected')
 local swap=assert(X.new(codec,wire,peer,{seat=0}));assert(swap:block())
 local wrong=Copy(yb);wrong.mon.otId=999
 T.eq(swap:receive(wrong),nil,'changed block cannot replace advertised offer')
 T.eq(swap:state(),'aborted','swapped offer aborts')
 local invalid=Copy(m);invalid.gen3Pokerus=999
 T.eq(codec.packMon(invalid),nil,'invalid source metadata cannot be clamped silently')
 invalid=Copy(m);invalid.extra={persistent=1}
 T.eq(codec.packMon(invalid),nil,'unsupported GBA extra data rejected explicitly')
 local owned=assert(X.new(codec,wire,peer,{seat=0}));assert(owned:block());local confirm=assert(owned:receive(yb))
 f.data.constants={}
 T.eq(owned:accept{type='trade_commit',n=1,digests={confirm.digest,confirm.digest}},nil,'retired cartridge cannot complete verification')
end
package.loaded['src.core.Game']=oldGame;V.set(previous)
T.finish('Opt-in Link3 source wire and commit ownership')
