package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local S=require('src.core.SaveSerializer')
local Journal=require('src.features.Gen1SessionJournal')
local Controller=require('src.features.Gen1CableSession')
local function copy(v)return S.decode(S.encodeExact(v))end
local function memfs()
 local files={};local fail=false
 return {files=files,fail=function(value)fail=value end,
  createDirectory=function()return true end,getInfo=function(p)return files[p]and{type='file',size=#files[p]}end,
  read=function(p)return files[p]end,write=function(p,v)if fail then return nil,'disk full'end;files[p]=v;return true end,
  remove=function(p)files[p]=nil;return true end,
  getDirectoryItems=function(dir)local out={};for p in pairs(files)do if p:sub(1,#dir+1)==dir..'/'then local name=p:sub(#dir+2);if not name:find('/',1,true)then out[#out+1]=name end end end;return out end}
end
local f=require('tests.enemy_actions.party_codec').fixture('.','gen2','firered','canonical')
f.data.constants.abilities={ABILITY_6={index=6},ABILITY_11={index=11}}
f.data.constants.itemOrder={[4]='CODEC_BALL'};f.data.items.CODEC_BALL={index=4}
require('src.pokemon.Stats').setNatures(f.data.constants.natures)
local function game(id)
 local m=require('src.pokemon.Pokemon').new(f.data,f.codecIds[60],30)
 require('src.pokemon.Pokemon').applySeed(f.data,m,{personality=100001,ivs={hp=31,attack=29,defense=27,speed=25,spatk=23,spdef=21}})
 m.moves={{id=f.ids.TACKLE,pp=10,ppUps=0}};m.evs={hp=0,attack=0,defense=0,speed=0,spatk=0,spdef=0}
 m.ball,m.ot,m.otId,m.secretId,m.abilitySlot,m.nickname='CODEC_BALL','TRAINER',id,5678,2,'LINKMON'
 local g={data=f.data,save={party={m},player={id=id,name='TRAINER'},meta={playthroughId=tostring(id)}},writes=0}
 function g:writeSave()if self.failSave then self.failSave=false;return nil,'injected save failure'end;self.writes=self.writes+1;self.persisted=S.encodeExact(self.save);return true end
 return g
end
local function relay()
 local r={clients={},log={},keys={},confirms={}}
 function r:channel(seat,replay)
  local n={seat=seat,mode='trade',room='23456789',seed=2712,paired=true,inbox={}}
  function n:update()end
  function n:poll()local out=self.inbox;self.inbox={};return out end
  function n:close()self.closed=true end
  function n:publish(key,body)
   local tag=seat..':'..key
   if r.keys[tag]then assert(S.encodeExact(r.keys[tag])==S.encodeExact(body));return true end
   r.keys[tag]=copy(body)
   local function emit(sender,message)
    local row={seat=sender,body=copy(message),ordinal=#r.log+1,room=self.room};r.log[#r.log+1]=row
    for _,client in pairs(r.clients)do if not client.closed then client.inbox[#client.inbox+1]=copy(row)end end
   end
   emit(seat,body)
   if key=='confirm'then r.confirms[seat]=body.digest
    if r.confirms[0]and r.confirms[1]then emit(-1,{type='trade_commit',n=1,digests={r.confirms[0],r.confirms[1]}})end
   end
   return true
  end
  r.clients[seat]=n
  if replay then for _,row in ipairs(r.log)do n.inbox[#n.inbox+1]=copy(row)end end
  return n
 end
 return r
end
for _,failure in ipairs{false,true}do
 local a,b=game(1234),game(4321)
 local saveOwner,playerOwner,partyOwner=a.save,a.save.player,a.save.party
 local fa,fb=memfs(),memfs()
 local ja,jb=Journal.new(a,{fs=fa,slot='slot'}),Journal.new(b,{fs=fb,slot='slot'})
 local bus=relay()
 local ca=assert(Controller.new(a,bus:channel(0),{journal=ja}))
 local cb=assert(Controller.new(b,bus:channel(1),{journal=jb}))
 for _=1,12 do ca:update(0.1);cb:update(0.1)end
 T.eq(ca.phase,'select','real source-wire parties reach cable selection')
 assert(ca:pick(1));assert(cb:pick(1))
 for _=1,4 do ca:update(0.1);cb:update(0.1)end
 T.eq(ca.phase,'confirm','both immutable slots reach explicit consent')
 if failure then a.failSave=true end
 assert(ca:confirm());assert(cb:confirm())
 for _=1,10 do ca:update(0.1);cb:update(0.1)end
 if failure then
  T.eq(ca.phase,'recovery','save failure leaves a recoverable committed receipt')
  T.eq(a.save.party[1].otId,1234,'failed native save restores the original live party')
  T.eq(a.writes,0,'failed write cannot be counted as applied')
  ca:close()
  ca=assert(Controller.new(a,bus:channel(0,true),{journal=Journal.new(a,{fs=fa,slot='slot'})}))
  for _=1,6 do ca:update(0.1)end
 end
 T.eq(ca.phase,'done','verified relay decision reaches durable native save')
 T.eq(cb.phase,'done','both players finish')
 T.eq(a.save.party[1].otId,4321,'received native ownership belongs to the other seat')
 T.eq(b.save.party[1].otId,1234,'other seat receives its selected peer')
 T.eq(a.writes,1,'exactly one successful native save applies the receipt')
 T.eq(a.save.gen3Stats[21],1,'native trade counter applies once')
 T.eq(a.save,saveOwner,'native save identity survives the successful transaction')
 T.eq(a.save.player,playerOwner,'native player identity survives the successful transaction')
 T.eq(a.save.party,partyOwner,'native party array retains its owner')
 T.eq(S.encodeExact(a.save),a.persisted,'live save matches the committed bytes')
 T.eq(a.linkSession,nil,'finished controller releases its native lease')
 local resumed=assert(Controller.new(a,bus:channel(0,true),{journal=Journal.new(a,{fs=fa,slot='slot'})}))
 T.eq(resumed.phase,'done','post-save crash is recognized from the native receipt marker')
 T.eq(a.writes,1,'replaying a completed receipt cannot trade twice')
 T.check(next(fa.files)~=nil,'recovery proof is retained in the private profile filesystem')
end
-- A divergent party must not be overwritten by journal recovery.
local a=game(1234);local fs=memfs();local j=Journal.new(a,{fs=fs,slot='slot'})
local codec=require('src.features.Gen1Link3').codec(f.data,3)
local received=assert(codec.packMon(game(4321).save.party[1]))
assert(j:prepare('23456789',1,received,'0123456789abcdef',codec))
a.save.party[1].nickname='CHANGED'
T.eq(j:commit('23456789',{type='trade_commit',n=1,digests={'0123456789abcdef','0123456789abcdef'}},codec),nil,'changed party blocks recovery without overwriting progress')
T.eq(a.save.party[1].nickname,'CHANGED','divergent native data survives')
local poor=memfs();local journal=Journal.new(a,{fs=poor,slot='slot'});poor.fail(true)
T.eq(journal:prepare('ABCDEFGH',1,received,'0123456789abcdef',codec),false,'disk-full preparation fails before confirmation')
-- Native trade evolution and post-evolution move prompts retain a durable marker.
local current=f.data.pokemon[f.codecIds[60]]
local oldEvolutions=current.evolutions
current.evolutions={{method='TRADE',species='EVOLVED_FIXMON'}}
local evolved=copy(current);evolved.id='EVOLVED_FIXMON';evolved.index=61;evolved.evolutions={}
evolved.learnset={{level=30,move=f.ids.SCRATCH}};f.data.pokemon.EVOLVED_FIXMON=evolved
local evoGame=game(1234);local evoFs=memfs();local evoJournal=Journal.new(evoGame,{fs=evoFs,slot='slot'})
assert(evoJournal:credentials('ABCDEFGH',{token='private',seat=0,mode='trade',finished=true}))
assert(evoJournal:prepare('ABCDEFGH',1,received,'0123456789abcdef',codec))
assert(evoJournal:commit('ABCDEFGH',{type='trade_commit',n=1,digests={'0123456789abcdef','0123456789abcdef'}},codec))
T.eq(evoGame.save.party[1].species,'EVOLVED_FIXMON','native trade method applies before the committed save')
local recipient,moves=evoJournal:pendingLearning('ABCDEFGH',codec);assert(recipient)
T.eq(moves[1],f.ids.SCRATCH,'evolved exact-level moves remain available to the native move-learn UI')
T.eq(#evoJournal:list(),1,'finished cable room remains resumable while evolution learning is pending')
assert(evoJournal:finishLearning('ABCDEFGH'))
T.eq(evoJournal:pendingLearning('ABCDEFGH',codec),nil,'saved native learning decision cannot prompt twice')
T.eq(#evoJournal:list(),0,'completed learning clears the recovery menu entry')
current.evolutions=oldEvolutions
T.finish('Cable consent, durable commit, crash replay and save ownership')
