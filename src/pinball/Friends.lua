-- Pinball invitations through the shared ModCompass friend/account service.
-- Contributions by Roxas2712. No cartridge, credentials or solo saves in peer data.
local M={};M.__index=M
local Strings=require('src.core.Strings')
local function uuid(s)return type(s)=='string'and #s==36 and s:match('^[a-f0-9%-]+$')end
local function accountId(s)return type(s)=='string'and #s<=20 and s:match('^[1-9][0-9]*$')end
local function now()return love.timer.getTime()end
local function account(Auth)return Auth.signedIn()and Auth.accountId()or nil end
function M.fingerprint(session)
 if not session then return end
 local bytes=table.concat({'pinball-duel-v1',session.rom_sha1,session.backend,session.content},'\n')
 return love.data.encode('string','hex',love.data.hash('sha256',bytes))
end
function M.new(session,options)
 options=options or {}
 local self=setmetatable({session=session,options=options,Auth=options.auth or require('src.cloud.RetroCloud'),
  Play=options.play or require('src.cloud.Play'),Task=options.task or require('src.cloud.Task'),
  Net=options.net or require('src.link.CloudNet'),fingerprint=M.fingerprint(session)or false,seen={},state='idle',nextEnter=0},M)
 self.account=account(self.Auth);return self
end
function M:context(available)
 if not self.session then return {available=false}end
 return {edition='pinballrs',fingerprint=self.session and self.fingerprint or nil,available=self.session~=nil and available==true and self.state=='idle',
  pinball={protocol=1,field=self.options.field or 0,frames=18000,locale=self.session.locale or 'en'}}
end
function M:rules()
 if not self.session then return end
 return {protocol=1,field=self.options.field or 0,frames=18000,seed=0,rom=self.session.rom_sha1,
  backend=self.session.backend,content=self.session.content,locale=self.session.locale or 'en'}
end
function M:compatible(r)
 return self.session~=nil and type(r)=='table'and r.protocol==1 and(r.field==0 or r.field==1)and r.frames==18000 and r.seed==0
  and r.rom==self.session.rom_sha1 and r.backend==self.session.backend and r.content==self.session.content
  and r.locale==(self.session.locale or 'en')
end
function M:request(purpose,path,payload)
 if self.job then self.notice=Strings("The current ModCompass request is still finishing.");return false end
 if not account(self.Auth)then self.notice=Strings("Sign in to ModCompass for friend duels.");return false end
 local identity=account(self.Auth)
 self.job=self.Task.new(function()
  if identity~=account(self.Auth)then return nil,Strings("The active account changed.")end
  return self.Play.request('POST',path,payload)
 end)
 if not self.job then self.notice=Strings("Background connections are unavailable.");return false end
 self.purpose=purpose;return true
end
function M:document()return self.Play.read()end
function M:invitation(id)
 for _,i in ipairs((self:document()or {}).invites or {})do if i.id==id and i.mode=='pinball'and i.edition=='pinballrs'then return i end end
end
function M:action(id)
 local op,value=id:match('^pinball:(%a+):([a-f0-9%-]+)$')
 if not op or not((op=='inviteaccount'and accountId(value))or uuid(value))then return false end
 if op=='inviteaccount'then
  local found
  for _,peer in ipairs((self:document()or {}).friends or {})do if tostring(peer.account_id)==value then found=peer end end
  if not found or not found.online or self.state~='idle'then self.notice=Strings("This friend cannot receive a game invitation right now.");return true end
  if not self.session then
   if self.options.prepare then self.options.prepare(nil,value)end
   return true
  end
  self:request('invite','invites',{account=value,mode='pinball',rules=self:rules(),fingerprint=self.fingerprint})
 elseif op=='invite'then
  local found
  for _,friend in ipairs((self:document()or {}).friends or {})do
   for _,device in ipairs(friend.playing or {})do
    if device.device==value and device.edition=='pinballrs'and device.available and device.compatible then found=true end
   end
  end
  if not found or self.state~='idle'then self.notice=Strings("This friend is not ready for this Pinball duel.");return true end
  self:request('invite','invites',{device=value,mode='pinball',rules=self:rules(),fingerprint=self.fingerprint})
 elseif op=='accept'or op=='decline'or op=='cancel'then
  local i=self:invitation(value)
  if not i or (op~='cancel'and(i.state~='pending'or not i.incoming))then self.notice=Strings("This invitation is no longer available.");return true end
  if op=='accept'and not self:compatible(i.rules)then
   if self.options.prepare then self.options.prepare(i)
   else self.notice=Strings("Game version, language or Pinball build do not match.")end
   return true
  end
  if op=='cancel'and self.active and self.active.id==value then
   if self.job then self.job:cancel();self.job=nil end
   self:retire()
  end
  self:request(op,'invites/'..value..(op=='cancel'and'/cancel'or'/respond'),{accept=op=='accept'})
 else return false end
 return true
end
function M:retire()
 if self.net then self.net:close();self.net=nil end
 self.active=nil;self.state='idle';self.nextEnter=0
end
function M:finished()
 if self.active then
  local id=self.active.id;self.seen[id]=true
  if self.job then self.job:cancel();self.job=nil;self.purpose=nil end
  self:retire();self:request('cancel','invites/'..id..'/cancel',{})
 end
end
function M:close()
 if self.job then self.job:cancel();self.job=nil end
 self:retire()
end
function M:tick(available)
 local identity=account(self.Auth)
 if self.account~=identity then
  local playing=self.state=='playing'
  self:close();self.account=identity;self.seen={}
  if playing and self.options.stop then self.options.stop(Strings("The ModCompass account changed."))end
 end
 if not identity then return end
 if self.job then
  local response=self.job:poll()
  if response then
   local purpose=self.purpose;self.job=nil;self.purpose=nil
   if response.kind~='done'or not response.first then
    self.notice=tostring(response.second or response.error or Strings("ModCompass connection failed."))
    if purpose=='enter'then self:retire()end
   else
    self.notice=nil
    if purpose=='enter'and self.active and response.first.ready then
     local invite=self.active
     self.net=self.Net.new(invite.id,invite.id,invite.id,'',function(payload)
      return self.Play.request('POST','invites/'..invite.id..'/wire',payload)
     end,{drainPeer=true})
     self.net.peerTicket=function()return self.Play.request('POST','invites/'..invite.id..'/transport',{})end
     self.state='playing'
     local ok,why=self.options.start(self.net,tostring(invite.host)==identity,invite.rules,invite.nickname)
     if not ok then self.notice=tostring(why or Strings("Pinball could not be started."));self:finished()end
    elseif purpose~='enter'then self.Play.refresh(true)end
   end
  end
 end
 if self.state=='entering'then
  if now()>self.deadline then self.notice=Strings("Your friend did not complete the shared start.");self:finished();return end
  if not self.job and now()>=self.nextEnter then
   self.nextEnter=now()+1
   self:request('enter','invites/'..self.active.id..'/enter',{fingerprint=self.fingerprint,rules=self.active.rules})
  end
  return
 end
 if self.state~='idle'or not available or self.job then return end
 for _,invite in ipairs((self:document()or {}).invites or {})do
  if invite.mode=='pinball'and invite.edition=='pinballrs'and invite.state=='accepted'and uuid(invite.id)and not self.seen[invite.id]then
   self.seen[invite.id]=true
   if not self:compatible(invite.rules)then self.notice=Strings("The accepted invitation does not match the language, game version or build.");return end
   local host,peer=tostring(invite.host),tostring(invite.peer)
   if not accountId(host)or not accountId(peer)or peer==identity or(host~=identity and host~=peer)then self.notice=Strings("Invalid invitation partner.");return end
   self.active=invite;self.state='entering';self.deadline=now()+90;self.nextEnter=0;return
  end
 end
end
local function title(i)return(i.rules and i.rules.field==1 and'SAPPHIRE'or'RUBY')..' · '..tostring(i.nickname or Strings("Friend"))end
function M:rows(peer)
 local rows={};local function add(id,label,note)rows[#rows+1]={id=id,label=label,note=note}end
 for _,i in ipairs((self:document()or {}).invites or {})do
  if not peer and i.mode=='pinball'and i.edition=='pinballrs'and uuid(i.id)then
   if i.state=='pending'and i.incoming then
    if self:compatible(i.rules)then add('pinball:accept:'..i.id,Strings("ACCEPT PINBALL · ")..title(i),Strings("5 minutes · fresh game · regular saves are kept."))
    else add('pinball:accept:'..i.id,Strings("PREPARE & ACCEPT PINBALL · ")..title(i),Strings("Prepare your matching import to continue this invitation."))end
    add('pinball:decline:'..i.id,Strings("Decline Pinball invitation"))
   elseif i.state=='pending'or i.state=='accepted'and self.state~='playing'then add('pinball:cancel:'..i.id,Strings("CANCEL PINBALL · ")..title(i),Strings("Waiting for the shared start."))end
  end
 end
 if peer then
  if peer.online and self.state=='idle'then
   add('pinball:inviteaccount:'..tostring(peer.account_id),Strings("INVITE TO PINBALL"),Strings("Invite this friend · a missing import can be prepared afterward."))
  end
  for _,d in ipairs(peer.playing or {})do
   if d.edition=='pinballrs'and uuid(d.device)then
    if d.available and d.compatible and self.state=='idle'then add('pinball:invite:'..d.device,Strings("INVITE TO PINBALL"),Strings("Selected table · 5 minutes · starts after acceptance and both players prepare."))
    else add('noop',Strings("PINBALL · not ready"),Strings("Both players need to open Pinball in the same language and build."))end
   end
  end
 end
 return rows
end
return M
