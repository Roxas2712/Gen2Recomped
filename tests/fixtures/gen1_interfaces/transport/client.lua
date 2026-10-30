package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local S=require('src.core.SaveSerializer')
local f=require('tests.enemy_actions.party_codec').fixture('.','gen2','firered','canonical')
f.data.constants.abilities={ABILITY_6={index=6},ABILITY_11={index=11}}
f.data.items.CODEC_BALL={index=4};f.data.constants.itemOrder={[4]='CODEC_BALL'}
require('src.pokemon.Stats').setNatures(f.data.constants.natures)
local function player(id)
 local mon=require('src.pokemon.Pokemon').new(f.data,f.codecIds[60],30)
 require('src.pokemon.Pokemon').applySeed(f.data,mon,{personality=100001,ivs={hp=31,attack=29,defense=27,speed=25,spatk=23,spdef=21}})
 mon.evs={hp=0,attack=0,defense=0,speed=0,spatk=0,spdef=0};mon.moves={{id=f.ids.TACKLE,pp=10,ppUps=0}}
 mon.ot,mon.otId,mon.secretId,mon.ball,mon.nickname,mon.abilitySlot='TRAINER',id,5678,'CODEC_BALL','LINKMON',2
 local game={data=f.data,save={player={id=id,name='TRAINER'},meta={playthroughId=tostring(id)},party={mon}},writes=0}
 function game:writeSave()self.writes=self.writes+1;self.persisted=S.encodeExact(self.save);return true end
 local files={};local fs={createDirectory=function()return true end,read=function(p)return files[p]end,
   write=function(p,v)files[p]=v;return true end,getInfo=function(p)return files[p]and{type='file',size=#files[p]}end,
   remove=function(p)files[p]=nil;return true end,getDirectoryItems=function()return{}end}
 return game,require('src.features.Gen1SessionJournal').new(game,{fs=fs,slot='slot'})
end
local Socket=dofile('tests/fixtures/gen1_interfaces/transport/socket.lua')
local function net()return require('src.features.Gen1Tcp').new{socketApi=Socket}end
local a,ja=player(1234);local b,jb=player(4321)
local ca=assert(require('src.features.Gen1RelayChannel').new(ja,{mode='trade',address=arg[1],netFactory=net}))
local sa=assert(require('src.features.Gen1CableSession').new(a,ca,{journal=ja}))
local cb,sb,room
local deadline=Socket.gettime()+15
while Socket.gettime()<deadline do
 sa:update(0.01)
 if ca.room and not cb then
  room=ca.room
  cb=assert(require('src.features.Gen1RelayChannel').new(jb,{mode='trade',room=room,address=arg[1],netFactory=net}))
  sb=assert(require('src.features.Gen1CableSession').new(b,cb,{journal=jb}))
 end
 if sb then sb:update(0.01)end
 for _,session in ipairs{sa,sb}do
  assert(not session.error,session.error)
  if session.phase=='select'and not session.picks[session.channel.seat]then assert(session:pick(1))end
  if session.phase=='confirm'then assert(session:confirm())end
 end
 if sb and sa.phase=='done'and sb.phase=='done'then break end
 Socket.sleep(0.001)
end
assert(sb and sa.phase=='done'and sb.phase=='done','actual relay cable exchange timed out')
assert(a.save.party[1].otId==4321 and b.save.party[1].otId==1234,'actual relay swapped the wrong ownership')
assert(a.writes==1 and b.writes==1,'actual relay did not apply exactly once')
local doc=assert(ja:credentials(room));assert(doc.finished and doc.token,'seat credentials were not protected')
print('ACTUAL_LUA_CABLE_RELAY_OK '..room)

-- The opposite client now uses the portable Gen1 adapter and its actual pinned
-- source modules. The native controller retains its own isolated kernel.
local source=require('src.features.gen1_gsc.Bundle').new{profile='g3u',testing=true}
local F=source:require('tests.engine._g3u_fixture')
local rules=assert(source:require('src.battle.g3u.Table').build(F.gen1()))
local Peer=require('compat.gen1_session.Peer')
local files={};local peerFs={createDirectory=function()return true end,read=function(p)return files[p]end,write=function(p,v)files[p]=v;return true end}
local credentials=Peer.credentials(peerFs,'pinned-gen1-test-profile')
local function makePeer(room)
 return assert(Peer.new{namespace=source,journal=credentials,room=room,address=arg[1],netFactory=net,
  table=rules,records={F.record(rules,25,{33},25)},generation=1,engineVersion='pinned Gen1'})
end
local peer=makePeer()
local native,nativeChannel,reconnected
local before=S.encodeExact(a.save)
deadline=Socket.gettime()+15
while Socket.gettime()<deadline do
 peer:update(0.01)
 if peer.channel.room and not native then
  nativeChannel=assert(require('src.features.Gen1RelayChannel').new(ja,{mode='battle',room=peer.channel.room,address=arg[1],netFactory=net}))
  native=assert(require('src.features.Gen1CableSession').new(a,nativeChannel,{journal=ja,records={F.record(rules,143,{33},25)}}))
 end
 if native then native:update(0.01)end
 assert(not peer.error,peer.error);assert(not native or not native.error,native and native.error)
 if peer.core and not peer.closed then
  local legal=peer.core:legal();if legal[1]then assert(peer:choose(legal[1]))end
 end
 if native and native.battle and not native.closed then
  local legal=native.battle:legal();if legal[1]then assert(native:choose(legal[1]))end
 end
 if peer.core and peer.core.step>=1 and not reconnected then
  local code=peer.channel.room;peer:close();peer=makePeer(code);reconnected=true
 end
 if peer.phase=='done'and native and native.phase=='done'then break end
 Socket.sleep(0.001)
end
assert(peer.phase=='done'and native and native.phase=='done','cross-engine TCP battle did not finish')
assert(reconnected,'battle connection was not restarted')
T.same(peer.result,native.result,'real Gen1 companion and native client agree after relay reconnection')
assert(T.harness.failures==0,'cross-engine result comparison failed')
assert(S.encodeExact(a.save)==before,'cross-engine battle changed the adventure save')
assert(a.writes==1,'cross-engine battle wrote an adventure save')
print('ACTUAL_CROSS_ENGINE_RECONNECT_OK')
