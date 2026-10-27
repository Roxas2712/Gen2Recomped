-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Reconstruct accepted choices from the server archive, then attach a new
-- device's transport. No HP, RNG or executable client snapshot is trusted.
local R={}
function R.rebuild(game,job,account,net,onFinished,yield)
 assert(job.schema==1 and type(job.teams)=='table' and #job.teams==2,'Invalid battle transfer')
 local host,guest=job.teams[1],job.teams[2]
 local role=host.account==account and 'host' or guest.account==account and 'guest'
 assert(role,'This transfer belongs to another account')
 local fp=require('src.link.Handshake').hello(game,'battle').fingerprint
 assert(host.fingerprint==fp and guest.fingerprint==fp,'Native battle data differs')
 local parse=require('src.link.ArenaReplay').stream
 local hs,gs=parse(host.messages),parse(guest.messages)
 local turns=math.min(#hs.actions,#gs.actions)
 assert(math.abs(#hs.actions-#gs.actions)<=1,'Battle has conflicting pending choices')
 local active=false
 local proxy={update=function()if active then net:update()end end,poll=function()return active and net:poll()or{}end,
  send=function(_,m)if active then net:send(m)end end,close=function()if active then net:close()end end}
 local own,peer=role=='host'and host or guest,role=='host'and guest or host
 local completion
 local b=assert(require('src.link.LinkBattle').new(game,proxy,{role=role,myParty=own.party,theirParty=peer.party,
  seed=job.seed,forceLevel=job.level,strict=true,verdict='full',replay=true,theirName='RIVAL',onFinished=function(result)
   completion=result;if active and onFinished then onFinished(result)end
  end}))
 game.stack:push(b)
 local turn,hb,gb=1,1,1;local ready=false
 for tick=1,2000000 do
  if completion then ready=true;break end
  assert(not b.linkEnded,'The archived battle ended without a native result')
  if b.phase=='menu'and not b.result then
   if turn>turns then ready=true;break end
   b:replayTurn(hs.actions[turn],gs.actions[turn]);turn=turn+1
  end
  for _,side in ipairs({{hs,'host'},{gs,'guest'}})do
   local n=side[2]=='host'and hb or gb;local p=side[1].batons[n]
   if p and p.turn==(b.turnCount or 0)then
    assert(require('src.link.Gen3BatonChoice').receive(b,p,side[2]),'Invalid archived replacement choice')
    if side[2]=='host'then hb=hb+1 else gb=gb+1 end
   end
  end
  game.input.pressed={a=b.phase=='messages'};game.stack:update(1/60)
  if b._gen3BatonPending and not b._gen3BatonPending.choice and turn>turns then ready=true;break end
  if yield and tick%600==0 then yield()end
 end
 assert(ready,'The archived battle has not reached a reconstructible decision')
 for _,s in ipairs({hs,gs})do
  for n,p in pairs(s.hashes)do
   local parts=b.localParts[n]
   assert(n<=turns and parts and p.value==b.localHashes[n] and p.parts and p.parts.actives==parts.actives and p.parts.bench==parts.bench,'Battle transfer diverged at turn '..n)
  end
 end
 assert(hb>#hs.batons and gb>#gs.batons,'Unused archived replacement choice')
 local mine,theirs=role=='host'and hs or gs,role=='host'and gs or hs
 for n,p in pairs(theirs.hashes)do b.remoteHashes[n]=p.value;b.remoteParts[n]=p.parts end
 game.input.pressed={};game.input.state={};game.input.sources={}
 return b,function()
  assert(not active,'This battle transfer is already active')
  active=true
  if completion then if onFinished then onFinished(completion)end;net:close();return true end
  b:resumeLive(mine.actions[turns+1],theirs.actions[turns+1])
  game.linkNet=proxy
  return false
 end
end
return R
