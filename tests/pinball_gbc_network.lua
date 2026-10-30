-- Two real native guests over the real ENet/TCP transport, on localhost only.
local Json=require('src.link.Json')
local Player=require('src.pinball.Player')
local Net=require('src.link.Net')
local players={};local started=love.timer.getTime();local mode=os.getenv('PINBALL_NETWORK_MODE')or'enet'
local output=assert(os.getenv('PINBALL_NETWORK_REPORT'))
local images={};local closed=false;local screenshot=false;local fullImages={0,0}
local function finish(ok,why)
 if closed then return end;closed=true
 local report={passed=ok,reason=why,transport=mode,seconds=love.timer.getTime()-started,players={}}
 for i,p in ipairs(players)do
  report.players[i]={state=p.duel.state,result=p.duel.result,localScore=p.duel.localScore,remoteScore=p.duel.remoteScore,
   frame=p.duel.localFrame,remoteFrame=p.duel.remoteFrame,checkpoint=p.checkpoint,peerImages=p.liveView and p.liveView.received or 0,fullTablePeerImages=fullImages[i],stats=p.stats[1],view=p.duel.viewEnabled,
   nativeShape=p.images[1]and{p.images[1]:getDimensions()},remoteShape=p.images[2]and{p.images[2]:getDimensions()}}
  p:stop()
 end
 Player.shutdown()
 local file=assert(io.open(output,'w'));file:write(Json.encode(report));file:close()
 print(Json.encode(report));love.event.quit(ok and 0 or 1)
end
function love.load()
 love.window.setTitle('GBC Pinball · localhost network qualification')
 local file=assert(io.open(assert(os.getenv('PINBALL_NETWORK_LIBRARY')),'rb'));local session=Json.decode(file:read('*a'));file:close()
 session.player=assert(os.getenv('PINBALL_NETWORK_PLAYER'))
 local left,right=Net.new(),Net.new();local address='127.0.0.1:'..assert(os.getenv('PINBALL_NETWORK_PORT'))
 if mode=='relay'then
  -- Synthetic identities exercise the local relay, never a live account API.
  local identity='101'
  package.loaded['src.cloud.RetroCloud']={signedIn=function()return true end,accountId=function()return identity end}
  package.loaded['src.cloud.NativeAccount']={request=function(method,path)assert(method=='GET'and path=='/community/counts');return{account_id=identity}end}
  assert(left:hostOnline(address),left.error)
  local deadline=love.timer.getTime()+3
  while not left.code and love.timer.getTime()<deadline do left:update();love.timer.sleep(.001)end
  assert(left.code,'Local relay did not return a room code');identity='102'
  assert(right:joinOnline(address,left.code),right.error)
 else assert(left:host(tonumber(os.getenv('PINBALL_NETWORK_PORT'))),left.error);assert(right:join(address),right.error)end
 for i,net in ipairs{left,right}do
  local own={};for k,v in pairs(session)do own[k]=v end;own.volume=i==1 and .3 or 0
  local p=Player.new(own,{net=net,host=i==1,duel=true,field=tonumber(os.getenv('PINBALL_NETWORK_FIELD'))or 0,frameLimit=600})
  players[i]=p;p.settings.full_table=true;p:command{action='view',full_table=true}
  p.input={buttons=function(_,seat)
   local st=p.stats[1];local frame=st and st.elapsed or 0
   return frame%120<55 and 1 or frame%120<110 and 32 or 0
  end,join=function()end}
 end
end
function love.update(dt)
 local ok,why=pcall(function()
  for i,p in ipairs(players)do
   p:update(dt)
   assert(not p.error,p.error);assert(p.duel.state~='cancelled',p.duel.error)
   if p.images[2]then images[i]=(images[i]or 0)+1;if p.images[2]:getWidth()==192 then fullImages[i]=fullImages[i]+1 end end
  end
  local p=players[1]
  if not screenshot and p and p.images[1]and p.images[2]and p.images[1]:getWidth()==192 and p.images[2]:getWidth()==192 and(p.stats[1].elapsed or 0)>120 then
   screenshot=true;love.graphics.captureScreenshot(function(data)
    local png=data:encode('png');local file=assert(io.open(output:gsub('json$','png'),'wb'));file:write(png:getString());file:close();png:release();data:release()
   end)
  end
  if #players==2 and players[1].duel.state=='finished'and players[2].duel.state=='finished'then
   assert(players[1].checkpoint==players[2].checkpoint,'Native checkpoints differ')
   assert(players[1].duel.localScore==players[2].duel.remoteScore and players[2].duel.localScore==players[1].duel.remoteScore,'Final scores differ between peers')
   assert((images[1]or 0)>0 and(images[2]or 0)>0,'Both players must receive real opponent pictures')
   assert(fullImages[1]>0 and fullImages[2]>0,'Both clients must receive full-table opponent pictures')
   assert(players[1].duel.localScore>0 or players[2].duel.localScore>0,'Gameplay must score points')
   finish(true)
  elseif love.timer.getTime()-started>75 then error('Network duel timed out')end
 end)
 if not ok then finish(false,tostring(why))end
end
function love.draw()
 local w,h=love.graphics.getDimensions()
 if players[1]then players[1]:draw(w,h)end
end
function love.quit()if not closed then finish(false,'Interrupted')end end
