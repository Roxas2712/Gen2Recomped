-- Device-bound friend invitations and opt-in map presence.
local P={}
local Auth=require('src.cloud.RetroCloud')
local Task=require('src.cloud.Task')
local Version=require('src.core.GameVersion')
local function now() return love.timer.getTime() end
function P.request(method,path,payload)
 if not Auth.signedIn() then return nil,'Sign in to connect with friends.' end
 local account=Auth.accountId();local doc,why,status=require('src.cloud.NativeAccount').request(method,'/play/'..path,payload,true)
 if not Auth.signedIn() or account~=Auth.accountId() or doc and tostring(doc.account_id)~=account then return nil,'The active account changed.' end
 return doc,why,status
end
function P.context(game)
 local context={available=false}
 if not game and P.externalContext then return P.externalContext end
 if not game or not game.data or not game.save then return context end
 context.edition=Version.get()
 if P.data~=game.data or P.version~=context.edition then
  P.data=game.data;P.version=context.edition;P.hello=require('src.link.Handshake').hello(game,'battle')
 end
 context.fingerprint=P.hello.fingerprint
 local world=game.overworld;local top=game.stack and (game.stack.active and game.stack:active() or game.stack:top())
 local menu=package.loaded['src.ui.RetroOverlay']
 local wager=package.loaded['src.link.FriendWager']
 context.available=world~=nil and top==world and not game.linkSession and not game.retroArena and not (wager and wager.blocked and not wager.readyInvite) and not (menu and menu.job) and not world.transitioning and not (world.runner and world.runner:isRunning()) and #(world.scriptMoves or {})==0 and not (world.player and world.player.inputLocked) and require('src.link.Handshake').onlineAllowed(game)
 if world and world.map and world.player then
  local navigation=require('src.world.FriendMap').describe(world)
  if navigation then context.zone={map=tostring(world.map.id),navigation=navigation} end
 end
 if context.available and world.map and world.player then
  local player=world.player
  context.position={map=tostring(world.map.id),x=player.px,y=player.py,facing=player.facing,
   navigation=require('src.world.FriendMap').describe(world)}
 end
 return context
end
function P.setExternalContext(owner,context)
 P.externalOwner=owner;P.externalContext=context
end
function P.clearExternalContext(owner)
 if P.externalOwner==owner then P.externalOwner=nil;P.externalContext=nil;P.refresh(true)end
end
function P.read()
 if Auth.signedIn() and Auth.accountId()==P.account and P.doc and now()-(P.received or 0)<15 then return P.doc end
end
function P.refresh(invalidate) P.next=0;if invalidate then P.doc=nil end end
function P.tick(game)
 local account=Auth.signedIn() and Auth.accountId() or nil
 if P.account~=account then
  if P.job then P.job:cancel() end
  P.account=account;P.doc=nil;P.job=nil;P.next=0;P.data=nil;P.entered={}
 end
 require('src.link.CloudNet').pump()
 local blocked=require('src.link.FriendLink').tick(game)
 if not account then return blocked end
 local ctx=P.context(game);local key=tostring(ctx.edition)..':'..tostring(ctx.fingerprint)
 if P.contextKey~=key then
  if P.job then P.job:cancel() end
  P.contextKey=key;P.job=nil;P.doc=nil;P.next=0
 end
 if P.job then
  local r=P.job:poll()
  if r then
   P.job=nil
   if r.kind=='done' and r.first then P.doc=r.first;P.error=nil;P.received=now();require('src.cloud.Presence').accept(r.first)
   else P.error=tostring(r.second or r.error or 'Friend connection unavailable.');P.next=now()+5 end
  end
 elseif now()>=(P.next or 0) then
  P.next=now()+((game or ctx.edition=='pinballrs')and 1 or 20)
  P.job=Task.new(function() return P.request('POST','presence',ctx) end)
 end
 local doc=P.read()
 local wager=package.loaded['src.link.FriendWager']
 if game and doc and (not blocked or wager and wager.readyInvite) and P.context(game).available then
  for _,invite in ipairs(doc.invites or {}) do
   if invite.mode~='meet' and invite.mode~='pinball' and invite.state=='accepted' and (not blocked or wager.readyInvite==invite.id) and not (P.entered and P.entered[invite.id]) then
    local ok,why=require('src.link.FriendLink').start(game,invite)
    if ok then P.entered=P.entered or {};P.entered[invite.id]=true;blocked=false;break else P.error=why end
   end
  end
 end
 return blocked
end
return P
