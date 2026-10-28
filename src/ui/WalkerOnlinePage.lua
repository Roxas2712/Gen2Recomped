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
  if not Auth.signedIn()then
   line(Strings('Walks and minigames work without an account. Sign in for your friends, chat and private cloud progress.'))
   button('SIGN IN / REGISTER',function()M.openAccount(self)end)
   return math.max(h,y-top)
  end
  line(Strings('Cloud progress includes walks, watts, items, achievements and minigame records. Conflicting rewards are never merged.'))
  local sync=require('src.storage.SyncStatus').get()
  if sync then line(Strings(require('src.storage.SyncStatus').describe(sync)))end
  button('SYNC POKÉWALKER & SAVES',function()
   if self.host and self.host._storageSync then self.host:_storageSync()end
  end)
  button('FRIENDS',function()M.openAccount(self,'friends')end)
  button('INBOX',function()M.openAccount(self,'inbox')end)
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
