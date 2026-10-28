-- Shared social services and explicit progress sync; no second friend roster.
-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
local M={}
local Auth=require('src.cloud.RetroCloud')
local Strings=require('src.core.Strings')
function M.friends()
 local doc=require('src.cloud.Presence').read()
 if not doc or os.time()-(doc._receivedAt or 0)>90 then return nil end
 return doc.friends or{}
end
function M.openAccount(screen,view,peer)
 local host=screen.host;if not host then return end
 host:_openAccount()
 local overlay=host._accountOverlay
 if overlay and Auth.signedIn()then overlay.afterView=peer and('chat:'..peer)or view end
end
function M.install(P)
 P.TILES[#P.TILES+1]={id='online',label='Friends & cloud'}
 local update=P.update
 function P:reviewWalkerConflict(choice)
  if self._walkerConflictTask then return end
  local preview=self._walkerConflict
  self._walkerConflictTask=require('src.cloud.Task').new(function()
   local store,why=Auth.open();if not store then return nil,why end
   local cloud=require('src.pokewalker.WalkerCloud')
   if not choice then return cloud.review(store)end
   local resolved,err=cloud.resolve(store,preview,choice)
   return resolved and{resolved=resolved}or nil,err
  end)
 end
 function P:update(dt)
  if self._walkerConflict and self._walkerConflict.accountId~=Auth.accountId()then self._walkerConflict=nil end
  update(self,dt)
  if self._walkerConflictTask then
   local result=self._walkerConflictTask:poll()
   if result then
    self._walkerConflictTask=nil
    if result.kind=='done'and result.first then
     if result.first.resolved then
      self._walkerConflict=nil;self.st=require('src.pokewalker.Walker').load()
      self:say(Strings('Pokéwalker: %s',Strings(result.first.resolved)))
     elseif result.first.accountId==Auth.accountId()then self._walkerConflict=result.first end
    else self._walkerConflict=nil;self:say(Strings(result.error or result.second or'Pokéwalker progress changed. Review both versions again.'))end
   end
  end
 end
 function P:pageOnline(x,y,w,h,f)
  local top=y;local g=love.graphics
  local function line(value)
   g.setFont(f.body);P._setc(P.COLORS.INK)
   local _,wrapped=f.body:getWrap(value,math.max(40,w-24))
   g.printf(value,x+12,y,w-24,'left');y=y+math.max(1,#wrapped)*f.body:getHeight()+12
  end
  local function button(label,fn)
   label=Strings(label)
   local _,wrapped=f.body:getWrap(label,math.max(30,w-48))
   local hh=math.max(42,math.max(1,#wrapped)*f.body:getHeight()+20)
   self:button(x+12,y,w-24,hh,'',fn,'accent',f.body)
   g.setFont(f.body);P._setc(P.COLORS.INK)
   g.printf(label,x+24,y+10,w-48,'center');y=y+hh+12
  end
  line(Strings('POKÉWALKER · FRIENDS & CLOUD'))
  local function withdrawButton()
   button('WITHDRAW MINIGAME ACCEPTANCE',function()
    local ok,why=require('src.pokewalker.minigames.Enrollment').revoke()
    self:say(ok and Strings('Acceptance withdrawn. Minigames require confirmation again.')or Strings(why or'The confirmation could not be saved. Minigames remain locked.'))
   end)
  end
  if not Auth.signedIn()then
   line(Strings('Walks and minigames work without an account. Sign in for your friends, chat and private cloud progress.'))
   button('SIGN IN / REGISTER',function()M.openAccount(self)end)
   withdrawButton()
   return math.max(h,y-top)
  end
  line(Strings('Cloud progress includes walks, watts, items, achievements and minigame records. Conflicting rewards are never merged.'))
  local sync=require('src.storage.SyncStatus').get()
  if sync then line(Strings(require('src.storage.SyncStatus').describe(sync)))end
  button('SYNC POKÉWALKER & SAVES',function()
   if self.host and self.host._storageSync then self.host:_storageSync()end
  end)
  button('REVIEW CONFLICTING PROGRESS',function()self:reviewWalkerConflict()end)
  local choice=self._walkerConflict
  if choice and choice.accountId~=Auth.accountId()then choice=nil;self._walkerConflict=nil end
  if choice then
   line(Strings('Choose one complete version. Both copies are kept for recovery; rewards are never added together.'))
   line(Strings('This device: %d W · Walking: %s',choice.localWatts,choice.localWalking or Strings('None')))
   line(Strings('Cloud: %d W · Walking: %s',choice.cloudWatts,choice.cloudWalking or Strings('None')))
   button('KEEP THIS DEVICE VERSION',function()self:reviewWalkerConflict('local')end)
   button('USE THE CLOUD VERSION',function()self:reviewWalkerConflict('cloud')end)
  end
  button('FRIENDS',function()M.openAccount(self,'friends')end)
  button('INBOX',function()M.openAccount(self,'inbox')end)
  withdrawButton()
  local rows=M.friends()
  if not rows then line(Strings('Friend status is refreshing. Open Friends to check availability.'))
  elseif #rows==0 then line(Strings('Your accepted friends appear here. Requests need the other player’s confirmation.'))
  else
   local Role=require('src.ui.PlayerRole')
   for i,peer in ipairs(rows)do
    if i>20 then line(Strings('Open Friends to see the complete list.'));break end
    local status=peer.online and(peer.status=='away'and'AWAY'or'ONLINE')or'OFFLINE'
    line(Role.label(peer.friend_tag or peer.nickname,peer)..' · '..Strings(status))
    for _,device in ipairs(peer.playing or{})do
     local info=require('src.core.GameVersion').info(device.edition)
     line(Strings(info and(info.label or info.displayName)or device.edition))
    end
    local id=tostring(peer.account_id)
    button('CHAT',function()M.openAccount(self,nil,id)end)
   end
  end
  line(Strings('Minigame records are personal records. Shared real-time minigame duels are not available in this build.'))
  return math.max(h,y-top)
 end
end
return M
