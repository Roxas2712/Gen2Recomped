-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
local cfg,net,finished,completeAt
local elapsed,received,sent=0,0,0
local direct,relay,dropped=false,false,false
local function finish(ok,why)
 if finished then return end;finished=true
 local file=assert(io.open(cfg.result,'wb'))
 file:write(require('src.link.Json').encode({ok=ok,reason=why,mode=cfg.mode,role=cfg.role,received=received,sent=sent,usedDirect=direct,usedRelay=relay,forcedFallback=dropped}));file:close()
 if net then net:close()end;love.event.quit(ok and 0 or 1)
end
function love.load()
 local file=assert(io.open(os.getenv('RETRO_PEER_CONFIG'),'rb'));cfg=require('src.link.Json').decode(file:read('*a'));file:close()
 package.loaded['src.cloud.RetroCloud']={signedIn=function()return true end,accountId=function()return cfg.role end}
 assert(require('src.link.NativePeer').available(),'Native peer bridge loads')
 net=assert(require('src.link.PeerNet').new(function()return {account_id=cfg.role,transport=cfg.transport}end,nil,{ephemeral=true,forceRelay=cfg.mode=='relay'}))
end
function love.update(dt)
 if finished or not cfg then return end;elapsed=elapsed+dt
 if elapsed>35 then return finish(false,'Timed out: '..tostring(net.path)..' '..tostring(net.error or net.openError))end
 net:update();if net.closed then return finish(false,net.error or'Unexpected close')end
 direct=direct or net.path=='p2p';relay=relay or net.path=='relay'
 for _,message in ipairs(net:poll())do
  if message.type~='fixture'or message.index~=received+1 or message.payload~=string.rep('x',message.index==1 and 20000 or 200)then return finish(false,'Payload changed or message order differed')end
  received=message.index
 end
 local ready=net.paired and(cfg.mode=='relay'or direct)
 if ready and sent==0 then for i=1,12 do net:send({type='fixture',index=i,payload=string.rep('x',i==1 and 20000 or 200)});sent=i end end
 if sent==12 and received>=12 and net.liveAck>=12 then
  if cfg.mode=='switch'and not dropped then net.native:drop();dropped=true end
  for i=13,24 do net:send({type='fixture',index=i,payload=string.rep('x',200)});sent=i end
 end
 if received==24 and net.liveAck==24 then
  completeAt=completeAt or elapsed
  if elapsed-completeAt>.5 then return finish(cfg.mode=='relay'and not direct or cfg.mode~='relay'and direct and(cfg.mode~='switch'or dropped and relay),'Native reliable transport completed')end
 end
end
function love.draw()love.graphics.clear(.02,.03,.05)end
function love.errorhandler(err)print(tostring(err)..'\n'..debug.traceback());if cfg then pcall(finish,false,err)end;return function()return 1 end end
