package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
love.data={hash=function(_,b) local h=5381;for i=1,#b do h=(h*33+b:byte(i))%4294967296 end;return string.rep(('%08x'):format(h),8) end,encode=function(_,_,b) return b end}
local P=require('src.link.Protocol');local L=require('src.link.LinkBattle');local S=require('src.core.SaveSerializer')
local function clone(v) return S.decode(S.encode(v)) end
for _,version in ipairs({'red','crystal','emerald'}) do
 require('src.core.GameVersion').set(version)
 local data=T.fixtures.fresh();T.sdk.loadNone({data=data})
 if version=='emerald' then for _,d in pairs(data.pokemon) do d.baseStats.spatk=d.baseStats.special;d.baseStats.spdef=d.baseStats.special;d.evYield={} end end
 require('src.battle.TypeChart').load(data);T.link.prepare(data)
 local ga=T.link.fakeGame(data,'FIXMON_A',{name='HOST',level=50});local gb=T.link.fakeGame(data,'FIXMON_B',{name='GUEST',level=50})
 local na,nb=require('src.link.Net').loopbackPair();local pa,pb=P.packParty(ga.save.party),P.packParty(gb.save.party)
 local streams={{},{}};local proofs={}
 for i,net in ipairs({na,nb}) do local send=net.send;net.send=function(self,m) streams[i][#streams[i]+1]={sequence=#streams[i]+1,body=clone(m)};send(self,m) end end
 local a=assert(L.newHost(ga,na,{myParty=pa,theirParty=pb,seed=327,forceLevel=50,strict=true,onFinished=function(r)proofs[1]=r end}))
 local b=assert(L.newGuest(gb,nb,{myParty=pb,theirParty=pa,seed=327,forceLevel=50,strict=true,onFinished=function(r)proofs[2]=r end}))
 ga.stack:push(a);gb.stack:push(b)
 local snapshot
 for _=1,100000 do
  ga.input.pressed={a=snapshot~=nil or(a.turnCount or 0)<2 or a.phase~='menu'};ga.stack:update(1/60)
  gb.input.pressed={a=snapshot~=nil or(b.turnCount or 0)<2 or b.phase~='menu'};gb.stack:update(1/60)
  if not snapshot and a.phase=='menu'and b.phase=='menu'and a.localHashes[2]and b.localHashes[2]then snapshot=clone(streams)end
  if proofs[1] and proofs[2] then break end
 end
 T.check(proofs[1] and proofs[2],'two real native participants completed '..version)
 local fp=require('src.link.Handshake').hello(ga,'battle').fingerprint
 local job={schema=1,seed=327,edition=version,level=50,teams={{account=1,party=pa,fingerprint=fp,messages=streams[1]},{account=2,party=pb,fingerprint=fp,messages=streams[2]}}}
 local function replay(j) local g=T.link.fakeGame(data,'FIXMON_A',{name='HOST',level=50});return require('src.link.ArenaReplay').run(g,j) end
 local proof=replay(job)
 T.eq(proof.digest,proofs[1].digest,'independent replay reproduces the final proof '..version)
 T.eq(proof.turns,proofs[1].turns)
 local terminal=T.link.fakeGame(data,'FIXMON_A',{name='HOST',level=50});local emitted
 local finishedBattle,activateFinished=require('src.link.ArenaResume').rebuild(terminal,job,1,{close=function()end},function(r)emitted=r end)
 T.eq(emitted,nil,'a terminal reconstruction does not report before the device lease is activated '..version)
 T.check(activateFinished(),'a battle finishing during takeover is recovered as its actual result '..version)
 T.eq(emitted.digest,proofs[1].digest,'terminal takeover retains the uninterrupted result '..version)
 assert(snapshot,'A native mid-battle transfer snapshot is required')
 local resumeJob=clone(job);resumeJob.teams[1].messages=snapshot[1];resumeJob.teams[2].messages=snapshot[2]
 local ra=T.link.fakeGame(data,'FIXMON_A',{name='HOST',level=50});local rb=T.link.fakeGame(data,'FIXMON_B',{name='GUEST',level=50})
 local rn,sn=require('src.link.Net').loopbackPair();local resumed={}
 local ar,activateA=require('src.link.ArenaResume').rebuild(ra,resumeJob,1,rn,function(r)resumed[1]=r end)
 local br,activateB=require('src.link.ArenaResume').rebuild(rb,resumeJob,2,sn,function(r)resumed[2]=r end)
 T.eq(ar.localHashes[2],a.localHashes[2],'host reconstruction preserves the last accepted turn '..version)
 T.eq(br.localHashes[2],b.localHashes[2],'guest reconstruction preserves the last accepted turn '..version)
 activateA();activateB()
 for _=1,100000 do
  ra.input.pressed={a=true};ra.stack:update(1/60);rb.input.pressed={a=true};rb.stack:update(1/60)
  if resumed[1]and resumed[2]then break end
 end
 T.check(resumed[1]and resumed[2],'both reconstructed devices continue live '..version)
 T.eq(resumed[1].digest,proofs[1].digest,'host handoff ends with the uninterrupted proof '..version)
 T.eq(resumed[2].digest,proofs[2].digest,'guest handoff ends with the uninterrupted proof '..version)
 local bad=clone(job);bad.teams[1].messages[1].sequence=2
 T.check(not pcall(replay,bad),'missing transcript sequence refused')
 bad=clone(job);for _,row in ipairs(bad.teams[1].messages) do if row.body.type=='action' then row.body.slot=999;break end end
 T.check(not pcall(replay,bad),'invented move slot refused')
 bad=clone(job);bad.teams[2].fingerprint='untrusted'
 T.check(not pcall(replay,bad),'untrusted native dataset refused')
end
T.finish('Independent native Arena replay')
