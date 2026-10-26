-- Runs the native link state above the current overworld; no adventure boot
-- or ROM transfer is involved. Friend battles are unranked.
local L={}
local Task=require('src.cloud.Task')
local Auth=require('src.cloud.RetroCloud')
local function clone(v) local S=require('src.core.SaveSerializer');return S.decode(S.encode(v)) end
function L.start(game,invite)
 if not game or not require('src.cloud.Play').context(game).available then return nil,'Return to the overworld before connecting.' end
 if invite.edition~=require('src.core.GameVersion').get() or invite.mode=='meet' then return nil,'Open the matching edition first.' end
 if require('src.link.FriendTrade').pending() then return nil,'Finish recovering your previous trade first.' end
 if not game.save.party or #game.save.party==0 then return nil,'Choose a party before connecting.' end
 local ok,why=game:writeSave();if not ok then return nil,'Could not checkpoint your adventure: '..tostring(why) end
 require('src.ui.RetroOverlay').clear()
 local state=require('src.link.LinkState').new(game)
 local account=Auth.accountId();local mode=invite.mode;local hello=require('src.link.Handshake')
 local party=require('src.link.Protocol').packParty(game.save.party);local frozen=clone(party)
 local originalSave=mode=='battle' and game.save or nil
 if originalSave then game.save=clone(game.save) end
 local write=game.writeSave
 if originalSave then game.writeSave=function()return nil,'Friend battles do not change your adventure save.'end end
 local started=false;local cleaned=false;local job;local purpose;local nextPoll=0;local deadline=love.timer.getTime()+90
 local function cleanup()
  if cleaned then return end;cleaned=true
  if job then job:cancel();job=nil end
  if state.net then state.net:close() end
  if originalSave then game.save=originalSave;game.writeSave=write end
  require('src.link.FriendWager').closed(game,invite)
  game.linkSession=nil;game.linkNet=nil;L.active=nil
  if not invite.wager and (mode~='trade' or not require('src.link.FriendTrade').read(invite.id)) then
   L.retiring=L.retiring or {};L.retiring[#L.retiring+1]={account=account,id=invite.id}
  end
  require('src.cloud.Play').refresh()
 end
 local exit=state.exitWith
 state.exitWith=function(self,message,reason) cleanup();return exit(self,message,reason) end
 local update=state.update
 state.net=require('src.link.CloudNet').new(invite.id,invite.id,invite.id,'',function(payload)
  return require('src.cloud.Play').request('POST','invites/'..invite.id..'/wire',payload)
 end)
 state.discordCodeSet=true
 state.arenaContext=mode=='battle' and {seed=invite.seed,onFinished=function(result)
  require('src.link.FriendWager').finished(game,invite,result)
 end} or nil
 state.sendHello=function(self,selected)
  self.myHello=hello.hello(game,selected);self.myHello.friendLink={id=invite.id,account=account}
  self.net:send(self.myHello)
 end
 local decide=state.decideCompat
 state.decideCompat=function(self,selected,host)
  if not self.peerHello then return end
  local peer=self.peerHello.friendLink
  if selected~=mode or not peer or peer.id~=invite.id or peer.account~=invite.peer then return self:exitWith('This peer does not match your invitation.') end
  self.friendVerified=true
  decide(self,selected,host)
  if self.stage=='battleOptions' then self.forceLevel=nil;self:startMode('battle',true) end
 end
 if mode=='trade' then
  local send=state.net.send
  state.net.send=function(net,message)
   if message.type=='confirm' and message.ok then
    local kept,problem=require('src.link.FriendTrade').keep(game,invite.id)
    if not kept then return net:fail('Could not protect the trade save: '..tostring(problem)) end
   end
   return send(net,message)
  end
  state.beforeTradeApply=function(self,t)
   if self.tradePrepared then return true end
   if not job and love.timer.getTime()>=(self.nextReceipt or 0) then self.nextReceipt=love.timer.getTime()+1;purpose='receipt';job=Task.new(function()return require('src.cloud.Play').request('GET','invites/'..invite.id..'/receipt')end) end
   return false
  end
  state.onTradeSaved=function(_,saved,problem,evo)
   game.friendTradeAnimating=evo~=nil
   if saved then require('src.link.FriendTrade').saved(game,invite.id,not evo)
   else L.notice='Trade confirmed in your account. Local save failed; recovery will retry: '..tostring(problem) end
  end
  state.onTradeEvolutionSaved=function(_,saved,problem)
   game.friendTradeAnimating=nil
   if saved then require('src.link.FriendTrade').saved(game,invite.id,true) else L.notice='Trade evolution needs save recovery: '..tostring(problem) end
  end
 end
 state.update=function(self,dt)
  if cleaned then return end
  if not Auth.signedIn() or Auth.accountId()~=account then return self:exitWith('The account changed. Your adventure was kept.') end
  if job then
   local r=job:poll()
   if r then
    job=nil
    if r.kind~='done' or not r.first then return self:exitWith(tostring(r.second or r.error or 'Friend link unavailable.')) end
    if purpose=='receipt' then
     if r.first.receipt then
      local kept,problem=require('src.link.FriendTrade').prepare(game,invite.id,r.first.receipt)
      if not kept then return self:exitWith(tostring(problem)) end;self.tradePrepared=true
     elseif r.first.state~='accepted' then return self:exitWith('The trade was not committed. Your recovery record was kept.') end
    elseif r.first.ready then
     if mode=='battle' then self.arenaContext.peerParty=r.first.peer_party end
     started=true;game.linkNet=self.net;self.stage=invite.host==account and 'onlineHosting' or 'onlineJoining'
    end
   end
  end
  if started and not self.friendVerified and love.timer.getTime()>deadline then return self:exitWith('Your friend did not complete the link handshake.') end
  if not started then
   if game.input:wasPressed('b') then return self:exitWith('Friend link cancelled.') end
   if love.timer.getTime()>deadline then return self:exitWith('Your friend did not enter in time.') end
   if not job and love.timer.getTime()>=nextPoll then
    nextPoll=love.timer.getTime()+1;purpose='enter'
    job=Task.new(function() return require('src.cloud.Play').request('POST','invites/'..invite.id..'/enter',{party=require('src.link.Json').encode(frozen),fingerprint=hello.hello(game,mode).fingerprint}) end)
   end
   return
  end
  if self.stage=='battleRunning' and game.stack:top()==self then return self:exitWith(nil) end
  update(self,dt)
  if self.stage=='modeSelect' then self:sendHello(mode);self.pendingMode=mode;self.helloWait=0;self.stage='waitHello' end
 end
 local draw=state.draw
 state.draw=function(self,...)
  if started then return draw(self,...) end
  love.graphics.setColor(.04,.07,.11);love.graphics.rectangle('fill',0,0,512,384);love.graphics.setColor(1,1,1)
  require('src.render.Font').draw('CONNECTING WITH FRIEND',8,20);require('src.render.Font').draw('B: return to your game',8,60)
 end
 L.active={game=game,state=state,cleanup=cleanup,account=account};game.stack:push(state)
 return true
end
function L.tick(game)
 if L.active and (not Auth.signedIn() or L.active.account~=Auth.accountId() or L.active.game~=game or not L.active.game.linkSession) then L.active.cleanup() end
 local retired=L.retiring or {}
 for i=#retired,1,-1 do
  local row=retired[i]
  if row.account~=Auth.accountId() or not Auth.signedIn() then if row.job then row.job:cancel() end;table.remove(retired,i)
  elseif row.job then if row.job:poll() then table.remove(retired,i) end
  else row.job=Task.new(function()return require('src.cloud.Play').request('POST','invites/'..row.id..'/cancel',{})end) end
 end
 local trades=require('src.link.FriendTrade').tick(game)
 local wager=require('src.link.FriendWager');local blocked=not trades and wager.tick(game) or false;wager.blocked=blocked
 return trades or blocked
end
return L
