-- Two separate LÖVE processes against the real local HTTPS ModCompass server.
-- Real Friends / CloudNet / Duel / Player / native worker. By Roxas2712.
local Json=require('src.link.Json')
local fixturePath=assert(os.getenv('PINBALL_HTTP_CONFIG'))
local f=assert(io.open(fixturePath,'rb'));local config=Json.decode(f:read('*a'));f:close()
assert(config.url:match('^https://localhost:%d+/api/cloud/v1/play/$')or config.publicQualification==true and config.url=='https://pokexpert.de/api/cloud/v1/play/','explicit isolated HTTPS qualification only')
local started=love.timer.getTime();local doc,job,nextPresence,player,friends,net= nil,nil,0
local preparedFromMissing=false;local invited=false;local pendingAccept;local result,finishedAt,completionWait,captured,minimized,reported
local updateGaps={};local priorUpdate;local activityStatus;local steadyRestarts;local steadyStart;local capturedAt;local minimizedAt
local Auth={signedIn=function()return true end,accountId=function()return config.account end}
package.loaded['src.cloud.RetroCloud']=Auth
local Http=require('src.cloud.Http');local Task=require('src.cloud.Task')
local CloudNet=require('src.link.CloudNet');local Friends=require('src.pinball.Friends')
local Play={read=function()return doc end,refresh=function()nextPresence=0 end}
function Play.request(method,path,payload)
 local status,body=Http.request(method,config.url..path,{sensitive=true,headers={Authorization='Bearer '..config.token,['Content-Type']='application/json',Accept='application/json'},body=Json.encode(payload)})
 if status~=200 then
  local ok,errorDoc=pcall(Json.decode,body or '')
  return nil,ok and type(errorDoc)=='table'and errorDoc.message or ('HTTP '..tostring(status)),status
 end
 return Json.decode(body)
end
local function client(session)
 return Friends.new(session,{auth=Auth,task=Task,net=CloudNet,play=Play,field=config.field,
  prepare=function(invite)
   assert(invite and not session,'only the initially missing private import is activated here')
   preparedFromMissing=true;pendingAccept=invite.id;friends=client(config.session);doc=nil;nextPresence=0
  end,
  start=function(transport,host,rules)
   assert(not player,'only one native start per client');net=transport
   player=require('src.pinball.Player').new(config.session,{net=transport,host=host,duel=true,field=rules.field,diagnostics=true,forceRelay=config.peer_mode=='relay',opponent='HTTPS QA FRIEND'})
   player.sound:setVolume(0)
   activityStatus={active=player.activity.active,error=player.activity.error,priorityBefore=player.activity.priorityBefore}
   player.input.buttons=function()
    local st=player.stats[1]or{};local step=st.elapsed or 0
    local period=config.seat==1 and 120 or 97
    return step%period<period*.46 and 1 or step%period<period*.92 and 32 or 0
   end
   return true
  end})
end
friends=client(config.seat==1 and config.session or nil)
local function report(ok,why)
 reported=true
 local value={passed=ok,error=why,seat=config.seat,transport=config.publicQualification and 'actual public HTTPS' or 'actual local HTTPS',native=player~=nil,
  prepared_from_missing=preparedFromMissing,result=result,seconds=love.timer.getTime()-started,
  checkpoint=player and player.checkpoint,stats=player and player.stats[1],duel=player and player.duel and {
   state=player.duel.state,localScore=player.duel.localScore,remoteScore=player.duel.remoteScore,
   localFrame=player.duel.localFrame,remoteFrame=player.duel.remoteFrame},wire_drained=net and net.finished or false,
  activity=activityStatus,update_gaps=updateGaps,
  steady_audio_restarts=steadyRestarts and ((player.audioRestarts or 0)-steadyRestarts),steady_seconds=steadyStart and (love.timer.getTime()-steadyStart),
  capture_at=capturedAt,minimize_at=minimizedAt,audio_history=player and player.audioRestartHistory,
  peer_view=player and player.peerView and {path=player.peerView.path,sent=player.peerView.sent,received=player.peerView.received,directFrames=player.peerView.directFrames,relayFrames=player.peerView.relayFrames,error=player.peerView.error,forcedFallback=player.forcedFallback},
  producer=player and player.diagnostics,audio_restarts=player and player.audioRestarts or 0,wire_error=net and net.error,
  opponent_view=player and player.liveView and {frame=player.liveView.frame,received=player.liveView.received,error=player.viewFailed}}
 local file=assert(io.open(config.output,'wb'));file:write(Json.encode(value));file:close()
end
love.load=function()love.window.setTitle('Pinball HTTPS · QA '..config.seat..' · separates Profil')end
love.update=function(dt)
 local ok,why=pcall(function()
  local now=love.timer.getTime()
  if player and priorUpdate then local gap=now-priorUpdate;updateGaps.maximum=math.max(updateGaps.maximum or 0,gap);if gap>.1 then updateGaps.over100ms=(updateGaps.over100ms or 0)+1 end end
  priorUpdate=now
  assert(now-started<390,'Native HTTPS duel did not finish within 390 seconds')
  if job then
   local response=job:poll()
   if response then job=nil;assert(response.kind=='done'and response.first,tostring(response.second or response.error));doc=response.first end
  elseif now>=nextPresence then
   nextPresence=now+.8
   local context=friends:context(not player)
   job=Task.new(function()return Play.request('POST','presence',context)end)
  end
  friends:tick(not player)
  if not player and doc then
   if config.seat==1 and not invited and doc.friends[1]and doc.friends[1].online then
    assert(friends:action('pinball:inviteaccount:'..doc.friends[1].account_id));invited=true
   elseif config.seat==2 then
    for _,invite in ipairs(doc.invites or{})do
     if invite.incoming and invite.state=='pending'and not friends.job then
      if pendingAccept then
       if friends:compatible(invite.rules)and doc.device then friends:action('pinball:accept:'..invite.id);pendingAccept=nil end
      else friends:action('pinball:accept:'..invite.id)end
      break
     end
    end
   end
   if friends.notice then error(friends.notice)end
  end
  if player then
   if not finishedAt then
    player:update(dt)
    if config.peer_mode=='switch'and not player.forcedFallback and now-started>70 and player.peerView and player.peerView.net.direct then
     player.forcedFallback=true;player.peerView.net.options.forceRelay=true;player.peerView.net.native:drop()
    end
    if now-started>60 and not steadyStart then steadyStart=now;steadyRestarts=player.audioRestarts or 0 end
    assert(not player.error,tostring(player.error))
    assert(player.duel.state~='cancelled',tostring(player.duel.error))
    assert(not player.viewFailed,tostring(player.viewFailed))
    if not captured and now-started>35 and player.images[2]then
     captured=true;capturedAt=now
     love.graphics.captureScreenshot(function(image)
      local png=image:encode('png');local file=assert(io.open(config.output..'.png','wb'));file:write(png:getString());file:close();png:release()
     end)
    end
    if player.duel.state=='finished'then
     result=player.duel.result;completionWait=completionWait or now
     assert(now-completionWait<20,'Opponent live picture did not arrive')
     if player.liveView and player.liveView.received>0 and player.images[2] then finishedAt=now;player:stop()end
    end
   elseif not player.thread:isRunning()then
    if net.finished then report(true);player:dispose();love.event.quit(0)
    else assert(now-finishedAt<15,'Final HTTPS wire ACKs did not drain')end
   end
  end
  if captured and not minimized and now-started>40 then minimizedAt=now;love.window.minimize();minimized=true end
  CloudNet.pump()
 end)
 if not ok then
  report(false,tostring(why));if player then player:stop()end;love.event.quit(1)
 end
 love.timer.sleep(.004)
end
love.draw=function()
 if player then player:draw(love.graphics.getDimensions())end
end
love.quit=function()if not reported then report(false,'The separate QA window closed before the duel finished.')end;if player and player.thread:isRunning()then player:stop();player.thread:wait()end end
