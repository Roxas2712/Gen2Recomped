package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local B=require('src.features.gen1_gsc.Bundle')
local source=B.new{profile='g3u',testing=true}
local F=source:require('tests.engine._g3u_fixture')
local Builder=require('src.features.Gen1BattleCatalog')
for gen=1,2 do
 local input=gen==1 and F.gen1()or F.gen2()
 local expected=assert(source:require('src.battle.g3u.Table').build(input))
 local data={constants={},pokemon={},moves={}}
 for n,row in pairs(input.species)do
  local p={index=n,dex=n,name='SPECIES '..n,types=row.types,baseStats={}}
  for _,pair in ipairs{{'hp','hp'},{'attack','atk'},{'defense','def'},{'speed','spe'},{'spatk','spa'},{'spdef','spd'}}do p.baseStats[pair[1]]=row.base[pair[2]]end
  data.pokemon['N_'..n]=p
 end
 for n,row in pairs(input.moves)do local mv={};for k,v in pairs(row)do mv[k]=v end;mv.index=n;mv.name='MOVE '..n;data.moves['M_'..n]=mv end
 local actual,party=Builder.build(data,gen);assert(actual,party)
 T.same(actual,expected,'native catalogs map to the exact source common rules')
 local r=F.record(expected,25,{33})
 local mon={dvs={attack=15,defense=15,speed=15,special=15},species='N_25',level=r.level,hp=r.hp,happiness=70,moves={{id='M_33',pp=10,ppUps=0}},stats={hp=r.maxHp,attack=r.atk,defense=r.def,speed=r.speed,spatk=r.spAtk,spdef=r.spDef}}
 local record=assert(party({mon},actual))[1]
 T.eq(record.species,25,'native party resolves canonical common species')
 T.eq(record.ivs.spa,31,'classic special DV maps to the shared Hidden Power genotype')
 T.eq(record.moves[1].id,33,'native party resolves actual imported move index')
 T.eq(mon.item,nil,'building a battle view cannot change the saved record')
 mon.status='PAR';T.eq(party({mon},actual),nil,'heal admission rejects a status before the shared battle')
end
require('src.core.GameVersion').set('firered')
local data=T.fixtures.fresh();require('src.render.Font').load(data)
local stack={states={{isOverworld=true}}};function stack:top()return self.states[#self.states]end;function stack:push(s)self.states[#self.states+1]=s end;function stack:pop()return table.remove(self.states)end
local keys={};local game={data=data,save={player={id=2712,name='TRAINER'},meta={playthroughId='ui'},party={}},stack=stack,input={wasPressed=function(_,k)return keys[k]end}}
local fs={createDirectory=function()return true end,getDirectoryItems=function()return{}end,read=function()end,getInfo=function()end,write=function()return true end}
local Journal=require('src.features.Gen1SessionJournal')
local journal=Journal.new(game,{fs=fs,slot='slot'})
local UI=require('src.features.Gen1CableLobby')
local screen=assert(UI.open(game,{journal=journal}))
T.eq(stack:top(),screen,'actual native stack admits the additional cable UI')
T.eq(#screen:rows(),5,'GBA lobby offers trade, battle and explicit address settings')
keys.down=true;screen:update(0.01);keys={a=true};screen:update(0.01)
T.eq(screen.page,'edit','joining opens actual room-code editor')
local original=screen.edit;keys={up=true};screen:update(0.01)
T.neq(screen.edit,original,'native direction input edits a room digit')
keys={left=true};screen:update(0.01);T.eq(screen.cursor,8,'room editor wraps cursor deterministically')
keys={};screen:draw()
keys={b=true};screen:update(0.01);T.eq(screen.page,'menu','B returns from entry without opening a connection')
local live=true;screen.options.checkOwner=function()return live end;live=false
screen:update(0.01)
T.neq(stack:top(),screen,'retired mod UI releases the native stack')
T.eq(game.linkSession,nil,'leaving an unused lobby cannot retain a link lease')
local inbox={}
local fake={closed=false,connectTCP=function()return true end,update=function()end,
 send=function(_,message)if message.type=='session_open'then inbox[#inbox+1]={type='session_welcome',room='23456789',seat=0,token='private',profile=require('src.features.Gen1RelayChannel').PROFILE,mode='battle',seed=1}end end,
 poll=function()local out=inbox;inbox={};return out end,close=function(self)self.closed=true end}
local channel=assert(require('src.features.Gen1RelayChannel').new({credentials=function(_,_,value)if value then return true end end},{mode='battle',netFactory=function()return fake end}))
channel:update(0.01)
local frame={type='probe',value=1};assert(channel:publish('probe',frame));frame.value=2
T.eq(channel:publish('probe',frame),nil,'mutating an already sent table cannot rewrite its frozen publication')
channel:close()
T.finish('Native cable UI input, imported catalog and party admission')
