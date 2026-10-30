package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.harness')
local B=require('src.features.gen1_gsc.Bundle')
local Sync=require('src.features.Gen1SyncBattle')
for gen=1,2 do
 for seed=1,4 do
  local source=B.new{profile='g3u',testing=true}
  local F=source:require('tests.engine._g3u_fixture')
  local table=assert(source:require('src.battle.g3u.Table').build(gen==1 and F.gen1()or F.gen2()))
  local random=F.lcg(seed)
  local parties={[0]=F.randomParty(table,random,2),[1]=F.randomParty(table,random,2)}
  local snapshot=require('src.core.SaveSerializer').encodeExact(parties)
  local a=Sync.new{seat=0,seed=seed,table=table,parties=parties}
  local b=Sync.new{seat=1,seed=seed,table=table,parties=parties}
  local reference=source:require('src.battle.g3u.Match').new{table=table,parties=parties,seed=seed}
  reference:start()
  local steps=0
  while true do
   for seat,peer in pairs{[0]=a,[1]=b}do
    for _,row in ipairs(peer:poll())do assert(a:handle(seat,row.body));assert(b:handle(seat,row.body))end
   end
   T.check(a:ready()and b:ready(),'both canonical seats cross the hash barrier')
   T.eq(a.hash,b.hash,'independent namespaces agree after a full state/RNG hash')
   T.eq(a.hash,source:require('src.battle.g3u.Hash').value(source:require('src.battle.g3u.Hash').parts(reference.st,reference.draws)),'actual unwrapped source engine agrees')
   if a:result()then T.same(a:result(),b:result(),'both players receive the same verified result');break end
   steps=steps+1;assert(steps<=600,'battle did not finish')
   local actions={}
   for seat,peer in pairs{[0]=a,[1]=b}do
    if reference.phase~='replace'or reference:needs(seat)then
     actions[seat]=F.pick(reference,seat,random)
     local key,body=peer:choose(actions[seat]);assert(key,body)
     assert(a:handle(seat,body));assert(b:handle(seat,body))
    end
   end
   if reference.phase=='replace'then
    local picks={};for seat,act in pairs(actions)do picks[seat]=act.index end;reference:replace(picks)
   else reference:submit(actions)end
  end
  T.eq(require('src.core.SaveSerializer').encodeExact(parties),snapshot,'synchronous battles never modify native input parties')
 end
end
local source=B.new{profile='g3u',testing=true};local F=source:require('tests.engine._g3u_fixture')
local table=assert(source:require('src.battle.g3u.Table').build(F.gen1()))
local party={[0]={F.record(table,25,{33})},[1]={F.record(table,25,{33})}}
local bad=Sync.new{seat=0,seed=1,table=table,parties=party}
T.eq(bad:choose{kind='move',slot=1},nil,'input waits for the peer hash')
T.eq(bad:handle(1,{type='session_battle_hash',step=0,hash='ffffffff'}),nil,'desync aborts before another turn')
T.eq(bad.closed,true,'desynchronized match stays closed')
T.finish('Shared-kernel two-engine turn, replacement and hash barriers')
