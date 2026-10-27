local function L(value) return require('src.translation.Service').launcherLookup(value) end
local W={}
local Role=require('src.ui.PlayerRole')
local A=require('src.cloud.NativeAccount')
local Auth=require('src.cloud.RetroCloud')
local Task=require('src.cloud.Task')
local function inputMode(f,id)
  f.focus=id
  if love.keyboard and love.keyboard.setTextInput then love.keyboard.setTextInput(id~=nil) end
end
local function clearSecrets(f) f.moderationPassword='';f.password='';f.confirmation='';f.code='';f.giftCode='';f.rolePassword='';f.createdGift=nil end
local function job(self,purpose,fn)
  local f=self._accountOverlay;if f.job then return end
  local task,why=Task.new(fn);f.job=task;f.purpose=purpose
  f.notice=task and 'Connecting securely...' or tostring(why)
  inputMode(f,nil)
end
local function friends()
 local doc,why=require('src.cloud.Play').request('POST','presence',{available=false})
 if doc and A.request then local prefs=A.request('GET','/play/preferences',nil,true);doc.playPreferences=prefs and prefs.preferences end
 return doc,why
end
local function devices()
  local doc,why=A.devices()
  if doc and A.profile then doc.profile,doc.profileError=A.profile() end
  if doc and A.friends then doc.social,doc.socialError=friends() end
  if doc and A.presence then doc.presence=A.presence() end
  return doc,why
end
local function avatarImage(bytes)
  if type(bytes)~='string' or #bytes>2*1024*1024 or not require('src.import.ImageBounds').allowed(bytes,2048) then return nil,'Choose a PNG, JPEG or WebP up to 2048 pixels and 2 MB.' end
  local ok,image=pcall(function()
    local pixels=love.image.newImageData(love.filesystem.newFileData(bytes,'profile-image.png'))
    local w,h=pixels:getDimensions();if w>2048 or h>2048 then error('Choose an image up to 2048 pixels per side.',0) end
    local image=love.graphics.newImage(pixels);image:setFilter('linear','linear');return image
  end)
  return ok and image or nil,not ok and tostring(image) or nil
end
function W.avatarBytes(self,bytes)
  local f=self._accountOverlay
  if not f or (f.mode~='account' and f.mode~='profileEdit') or not Auth.signedIn() then return end
  local image,why=avatarImage(bytes);if not image then f.notice=why;return end
  f.avatarImage=image;f.avatarBytes=bytes;f.avatarRights=false;f.resetAvatar=false;f.notice='Image preview is local. Confirm the image rights and save to use it on your other devices.'
  return true
end
local function profile(self,doc)
  local f=self._accountOverlay;f.profile=doc;f.displayRole=doc.display_role;f.nickname=doc.name;f.friendTag=doc.friend_tag;f.profileName=doc.name;f.avatarBytes=nil;f.avatarRights=false;f.avatarImage=nil
  f.avatarPreset=doc.avatar_preset;f.avatarColor=doc.avatar_color;f.resetAvatar=false
  if type(doc.avatar)=='table' and type(doc.avatar.image_base64)=='string' then
    local ok,bytes=pcall(love.data.decode,'string','base64',doc.avatar.image_base64)
    if ok then
      local digest=love.data.encode('string','hex',love.data.hash('sha256',bytes))
      if digest==doc.avatar.sha256 then f.avatarImage=avatarImage(bytes) end
    end
  end
  require('src.cloud.AccountBadge').accept(doc,f.avatarImage)
end
function W.open(self,after)
  if self._developerOverlay then require('src.import.DeveloperWorkspace').close(self) end
  local choice=type(after)=='table' and after.storagePrompt and not (Auth.accountId and Auth.accountId())
  self._accountOverlay={mode=choice and 'storage_choice' or Auth.signedIn() and 'account' or 'login',after=after,email='',name='',password='',confirmation='',code='',repositories={''},restore=true,rects={},scroll=0,accountAtOpen=Auth.accountId and Auth.accountId()}
  if choice then return end
  local cached,image=require('src.cloud.AccountBadge').read()
  if cached then local f=self._accountOverlay;f.nickname=cached.name;f.friendTag=cached.friend_tag;f.displayRole=cached.display_role;f.avatarPreset=cached.avatar_preset;f.avatarColor=cached.avatar_color;f.avatarImage=image end
  job(self,Auth.signedIn() and 'devices' or 'policy',Auth.signedIn() and devices or A.policy)
end
function W.close(self)
  local f=self._accountOverlay;if f then require('src.ui.FriendChat').clear(f);if f.job then f.job:cancel() end;clearSecrets(f);f.challenge=nil;inputMode(f,nil) end
  self._accountOverlay=nil
end
local function connected(self,f)
  if Auth.accountId and Auth.accountId()~=f.accountAtOpen then require('src.storage.AccountStorage').profileChanged(self) end
  -- Restore is offered explicitly; uploads need their separate opt-in.
  local settings=self:_settings();settings.cloudAutoSync=f.cloudSync==true
  settings.cartridgeCloudSync=f.cloudSync==true
  settings.gameCacheDownload=f.restore~=false
  self._cloudRestoreOnce=f.restore~=false
  settings.launcherSaveStorageChoice=f.cloudSync and 'cloud' or 'local'
  if self._saveSettings then self:_saveSettings() end
  self._settingsRowCache=nil
  local after=f.after;W.close(self)
  if after=='developer' then self:_openDeveloper()
  elseif after=='browse' then self.findLoaded=false;self:_refreshFind(true)
  elseif after=='bank' or after=='bankDex' or after=='history' or type(after)=='table' and after.kind=='play' then require('src.storage.AccountStorage').resume(self,after)
  else W.open(self) end
end
function W.action(self,id)
  local f=self._accountOverlay;if not f then return end
  if id=='local' and not (Auth.accountId and Auth.accountId()) then
    local settings=require('src.core.SaveData').loadOptions()
    settings.launcherSaveStorageChoice='local';settings.cloudAutoSync=false
    if not require('src.core.SaveData').saveOptions(settings) then f.notice='Could not remember your local-save choice. Please retry.';return end
    self._settingsCache=nil
    local after=f.after;W.close(self)
    if type(after)=='table' and after.kind=='play' then return require('src.storage.AccountStorage').resume(self,after) end
    return
  end
  if id=='close' then W.close(self);return end
  if id=='back' and f.document then f.document=nil;f.scroll=0;return end
  if require('src.ui.FriendChat').action(f,id)then f.mode=f.chat and'friendChat'or'friends';f.scroll=0;return end
  if f.chat then require('src.ui.FriendChat').clear(f)end
  if f.job then return end
  if id:match('^field:') then inputMode(f,id:sub(7));return end
  inputMode(f,nil)
  if f.mode=='giftAdmin' and require('src.import.GiftDesigner').action(f,id) then f.scroll=0;return end
  if id=='cloud' then
    f.mode='login';f.cloudSync=true;f.scroll=0
    if not f.policy then job(self,'policy',A.policy) end
  elseif id=='login' or id=='register' or id=='forgot' or id=='back' then
    clearSecrets(f);f.challenge=nil;f.mode=id=='back' and 'login' or id;f.scroll=0;f.notice=nil
    if id=='register' and not f.policy then job(self,'policy',A.policy) end
  elseif id:match('^read:') then
    if not f.policy then job(self,'policy',A.policy);return end
    f.document=id:sub(6);f.scroll=0;f.padIndex=2;f.padActive=false
  elseif id:match('^toggle:') then local key=id:sub(8);f[key]=not f[key]
  elseif id=='addRepo' then f.repositories[#f.repositories+1]='';f.focus='repo'..#f.repositories;inputMode(f,f.focus)
  elseif id=='submit' then
    if f.mode=='login' then
      local email,password=f.email,f.password;job(self,'auth',function() return A.login(email,password) end);clearSecrets(f)
    elseif f.mode=='register' then
      if not f.policy then f.notice='Load the current terms before registering.';job(self,'policy',A.policy);return end
      if not f.terms or not f.privacy or f.developer and not f.rights then f.notice='Please review and accept the required account agreements.';return end
      local repositories={};if f.developer then for _,r in ipairs(f.repositories) do if r:match('%S') then repositories[#repositories+1]=r end end end
      local payload={name=f.name,email=f.email,password=f.password,password_confirmation=f.confirmation,developer=f.developer==true,repositories=repositories,
        terms_version=f.policy.version,terms_accepted=f.terms==true,privacy_acknowledged=f.privacy==true,developer_rights_accepted=f.rights==true}
      job(self,'auth',function() return A.register(payload) end);clearSecrets(f)
    elseif f.mode=='forgot' then local email=f.email;job(self,'auth',function() return A.forgot(email) end)
    elseif f.mode=='reset_code' then
      local challenge,code,password,confirmation=f.challenge,f.code,f.password,f.confirmation
      job(self,'auth',function() return A.reset(challenge,code,password,confirmation) end);clearSecrets(f)
    elseif f.challenge then local challenge,code=f.challenge,f.code;job(self,'auth',function() return A.complete(challenge,code) end);clearSecrets(f) end
  elseif id=='resend' and f.challenge then local challenge=f.challenge;job(self,'resend',function() return A.resend(challenge) end)
  elseif id=='operator' and f.policy and f.policy.operator_url=='https://pokexpert.de/impressum' then love.system.openURL(f.policy.operator_url)
  elseif id=='chooseAvatar' then
    local path=self._ui.chooseFileByExt({'png','jpg','jpeg','webp'},'profile image')
    if not path then f.notice='Drop a PNG, JPEG or WebP here to preview your profile image.';return end
    local file=io.open(path,'rb');if not file then f.notice='The profile image could not be read.';return end
    local bytes=file:read(2*1024*1024+1);file:close();W.avatarBytes(self,bytes)
  elseif id=='saveProfile' then
    if f.avatarBytes and not f.avatarRights then f.notice='Confirm your image rights before uploading.';return end
    local payload={name=f.profileName,avatar_preset=f.avatarPreset,avatar_color=f.avatarColor}
    if f.resetAvatar then payload.reset_avatar=true end
    if f.avatarBytes then payload.image_base64=love.data.encode('string','base64',f.avatarBytes);payload.avatar_rights=true end
    job(self,'profile',function() return A.profile(payload) end)
  elseif id=='resetAvatar' then job(self,'profile',function() return A.profile({reset_avatar=true}) end)
  elseif id=='profileEdit' or id=='accountSettings' or id=='transferGuide' then f.mode=id;f.scroll=0;f.notice=nil
  elseif id=='copyFriendTag' and f.friendTag and love.system.setClipboardText then love.system.setClipboardText(f.friendTag);f.notice='Friend tag copied.'
  elseif id:match('^avatarPreset:') then f.avatarPreset=id:sub(14);f.avatarImage=nil;f.avatarBytes=nil;f.avatarRights=false;f.resetAvatar=true
  elseif id=='avatarColor' then
    local colors=require('src.ui.ProfileAvatar').colors;local at=1;for i,c in ipairs(colors) do if c==f.avatarColor then at=i end end;f.avatarColor=colors[at%#colors+1]
  elseif id=='roles' then f.mode='roles';f.scroll=0;f.roleTarget='';f.roleChoice='retro_admin';f.roleReason=''
  elseif id=='roleChoice' then f.roleChoice=f.roleChoice=='retro_admin' and 'retro_superuser' or f.roleChoice=='retro_superuser' and 'player' or 'retro_admin'
  elseif id=='saveRole' then
    local payload={friend_tag=f.roleTarget,role=f.roleChoice,password=f.rolePassword,reason=f.roleReason};f.rolePassword=''
    job(self,'roles',function() return A.grantRole(payload) end)
  elseif id=='gifts' then f.mode='gifts';f.scroll=0;f.giftEdition=f.giftEdition or 'crystal';job(self,'gifts',A.gifts)
  elseif id=='giftEdition' then
    local versions=require('src.core.GameVersion').ORDER;local at=1
    for i,v in ipairs(versions) do if v==f.giftEdition then at=i end end
    repeat at=at%#versions+1 until versions[at]~='prism' and versions[at]~='polishedcrystal'
    f.giftEdition=versions[at]
  elseif id=='redeemGift' then
    local code,edition=f.giftCode or '',f.giftEdition or 'crystal';f.giftCode=''
    job(self,'giftReceived',function() return require('src.cloud.GiftCodes').redeem(code,edition) end)
  elseif id:match('^restoreGift:') then
    local receipt=f.gifts and f.gifts.receipts[tonumber(id:match(':(%d+)$'))]
    if receipt then
      if receipt.kind=='item' or receipt.kind=='event' then f.giftDelivery=receipt;f.mode='giftDelivery';f.scroll=0
      else job(self,'giftReceived',function() return require('src.cloud.GiftCodes').keep(receipt) end) end
    end
  elseif id:match('^giftDeliver:') then
    local index=tonumber(id:match(':(%d+)$'));local slot=f.giftSlots and f.giftSlots[index];local receipt=f.giftDelivery
    if slot and receipt then job(self,'giftDelivered',function() return require('src.storage.GiftItems').deliver(receipt,slot.version,slot.slot) end) end
  elseif id=='newGift' then f.createdGift=nil;f.mode='giftAdmin';f.giftTitle='';f.giftLimit='';f.giftSelected={crystal=true};f.scroll=0;require('src.import.GiftDesigner').init(f)
  elseif id:match('^giftFor:') then local version=id:sub(9);f.giftSelected[version]=not f.giftSelected[version]
  elseif id=='copyGiftCode' and f.createdGift and love.system.setClipboardText then love.system.setClipboardText(f.createdGift.code);f.notice='Gift code copied.'
  elseif id=='createGift' then
    local editions={};for _,v in ipairs(require('src.core.GameVersion').ORDER) do if (f.giftSelected or {})[v] then editions[#editions+1]=v end end
    local reward,why=require('src.import.GiftDesigner').payload(f);if not reward then f.notice=why or 'Choose a reward.';return end
    local payload=reward;payload.title=f.giftTitle;payload.editions=editions;payload.redemption_limit=tonumber(f.giftLimit)
    job(self,'giftCreated',function() return A.createGift(payload) end)
  elseif id:match('^giftActive:') then
    local campaign=f.gifts and f.gifts.campaigns[tonumber(id:match(':(%d+)$'))]
    if campaign then job(self,'giftActive',function() return A.activateGift(campaign.id,not campaign.active) end) end
  elseif id=='roleGuide' then f.mode='roleGuide';f.scroll=0;f.notice=nil
  elseif id=='presenceToggle' then
    local visible=not (require('src.cloud.AccountBadge').presence or {}).visible
    job(self,'presence',function()return A.presence({visible=visible})end)
  elseif id=='players' or id=='playersNext' or id=='playersPrevious' or id=='playersSearch' or id=='playersOnline' then
    f.mode='players';f.scroll=0
    if id=='playersOnline' then f.playersOnline=not f.playersOnline end
    f.playersPage=math.max(1,(id=='playersSearch' and 1 or f.playersPage or 1)+(id=='playersNext' and 1 or id=='playersPrevious' and -1 or 0))
    local page,query,online=f.playersPage,f.playersQuery or '',f.playersOnline
    job(self,'players',function()return A.players(page,query,online)end)
  elseif id:match('^playerFriend:') then
    local at=tonumber(id:match(':(%d+)$'));local peer=f.players and f.players.players[at]
    if peer then local tag=peer.friend_tag;job(self,'playerFriend',function()return A.addFriend(tag)end)end
  elseif id:match('^playerManage:') then
    local at=tonumber(id:match(':(%d+)$'));local peer=f.players and f.players.players[at]
    if peer then local key=peer.account_id;f.player=nil;f.mode='playerManage';f.scroll=0;job(self,'player',function()return A.player(key)end)end
  elseif id=='playerRoles' and f.player then f.roleTarget=f.player.friend_tag;f.mode='roles';f.scroll=0;f.roleChoice='retro_admin';f.roleReason='';f.rolePassword=''
  elseif id:match('^moderate:') then f.moderationAction=id:sub(10);f.moderationReason='';f.moderationPassword='';f.mode='moderate';f.scroll=0
  elseif id=='moderationCancel' then f.moderationPassword='';f.moderationReason='';f.moderationAction=nil;f.mode='playerManage';f.scroll=0
  elseif id=='moderationConfirm' and f.player and f.moderationAction then
    if #(f.moderationReason or '')<15 then f.notice='Explain the reason in at least 15 characters.';return end
    local id=f.player.account_id;local payload={action=f.moderationAction,password=f.moderationPassword,reason=f.moderationReason,confirmed=true};f.moderationPassword=''
    job(self,'moderation',function()return A.player(id,payload)end)
  elseif id=='inbox' then f.mode='inbox';f.scroll=0;job(self,'friends',friends)
  elseif id=='friends' then f.mode='friends';f.scroll=0;job(self,'friends',friends)
  elseif id=='allPlayRequests' or id=='allPlayVisibility' or id=='allPlayChat' or id:match('^playPref:') then
    local doc=f.social or {};local prefs=doc.playPreferences or {};local payload
    if id=='allPlayRequests' then payload={requests_enabled=prefs.requests_enabled==false}
    elseif id=='allPlayChat'then payload={chat_enabled=prefs.chat_enabled==false}
    elseif id=='allPlayVisibility' then payload={visibility_enabled=prefs.visibility_enabled==false}
    else
      local key,peer=id:match('^playPref:(%a+):(%d+)$');local current={}
      for _,v in ipairs(prefs.friends or {}) do if tostring(v.account_id)==peer then current=v;break end end
      local field=key=='visible' and 'visible' or key=='chat'and'chat_enabled'or'requests_enabled';payload={friend_id=tonumber(peer),[field]=current[field]==false}
    end
    job(self,'playPreferences',function()return require('src.cloud.Play').request('PUT','preferences',payload)end)
  elseif id=='findFriend' then local tag=f.friendQuery or '';job(self,'findFriend',function() return A.findPlayer(tag) end)
  elseif id=='addFriend' then local player=f.friendQuery or '';job(self,'friends',function() return A.addFriend(player) end)
  elseif id:match('^friendAccept:') or id:match('^friendRemove:') then
    local peer=id:match(':(.+)$');local accept=id:match('^friendAccept:')~=nil
    job(self,'friends',function() return A.friendAction(peer,accept) end)
  elseif id=='online' or id=='onlineNext' or id=='onlinePrevious' then
    f.mode='online';f.scroll=0
    f.onlinePage=math.max(1,(f.onlinePage or 1)+(id=='onlineNext' and 1 or id=='onlinePrevious' and -1 or 0))
    local page=f.onlinePage;job(self,'online',function() return A.online(page) end)
  elseif id=='account' then f.mode='account';f.scroll=0;job(self,'devices',devices)
  elseif id=='devices' then job(self,'devices',devices)
  elseif id=='sync' then W.close(self);self:_storageSync()
  elseif id=='restoreGames' then W.close(self);self:_storageSync(nil,nil,nil,'restore')
  elseif id=='uploadGames' then W.close(self);self:_storageSync(nil,nil,nil,'games-upload')
  elseif id=='linkStorage' then
    if not f.storageConsent then f.notice='Confirm that these local saves and Bank should belong to this account first.';return end
    local ok,why=require('src.storage.AccountStorage').bind()
    if not ok then f.notice=why;return end
    local after=f.after;W.close(self);require('src.storage.AccountStorage').resume(self,after)
  elseif id:match('^revoke:') then
    local device=f.devices and f.devices[tonumber(id:sub(8))]
    local token=Auth.accessToken and Auth.accessToken()
    if device then job(self,'revoke',function() local doc,why=A.revoke(device.id);if doc and device.current then Auth.expire(token) end;return doc,why end) end
  elseif id=='signout' or id=='switchAccount' then job(self,'signout',function() Auth.signOut();return {ok=true} end)
  elseif id=='developer' then W.close(self);self:_openDeveloper()
  elseif id=='browse' then W.close(self);self.findLoaded=false;self:_refreshFind(true)
  end
end
function W.tick(self)
  local f=self._accountOverlay;if not f then return end
  require('src.ui.FriendChat').tick(f)
  if not f.job and f.mode=='friends'and Auth.signedIn()and not f.focus and not f.composer and love.timer.getTime()>=(f.friendRefresh or 0)then
    f.friendRefresh=love.timer.getTime()+5;job(self,'friends',friends)
  end
  if not f.job then return end
  local r=f.job:poll();if not r then return end
  local purpose=f.purpose;f.job=nil
  if r.kind~='done' or not r.first then f.notice=tostring(r.second or r.error or 'Account unavailable.');return end
  local doc=r.first
  if purpose=='roles' then f.notice='Permissions saved · '..tostring(doc.permissions and doc.permissions.role)..'. The protected operator keeps their role.'
  elseif purpose=='gifts' then f.gifts=doc;f.notice=nil
  elseif purpose=='giftDelivered' then f.mode='gifts';f.notice='Prize delivered to a new save copy. Select that copy to continue playing.'
  elseif purpose=='giftReceived' then f.giftDelivery=doc.kind and doc.receipt or nil;if doc.kind then f.mode='giftDelivery';f.scroll=0 end;f.notice=(doc.alreadyRedeemed and 'Already claimed · ' or (doc.kind and 'Gift in your account inbox · ' or 'Gift in your Bank · '))..tostring(doc.title)..'. The same gift can be restored on your other devices.'
  elseif purpose=='giftCreated' then f.createdGift=doc;f.notice='Gift code created. Copy it now; the plaintext code is not kept in the campaign list.'
  elseif purpose=='giftActive' then job(self,'gifts',A.gifts)
  elseif purpose=='profile' then profile(self,doc);f.notice='Profile saved for all your devices. Custom avatars stay private until their public review is complete.'
  elseif purpose=='findFriend' then f.foundFriend=doc;f.notice='Player found: '..tostring(doc.friend_tag)..'. Send a friend request to connect.'
  elseif purpose=='playPreferences' then f.social=f.social or {};f.social.playPreferences=doc.preferences;require('src.cloud.Play').refresh(true);f.notice='Friend privacy saved for all your devices.'
  elseif purpose=='presence' then require('src.cloud.AccountBadge').acceptPresence(doc);f.notice='Online visibility saved for all your devices.'
  elseif purpose=='players' then f.players=doc;f.notice=nil
  elseif purpose=='player' then f.player=doc;f.notice=nil
  elseif purpose=='playerFriend' then f.social=doc;require('src.cloud.Presence').accept(doc);f.notice='Friend request sent. The other player must accept it.';f.players=nil;W.action(self,'players')
  elseif purpose=='moderation' then f.player=doc;f.mode='playerManage';f.scroll=0;f.moderationAction=nil;f.moderationReason='';f.notice='Moderation saved. The action is recorded in the audit log.'
  elseif purpose=='friends' then doc.playPreferences=doc.playPreferences or f.social and f.social.playPreferences;f.social=doc;require('src.cloud.Presence').accept(doc);f.notice=nil
  elseif purpose=='online' then f.online=doc;f.notice=nil
  elseif purpose=='policy' then f.policy=doc;f.notice=nil
  elseif purpose=='devices' then
    if not Auth.signedIn() then f.mode='login';f.devices=nil;f.profile=nil;f.avatarImage=nil;f.notice='This device was disconnected. Sign in again.';return end
    if doc.presence then require('src.cloud.AccountBadge').acceptPresence(doc.presence) end
    f.devices=doc.devices;f.nickname=doc.name;f.permissions=doc.permissions;f.notice=doc.profileError
    if doc.profile then profile(self,doc.profile) end
    if doc.social then f.social=doc.social;require('src.cloud.Presence').accept(doc.social) end
    if f.afterView then local view=f.afterView;f.afterView=nil;W.action(self,view);return end
    if f.after=='giftAdmin' then f.after=nil;W.action(self,'newGift');return end
    local storage=require('src.storage.AccountStorage')
    if Auth.accountId and Auth.accountId()~=f.accountAtOpen then storage.profileChanged(self);f.accountAtOpen=Auth.accountId() end
    if storage.enabled and (f.after=='bank' or f.after=='bankDex' or f.after=='history' or f.after=='storage' or type(f.after)=='table' and f.after.kind=='play') and storage.check() then local after=f.after;W.close(self);storage.resume(self,after) end
  elseif purpose=='resend' then f.notice=doc.message or 'A fresh code was requested. Check your email.'
  elseif purpose=='signout' or purpose=='revoke' then
    if not Auth.signedIn() then require('src.storage.AccountStorage').profileChanged(self);f.mode='login';f.devices=nil;f.notice='This device is disconnected. Sign in with another account to use its separate local profile.'
    else job(self,'devices',devices) end
  elseif doc.state=='connected' then connected(self,f)
  elseif doc.state=='password_reset' then f.mode='login';f.challenge=nil;f.notice='Password updated. Sign in with your new password.';f.scroll=0
  elseif doc.state=='mfa_code' then
    clearSecrets(f);f.mode='login';f.challenge=nil;f.scroll=0
    f.notice='Please sign in again with email and password. This launcher does not require an authenticator.'
  elseif doc.challenge then
    f.mode=doc.state;f.challenge=doc.challenge;f.scroll=0
    f.notice='Enter the eight-digit code from your ModCompass email. It expires after 15 minutes.'
  else f.notice='Account response incomplete. Please try again.' end
end
function W.scroll(self,dy)
  local f=self._accountOverlay;if f then f.scroll=math.max(0,math.min(f.maxScroll or 0,f.scroll-dy*45)) end
end
function W.navigate(self,step)
  local f=self._accountOverlay;if not f or #f.rects==0 then return end
  inputMode(f,nil);f.padIndex=((f.padIndex or 1)-1+step)%#f.rects+1;f.padActive=true
  local r=f.rects[f.padIndex];local v=f.viewport
  if not r.pinned then
    if r.y<v.y then f.scroll=math.max(0,f.scroll+r.y-v.y)
    elseif r.y+r.height>v.y+v.height then f.scroll=math.min(f.maxScroll or 0,f.scroll+r.y+r.height-v.y-v.height) end
  end
end
function W.draw(self)
  local f=self._accountOverlay;if not f then return end
  local g=love.graphics;local ww,hh=g.getDimensions();local s=math.max(.65,math.min(ww/1050,hh/720,1.25))
  local width=math.min(800*s,ww-28*s);local height=math.min(670*s,hh-28*s);local x,y=(ww-width)/2,(hh-height)/2
  local U,p=self._ui,self.palette();f.rects={}
  g.push('all');g.setCanvas();g.origin();g.setShader();g.setScissor();g.setBlendMode('alpha')
  g.setColor(.015,.025,.05,.96);g.rectangle('fill',0,0,ww,hh)
  g.setColor(.06,.09,.14,1);g.rectangle('fill',x,y,width,height,14*s,14*s)
  local function text(value,tx,ty,w,big)
    g.setFont(big and self.stateFont or self.hintFont);U.col(big and p.ink or p.detail);g.printf(L(value),tx,ty,w,'left')
  end
  local function button(label,bx,by,bw,id)
    local r=self:_chipButton(bx,by,label,{w=bw,h=38*s,kind='accent'});r.id=id;f.rects[#f.rects+1]=r;return r
  end
  text(f.mode=='giftAdmin' and 'RETRORECOMPED · PRIZE STUDIO' or 'RETRORECOMPED · MY PROFILE',x+24*s,y+20*s,width-180*s,true)
  button('CLOSE',x+width-140*s,y+18*s,116*s,'close').pinned=true
  local social=require('src.cloud.Presence').read() or f.social or {}
  local tabs=Auth.signedIn() and not f.document
  if tabs then
    for i,tab in ipairs({{'account','PROFILE'},{'friends','FRIENDS'..(#(social.incoming or {})>0 and ' · '..#social.incoming..' NEW' or '')},{'accountSettings','CLOUD & DEVICES'}}) do
      local tw=(width-48*s)/3;button(tab[2],x+24*s+(i-1)*tw,y+68*s,tw-6*s,tab[1]).pinned=true
    end
  end
  local offset=tabs and 124 or 76
  local v={x=x+18*s,y=y+offset*s,width=width-36*s,height=height-(offset+18)*s};f.viewport=v
  local top=v.y-f.scroll
  local function paragraph(value,big)
    value=L(value)
    local font=big and self.stateFont or self.hintFont;local _,lines=font:getWrap(value,width-48*s)
    text(value,x+24*s,top,width-48*s,big);top=top+math.max(1,#lines)*font:getHeight()+16*s
  end
  local function row(label,id)
    label=L(label)
    local _,lines=self.hintFont:getWrap(label,width-72*s)
    local h=math.max(38*s,#lines*self.hintFont:getHeight()+20*s)
    local r=self:_chipButton(x+24*s,top,'',{w=width-48*s,h=h,kind='accent'});r.id=id;f.rects[#f.rects+1]=r
    text(label,x+36*s,top+10*s,width-72*s);top=top+h+12*s
  end
  local function check(label,key) row((f[key] and '[x] ' or '[ ] ')..label,'toggle:'..key) end
  local function field(label,key,secret)
    paragraph(label)
    local value=key:match('^repo(%d+)$') and f.repositories[tonumber(key:sub(5))] or f[key] or ''
    if secret then value=string.rep('*',math.min(#value,50)) end
    row((value~='' and value or '...')..(f.focus==key and ' |' or ''),'field:'..key)
  end
  g.setScissor(v.x,v.y,v.width,v.height)
  if f.mode=='storage_choice' then
    paragraph('YOUR GAME. YOUR CHOICE.',true)
    paragraph('Play without an account. Saves stay on this device and survive app updates. Cloud saves are optional and let you continue on another device after signing in.')
    row('PLAY WITHOUT AN ACCOUNT · SAVE LOCALLY','local')
    row('I WANT CLOUD SAVES · SIGN IN / REGISTER','cloud')
    paragraph('Bank, trading and new online mod installation require a confirmed account. Local play, manual mod imports and updates to installed mods do not. Browsing and installing new online mods require sign-in.')
  elseif f.document then
    local d=f.policy[f.document];if d then paragraph(d.title,true);paragraph(d.text);paragraph('Version '..f.policy.version);row('OPERATOR CONTACT >','operator') end
    row('BACK','back')
  elseif f.mode=='roles' then
    paragraph('PROFILE PERMISSIONS · SUPERUSER',true)
    paragraph('These permissions apply to RetroRecomped. The original operator is protected from demotion. ModCompass staff permissions keep their separate management.')
    field('Player’s complete friend tag','roleTarget');row('ROLE · '..tostring(f.roleChoice):upper()..' · CHANGE','roleChoice')
    field('Reason · at least 15 characters','roleReason');field('Confirm your account password','rolePassword',true)
    row('SAVE PERMISSIONS','saveRole');row('MY ACCOUNT','account')
  elseif f.mode=='giftDelivery' then
    paragraph('DELIVER ITEM / EVENT PRIZE',true);paragraph(f.giftDelivery.title);paragraph('Choose a save from the prize edition. A new save copy is created; the original is preserved.')
    f.giftSlots=require('src.import.BankWorkspace').slots(self)
    for i,slot in ipairs(f.giftSlots) do if slot.version==f.giftDelivery.edition then row(slot.label,'giftDeliver:'..i) end end
    if #f.giftSlots==0 then paragraph('Create or import a save in this edition first.') end
    row('MY GIFTS','gifts')
  elseif f.mode=='gifts' or f.mode=='giftAdmin' then
    paragraph(f.mode=='giftAdmin' and 'CREATE A GIFT CODE · STAFF' or 'GIFT CODES',true)
    paragraph('Pokémon, items and edition-specific event unlocks. Gen 1 has no eggs or shiny setting. A code is claimed once per account across all your devices. Pokémon stay in your Bank; items and event unlocks stay in your account inbox. Local saves stay intact.')
    if f.mode=='giftAdmin' then
      if f.createdGift then
        paragraph('NEW CODE · '..f.createdGift.code,true);paragraph('Keep or share this code now. It is shown only in this creation result.')
        row('COPY GIFT CODE','copyGiftCode');row('BACK TO MY GIFTS','gifts')
      else
        field('Gift title','giftTitle')
        local editions={};for _,v in ipairs(require('src.core.GameVersion').ORDER) do if (f.giftSelected or {})[v] then editions[#editions+1]=v end end
        local tabAt=0
        require('src.import.GiftDesigner').draw(f,editions,{text=paragraph,row=row,field=field,tab=function(label,id,active)
          local bw=(width-60*s)/7;button((active and '• ' or '')..label,x+24*s+tabAt*(bw+2*s),top,bw,id)
          tabAt=tabAt+1;if tabAt==7 then top=top+54*s end
        end,choices=function(choices)
          local bw=(width-58*s)/#choices
          for i,choice in ipairs(choices) do button((choice[3] and '• ' or '')..choice[1],x+24*s+(i-1)*(bw+2*s),top,bw,choice[2]) end
          top=top+54*s
        end})
        field('Maximum accounts · empty means unlimited','giftLimit')
        paragraph('SUPPORTED EDITIONS',true)
        for _,version in ipairs(require('src.core.GameVersion').ORDER) do if version~='prism' and version~='polishedcrystal' then
          row(((f.giftSelected or {})[version] and '[x] ' or '[ ] ')..require('src.core.GameVersion').info(version).displayName,'giftFor:'..version)
        end end
        row('CREATE GIFT CODE','createGift');row('CANCEL','gifts')
      end
    else
      field('Gift code','giftCode');row('EDITION · '..tostring(f.giftEdition or 'crystal'):upper()..' · CHANGE','giftEdition')
      row('REDEEM TO MY BANK','redeemGift');row('REFRESH MY GIFTS','gifts');row('MY ACCOUNT','account')
      for i,receipt in ipairs((f.gifts or {}).receipts or {}) do
        paragraph(receipt.title..' · '..require('src.import.GiftDesigner').describe(receipt.reward or receipt))
        row((receipt.kind=='item' or receipt.kind=='event') and 'DELIVER TO A SAVE COPY' or 'RESTORE THIS GIFT TO MY BANK','restoreGift:'..i)
      end
      if f.gifts and f.gifts.manage then
        row('STAFF · CREATE A GIFT CODE','newGift')
        for i,campaign in ipairs(f.gifts.campaigns or {}) do
          paragraph(campaign.title..' · '..campaign.redeemed..' claimed · '..table.concat(campaign.editions,', '))
          row(campaign.active and 'DISABLE THIS CODE' or 'ENABLE THIS CODE','giftActive:'..i)
        end
      end
    end
  elseif f.mode=='friendChat'then
    for _,r in ipairs(require('src.ui.FriendChat').rows(f))do
      if r.id=='noop'then paragraph(r.label,true);if r.note then paragraph(r.note)end
      else row(r.label,r.id);if r.note then paragraph(r.note)end end
    end
  elseif f.mode=='friends' then
    paragraph('FRIENDS & REQUESTS',true)
    local prefs=(f.social or {}).playPreferences or {}
    row('FRIEND CHAT · '..(prefs.chat_enabled==false and'OFF'or'ON'),'allPlayChat')
    row('INCOMING GAME INVITATIONS · '..(prefs.requests_enabled==false and 'OFF' or 'ON'),'allPlayRequests')
    row('MUTUAL MAP VISIBILITY · '..(prefs.visibility_enabled==false and 'OFF' or 'ON'),'allPlayVisibility')
    paragraph('Up to five accepted friends can appear as transient figures. They never change your adventure. Meetings need mutual confirmation.')
    paragraph('One friend list for your account, shared by all your devices. Search the complete friend tag, such as Trainer#4821. A Recompiler ID also works for requests. Only accepted friends see your online status.')
    field('Friend tag or Recompiler ID','friendQuery');row('SEARCH FRIEND TAG','findFriend')
    if f.foundFriend then paragraph('FOUND · '..f.foundFriend.friend_tag) end
    row('SEND FRIEND REQUEST','addFriend')
    row('REFRESH FRIENDS','friends');row('MY ACCOUNT','account')
    local social=require('src.cloud.Presence').read() or f.social or {}
    local fresh=os.time()-(social._receivedAt or 0)<=120
    paragraph(L('FRIENDS')..' · '..#(social.friends or {}),true)
    for _,peer in ipairs(social.friends or {}) do
      paragraph(Role.label(peer.friend_tag or peer.nickname,peer)..(not fresh and ' · STATUS UNAVAILABLE' or peer.online and (peer.status=='away' and ' · AWAY' or ' · ONLINE') or ' · OFFLINE'))
      local pref={};for _,v in ipairs(prefs.friends or {}) do if tostring(v.account_id)==tostring(peer.account_id) then pref=v;break end end
      row('INVITATIONS FROM THIS FRIEND · '..(pref.requests_enabled==false and 'OFF' or 'ON'),'playPref:requests:'..peer.account_id)
      row('MAP VISIBILITY WITH THIS FRIEND · '..(pref.visible==false and 'OFF' or 'ON'),'playPref:visible:'..peer.account_id)
      for _,device in ipairs(peer.playing or {})do local edition,zone=require('src.ui.FriendActivity').label(package.loaded['src.core.Game'],device);paragraph(edition..' · '..zone)end
      row('CHAT WITH THIS FRIEND · '..(pref.chat_enabled==false and'OFF'or'ON'),'playPref:chat:'..peer.account_id)
      row('CHAT','chat:'..peer.account_id)
      row('REMOVE FRIEND','friendRemove:'..peer.account_id)
    end
    if #(social.friends or {})==0 then paragraph('Your accepted friends appear here. Requests need the other player’s confirmation.') end
    paragraph('FRIEND REQUESTS · '..#(social.incoming or {}),true)
    for _,peer in ipairs(social.incoming or {}) do paragraph(Role.label(peer.nickname,peer));row('ACCEPT REQUEST','friendAccept:'..peer.account_id);row('DECLINE REQUEST','friendRemove:'..peer.account_id) end
    for _,peer in ipairs(social.outgoing or {}) do paragraph('WAITING · '..Role.label(peer.nickname,peer));row('CANCEL REQUEST','friendRemove:'..peer.account_id) end
    if social.permissions and social.permissions.view_online then row('STAFF · ONLINE PLAYERS & STATISTICS','online') end
  elseif f.mode=='transferGuide' then
    paragraph('CONTINUE ON ANOTHER DEVICE',true)
    paragraph('1 · ON THIS DEVICE',true)
    paragraph('Upload your own imported games once to your private account cache. This is optional and separate from saves. Other accounts cannot download them.')
    row('UPLOAD MY IMPORTED GAMES NOW','uploadGames')
    paragraph('In the game menu, choose Suspend & upload to cloud. Wait until the transfer finishes. Normal saves and exact battle suspends remain separate.')
    paragraph('2 · ON YOUR OTHER DEVICE',true)
    paragraph('Use the same app build, sign in to the same account and restore your cloud games and saves. Choose Continue to resume the saved battle.')
    row('RESTORE MY CLOUD GAMES & SAVES','restoreGames')
    paragraph('CURRENT SUPPORT',true)
    paragraph('Exact resume supports native Gen 1–3 sessions. Loaded mods and live online battles are excluded. Newer local progress is preserved; incompatible suspends fall back to your normal save with a notice.')
    paragraph('Simulated device switching has been tested on separate desktop profiles. Physical Android and iPhone switching still needs device testing.')
    row('BACK TO MY PROFILE','account')
  elseif f.mode=='roleGuide' then
    paragraph('ROLES & PERMISSIONS',true)
    paragraph('PLAYER · Local play needs no account. Verified accounts can use friends, cloud storage and online features.')
    paragraph('ADMIN · Organizes cups and prizes, manages regular players, bans and restores accounts, and quarantines or restores cloud content. Cannot grant roles or moderate staff.')
    paragraph('SUPERUSER · Admin permissions plus granting or revoking native Admin and Superuser roles, and moderating other unprotected staff accounts.')
    paragraph('PROTECTED OPERATOR · Starscream89 cannot be banned, removed, demoted or have cloud content quarantined. Protection belongs to the account across devices.')
    paragraph('The operator binding follows a fixed account ID even after a nickname change. Releasing it requires the private recovery key in the server console; ordinary role controls cannot remove it.')
    paragraph('Staff can see invisible online status. Reasons and current-password confirmation are required for moderation. Actions are audited; cloud removal is recoverable.')
    row('MY ACCOUNT','account')
  elseif f.mode=='players' then
    paragraph('PLAYERS',true)
    paragraph('Browse registered players. Requests become friendships only after the other player accepts. Private contact details stay private.')
    field('Search nickname','playersQuery');row('SEARCH PLAYERS','playersSearch')
    row(f.playersOnline and 'SHOW ALL PLAYERS' or 'SHOW ONLINE ONLY','playersOnline')
    local doc=f.players or {};paragraph(tostring(doc.online_count or '...')..' online · '..tostring(doc.registered_count or '...')..' registered')
    for i,peer in ipairs(doc.players or {})do
      paragraph(Role.label(peer.friend_tag,peer)..(peer.suspended and ' · BANNED' or peer.online and (peer.status=='away' and ' · AWAY' or ' · ONLINE') or ' · OFFLINE'),true)
      if peer.invisible then paragraph('INVISIBLE · STAFF VIEW')end
      if peer.protected then paragraph('PROTECTED OPERATOR')end
      if peer.relationship=='none' then row('SEND FRIEND REQUEST','playerFriend:'..i)
      elseif peer.relationship=='incoming' then row('ACCEPT REQUEST','friendAccept:'..peer.account_id)
      elseif peer.relationship=='outgoing' then paragraph('REQUEST PENDING')
      elseif peer.relationship=='friends' then row('CHAT','chat:'..peer.account_id)end
      if doc.staff then row('MANAGE PLAYER','playerManage:'..i)end
    end
    if (doc.page or 1)>1 then row('PREVIOUS PAGE','playersPrevious')end
    if (doc.page or 1)*(doc.per_page or 30)<(doc.total or 0)then row('NEXT PAGE','playersNext')end
    row('INBOX','inbox');row('MY ACCOUNT','account')
  elseif f.mode=='playerManage' then
    local peer=f.player or {};paragraph(tostring(peer.friend_tag or 'Loading player…'),true)
    paragraph(peer.suspended and 'BANNED' or 'ACCOUNT ACTIVE')
    paragraph('Cloud objects: '..tostring(peer.cloud_objects or 0)..' · Removed from access: '..tostring(peer.held_objects or 0))
    if peer.manageable then
      row(peer.suspended and 'UNBAN PLAYER' or 'BAN PLAYER','moderate:'..(peer.suspended and 'unban' or 'ban'))
      row(peer.profile_hidden and 'RESTORE PUBLIC PROFILE' or 'HIDE PUBLIC PROFILE','moderate:'..(peer.profile_hidden and 'restore_profile' or 'hide_profile'))
      row(peer.avatar_hidden and 'RESTORE PUBLIC AVATAR' or 'REMOVE PUBLIC AVATAR','moderate:'..(peer.avatar_hidden and 'restore_avatar' or 'hide_avatar'))
      row('REMOVE CLOUD CONTENT FROM ACCESS','moderate:quarantine_cloud')
      if (peer.held_objects or 0)>0 then row('RESTORE REMOVED CLOUD CONTENT','moderate:restore_cloud')end
      if f.permissions and f.permissions.manage_roles then row('CHANGE PLAYER RIGHTS','playerRoles')end
    else paragraph(peer.protected and 'PROTECTED OPERATOR · This account cannot be banned, demoted or have its content removed.' or 'This account is outside your moderation permissions.')end
    row('PLAYERS','players')
  elseif f.mode=='moderate' then
    paragraph('CONFIRM MODERATION',true);paragraph(tostring(f.player and f.player.friend_tag));paragraph(tostring(f.moderationAction))
    paragraph('Banning revokes all device sessions. Removed cloud content is quarantined and can be restored; local device files are not deleted. A reason and your current password are required.')
    field('Reason (at least 15 characters)','moderationReason');field('Current account password','moderationPassword',true)
    row('CONFIRM ACTION','moderationConfirm');row('CANCEL','moderationCancel')
  elseif f.mode=='inbox' then
    local doc=require('src.cloud.Presence').read() or f.social or {}
    paragraph('INBOX · FRIEND REQUESTS',true)
    for _,peer in ipairs(doc.incoming or {})do paragraph(Role.label(peer.friend_tag or peer.nickname,peer),true);row('ACCEPT REQUEST','friendAccept:'..peer.account_id);row('DECLINE REQUEST','friendRemove:'..peer.account_id)end
    if #(doc.incoming or {})==0 then paragraph('No pending friend requests.')end
    for _,peer in ipairs(doc.outgoing or {})do paragraph('WAITING · '..tostring(peer.friend_tag or peer.nickname));row('CANCEL REQUEST','friendRemove:'..peer.account_id)end
    row('FIND PLAYERS','players');row('FRIENDS','friends')
  elseif f.mode=='online' then
    paragraph('ONLINE PLAYERS · STAFF',true)
    local online=f.online or {}
    paragraph(tostring(online.online_count or 0)..' online · '..tostring(online.registered_count or 0)..' registered · '..tostring(online.verified_count or 0)..' email confirmed')
    paragraph('Players are counted once across all their devices. Status expires two minutes after the last response.')
    row('REFRESH ONLINE LIST','online')
    for _,peer in ipairs(online.online or {}) do paragraph(Role.label(peer.nickname,peer)..' · '..peer.account_id) end
    if (online.page or 1)>1 then row('PREVIOUS PAGE','onlinePrevious') end
    if (online.page or 1)*(online.per_page or 50)<(online.online_count or 0) then row('NEXT PAGE','onlineNext') end
    row('FRIENDS','friends');row('MY ACCOUNT','account')
  elseif f.mode=='account' then
    local Avatar=require('src.ui.ProfileAvatar');local yy=top
    Avatar.draw(f.avatarPreset,f.avatarColor,x+24*s,yy,88*s,f.avatarImage)
    text(Role.label(f.nickname or Auth.nickname(),{display_role=f.displayRole,permissions=f.permissions}),x+128*s,yy+8*s,width-170*s,true)
    text(tostring(f.friendTag or 'Loading your friend tag…'),x+128*s,yy+48*s,width-170*s)
    top=yy+106*s
    local presence=require('src.cloud.AccountBadge').presence
    if presence then row(presence.visible and 'VISIBLE ONLINE · CLICK TO GO INVISIBLE' or 'INVISIBLE · CLICK TO SHOW ONLINE','presenceToggle')end
    paragraph('Automatically away after 5 minutes without input. Any input makes you online again. Invisible players appear offline to other players; staff can still see their status.')
    row('PLAYERS','players');row('INBOX','inbox');row('ROLES & PERMISSIONS','roleGuide');row('EDIT NICKNAME & AVATAR','profileEdit');row('COPY MY FRIEND TAG','copyFriendTag')
    local fresh=os.time()-(social._receivedAt or 0)<=120;local online=0
    for _,peer in ipairs(social.friends or {}) do if fresh and peer.online then online=online+1 end end
    paragraph(L('FRIENDS')..' · '..online..' '..L('ONLINE')..' / '..#(social.friends or {})..' '..L('TOTAL'),true)
    if #(social.incoming or {})>0 then row(#social.incoming..' NEW FRIEND REQUESTS','friends') end
    for i,peer in ipairs(social.friends or {}) do if i<=5 then
      Avatar.draw(peer.avatar_preset,peer.avatar_color,x+24*s,top,42*s)
      text(Role.label(peer.friend_tag or peer.nickname,peer),x+80*s,top,width-120*s)
      text(not fresh and 'STATUS UNAVAILABLE' or peer.online and (peer.status=='away' and 'AWAY' or 'ONLINE') or '○ OFFLINE',x+80*s,top+22*s,width-120*s);top=top+58*s
    end end
    if #(social.friends or {})==0 then paragraph('Add a friend with their Trainer#1234 tag. Your friends and requests appear here on every device.') end
    row('FIND FRIENDS & MANAGE REQUESTS','friends')
    if f.permissions and f.permissions.view_online then row('STAFF · WHO IS ONLINE & PLAYER COUNTS','online') end
    row('MY GIFTS','gifts')
  elseif f.mode=='profileEdit' then
    paragraph(tostring(f.nickname or Auth.nickname and Auth.nickname() or Auth.account()),true)
    paragraph('Connected as '..tostring(Auth.account()))
    if f.friendTag then paragraph('MY FRIEND TAG · '..f.friendTag,true) end
    if f.avatarImage then
      local iw,ih=f.avatarImage:getDimensions();local size=100*s
      g.setScissor(x+width/2-size/2,math.max(v.y,top),size,math.max(0,math.min(top+size,v.y+v.height)-math.max(v.y,top)))
      local fit=math.max(size/iw,size/ih);g.setColor(1,1,1,1)
      g.draw(f.avatarImage,x+width/2-iw*fit/2,top+(size-ih*fit)/2,0,fit,fit)
      g.setScissor(v.x,v.y,v.width,v.height);top=top+size+18*s
    else
      require('src.ui.ProfileAvatar').draw(f.avatarPreset,f.avatarColor,x+24*s,top,100*s);top=top+118*s
    end
    if f.profile then
      field('Nickname · shared with ModCompass','profileName')
      for _,preset in ipairs(require('src.ui.ProfileAvatar').presets) do row((f.avatarPreset==preset and '● ' or '')..preset:upper(),'avatarPreset:'..preset) end
      row('AVATAR COLOR · '..tostring(f.avatarColor):upper()..' · CHANGE','avatarColor')
      row('CHOOSE MY PROFILE IMAGE','chooseAvatar')
      if f.avatarBytes then check('I have the rights to use this image for my account and allow its storage in ModCompass.','avatarRights') end
      row('SAVE MY GLOBAL PROFILE','saveProfile')
      if f.profile.avatar then row('REMOVE MY CUSTOM PROFILE IMAGE','resetAvatar') end
      if f.profile.avatar_pending then paragraph('Your image is already available on your own devices. Public display follows the ModCompass image review.') end
    end
    row('BACK TO MY PROFILE','account')
  elseif f.mode=='accountSettings' then
    paragraph(L('ACCOUNT PROFILE')..' · '..tostring(Auth.accountId and Auth.accountId() or L('Updating identity')))
    paragraph('Saves, Bank and mod choices are kept separately for each account.')
    paragraph('The same account connects your mods, developer projects, custom cartridge artwork and optional cloud storage.')
    row('CONTINUE ON ANOTHER DEVICE · HOW IT WORKS','transferGuide')
    row('SYNC MY SAVES & CUSTOM CARTRIDGES','sync')
    local storage=require('src.storage.AccountStorage');local permitted,why=storage.check()
    if storage.enabled and not permitted then
      paragraph(why)
      local owner,recovery=storage.owner()
      if not owner and not recovery then
        check('Create or link this account’s local save and Bank profile. Existing data stay intact and other accounts stay separate. This does not enable cloud uploads.','storageConsent')
        row('LINK SAVES & BANK TO MY ACCOUNT','linkStorage')
      end
    end
    row('FRIENDS & FRIEND REQUESTS','friends');row('GIFT CODES & MY GIFTS','gifts')
    if f.permissions and f.permissions.view_online then row('STAFF · ONLINE PLAYERS & STATISTICS','online') end
    if f.permissions and f.permissions.manage_roles then row('SUPERUSER · PROFILE PERMISSIONS','roles') end
    row('BROWSE MODS','browse');row('MOD DEVELOPER · MY REPOSITORIES','developer');row('REFRESH CONNECTED DEVICES','devices')
    paragraph('You stay signed in on this device until you sign out, change your password or disconnect it from your account. Offline periods keep your login.')
    for i,d in ipairs(f.devices or {}) do paragraph(tostring(d.label)..(d.current and ' · THIS DEVICE' or ''));paragraph(d.expires_at and ('Expires '..tostring(d.expires_at)) or 'Signed in until disconnected');row('DISCONNECT DEVICE','revoke:'..i) end
    row('SIGN OUT ON THIS DEVICE','signout')
    row('USE ANOTHER ACCOUNT / LOCAL PROFILE','switchAccount')
  else
    paragraph('One account for RetroRecomped and ModCompass. Signing in links this device. Your password is never saved here.')
    if not (Auth.accountId and Auth.accountId()) then
      row('CONTINUE WITHOUT AN ACCOUNT · LOCAL SAVES','local')
      paragraph('No account is needed to play or keep local saves. Sign in below to access your cloud saves, Bank and mod downloads.')
    elseif not Auth.signedIn() then
      paragraph('Online access needs a fresh login. Your existing local account profile and saves remain available offline.')
      row('SIGN OUT OF THIS LOCAL ACCOUNT PROFILE','signout')
    end
    if f.after=='bank' or f.after=='bankDex' then paragraph('The Pokémon Bank, Item Bank and global Pokédex require a registered account with confirmed email. After confirmation you return directly to the Bank.') end
    if f.mode=='register' then
      paragraph('CREATE YOUR ACCOUNT',true);field('Nickname','name');field('Email','email');field('Password','password',true);field('Confirm password','confirmation',true)
      check('I develop mods','developer')
      if f.developer then
        paragraph('Add your public GitHub repositories. Each project gets its own control proof and catalogue review. You can add more later.')
        for i=1,#f.repositories do field('Repository '..i,'repo'..i) end
        row('+ ADD ANOTHER REPOSITORY','addRepo');row('READ DEVELOPER CONFIRMATION','read:developer');check('I confirm my rights to submit these projects','rights')
      end
      row('READ TERMS OF USE','read:terms');check('I accept the terms of use','terms')
      row('READ PRIVACY NOTICE','read:privacy');check('I have read the privacy notice','privacy')
      check('Enable automatic save & cartridge sync on this device (optional)','cloudSync')
      paragraph('Cloud sync includes your cartridge designs and their images. Mod profile downloads are separate settings. ROMs and imported game caches are not uploaded.')
      row('CREATE ACCOUNT · SEND EMAIL CODE','submit');row('ALREADY REGISTERED? SIGN IN','login')
    elseif f.mode=='login' then
      paragraph('WELCOME BACK',true);field('Email','email');field('Password','password',true)
      check('Enable automatic save & cartridge sync on this device (optional)','cloudSync')
      check('Download my cloud saves and private imported games on this device','restore')
      paragraph('Private game downloads avoid importing again. Uploading imported game data is a separate opt-in under Cloud settings. Automatic save sync also includes Bank and cartridge designs.')
      row('SIGN IN & LINK THIS DEVICE','submit');row('CREATE AN ACCOUNT','register');row('FORGOT PASSWORD','forgot')
    elseif f.mode=='forgot' then paragraph('RECOVER YOUR ACCOUNT',true);field('Email','email');row('SEND RECOVERY CODE','submit');row('BACK TO SIGN IN','back')
    else
      paragraph('CHECK YOUR EMAIL',true);field('Email code','code')
      if f.mode=='reset_code' then field('New password','password',true);field('Confirm new password','confirmation',true) end
      row(f.mode=='reset_code' and 'UPDATE PASSWORD' or 'VERIFY & CONTINUE','submit')
      row('RESEND EMAIL CODE','resend')
      row('START AGAIN','back')
    end
  end
  paragraph(f.notice or '')
  f.maxScroll=math.max(0,top+f.scroll-v.y-v.height);f.scroll=math.min(f.scroll,f.maxScroll)
  local selected=f.padActive and f.rects[f.padIndex or 1]
  if selected and not selected.pinned then U.col(p.link);g.setLineWidth(2*s);g.rectangle('line',selected.x-3*s,selected.y-3*s,selected.width+6*s,selected.height+6*s,6*s,6*s) end
  g.setScissor()
  if f.maxScroll>0 then
    U.col(p.cardBlue);g.rectangle('fill',x+width-12*s,v.y,3*s,v.height)
    U.col(p.link);local th=math.max(20*s,v.height*v.height/(v.height+f.maxScroll))
    g.rectangle('fill',x+width-12*s,v.y+(v.height-th)*f.scroll/f.maxScroll,3*s,th)
  end
  g.pop()
  require('src.ui.TextComposer').draw(f)
end
local function append(f,value)
  if not f.focus then return end
  value=value:gsub('[%c]','')
  local index=tonumber(f.focus:match('^repo(%d+)$'))
  local limit=(f.focus=='password' or f.focus=='confirmation') and 512 or 255
  if index then f.repositories[index]=(f.repositories[index]..value):sub(1,250)
  else f[f.focus]=((f[f.focus] or '')..value):sub(1,type(limit)=='number' and limit or 512) end
end
local function backspace(value) return (value:gsub('[%z\1-\127\194-\244][\128-\191]*$','')) end
function W.install(RI)
  local U=RI._ui
  function RI:_openAccount(after) return W.open(self,after) end
  local draw=RI.draw;RI.draw=function(self,...) draw(self,...);W.draw(self) end
  local update=RI.update;RI.update=function(self,dt,...)
    W.tick(self);return update(self,dt,...)
  end
  local press=RI.mousepressed;RI.mousepressed=function(self,x,y,b,...)
    local f=self._accountOverlay;if not f then return press(self,x,y,b,...) end
    if b~=1 then return end
    if require('src.ui.TextComposer').press(f,x,y)then return end
    f.padActive=false
    for _,r in ipairs(f.rects) do if (r.pinned or U.inside(f.viewport,x,y)) and U.inside(r,x,y) then W.action(self,r.id);return end end
    inputMode(f,nil)
  end
  local key=RI.keypressed;RI.keypressed=function(self,k,...)
    local f=self._accountOverlay;if not f then return key(self,k,...) end
    if require('src.ui.TextComposer').key(f,k)then return end
    if k=='escape' then if f.document then W.action(self,'back') else W.close(self) end
    elseif k=='tab' then W.navigate(self,love.keyboard.isDown('lshift','rshift') and -1 or 1)
    elseif f.focus then
      if k=='backspace' then local index=tonumber(f.focus:match('^repo(%d+)$'));if index then f.repositories[index]=backspace(f.repositories[index]) else f[f.focus]=backspace(f[f.focus] or '') end
      elseif k=='return' then inputMode(f,nil)
      elseif k=='v' and love.keyboard.isDown('lctrl','rctrl','lgui','rgui') then append(f,love.system.getClipboardText() or '') end
    elseif k=='down' then W.navigate(self,1)
    elseif k=='up' then W.navigate(self,-1)
    elseif k=='return' or k=='space' then local r=f.rects[f.padIndex or 1];if r then W.action(self,r.id) end end
  end
  local input=RI.textinput;RI.textinput=function(self,t,...) if self._accountOverlay then if not require('src.ui.TextComposer').text(self._accountOverlay,t)then append(self._accountOverlay,t)end;return end;return input(self,t,...) end
  local wheel=RI.wheelmoved;RI.wheelmoved=function(self,dx,dy,...) if self._accountOverlay then W.scroll(self,dy);return end;if wheel then return wheel(self,dx,dy,...) end end
  local touch=RI.touchpressed;RI.touchpressed=function(self,id,x,y,...)
    local f=self._accountOverlay;if not f then return touch(self,id,x,y,...) end
    if not f.touch then f.touch={id=id,x=x,y=y,startY=y} end
  end
  local moved=RI.touchmoved;RI.touchmoved=function(self,id,x,y,...)
    local f=self._accountOverlay;if not f then if moved then return moved(self,id,x,y,...) end;return end
    local t=f.touch;if t and t.id==id then if math.abs(y-t.startY)>8 then t.scrolling=true end;if t.scrolling then W.scroll(self,(y-t.y)/45) end;t.y=y end
  end
  local release=RI.touchreleased;RI.touchreleased=function(self,id,x,y,...)
    local f=self._accountOverlay;if not f then if release then return release(self,id,x,y,...) end;return end
    local t=f.touch;if t and t.id==id then f.touch=nil;if not t.scrolling then self:mousepressed(x,y,1) end end
  end
  local pad=RI.gamepadpressed;RI.gamepadpressed=function(self,j,b,...)
    if not self._accountOverlay then return pad(self,j,b,...) end
    if require('src.ui.TextComposer').pad(self._accountOverlay,b)then return end
    if b=='b' then if self._accountOverlay.document then W.action(self,'back') else W.close(self) end
    elseif b=='dpdown' then W.navigate(self,1) elseif b=='dpup' then W.navigate(self,-1)
    elseif b=='a' then local f=self._accountOverlay;local r=f.rects[f.padIndex or 1];if r then W.action(self,r.id) end end
  end
  for _,name in ipairs({'mousereleased','mousemoved'}) do local original=RI[name];RI[name]=function(self,...) if self._accountOverlay then return end;if original then return original(self,...) end end end
  local dropped=RI.filedropped;RI.filedropped=function(self,file,...)
    local f=self._accountOverlay
    if not f or (f.mode~='account' and f.mode~='profileEdit') or not Auth.signedIn() then if dropped then return dropped(self,file,...) end;return end
    local ok,bytes=pcall(function() file:open('r');local b=file:read(2*1024*1024+1);file:close();return b end)
    if ok then W.avatarBytes(self,bytes) else f.notice='The profile image could not be read.' end
  end
  local play=RI.play;RI.play=function(self,...) if self._accountOverlay then W.close(self) end;return play(self,...) end
end
return W
