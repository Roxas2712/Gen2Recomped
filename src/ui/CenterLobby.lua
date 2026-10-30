-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Readiness is opt-in, scoped to this Center visit and current account.
local C={mode='off',public=false,next=0}
local function L(value)return require('src.translation.Service').launcherLookup(value)end
local Auth=require('src.cloud.RetroCloud')
local Task=require('src.cloud.Task')
local function play()return require('src.cloud.Play')end
function C.center(game)
 local world=game and game.overworld;local map=world and world.map
 if not map or not map.def or not game.data then return end
 local version=require('src.core.GameVersion')
 if version.generation()>=4 then
  local spawn=require('src.world.Gen4Blackout').spawnFor(game.data,map.id,map.def)
  if spawn and not spawn.home then return tostring(map.id)end
  return
 end
 local source=require('src.core.MapIdentity').sourceId(game.data,map.id)
 local canonical=version.generation()==3 and require('src.core.Gen3MapNames').canonicalId(game.data,map.id)or source
 for _,value in ipairs({tostring(canonical),tostring(source),tostring(map.id),tostring(map.def.name or ''),tostring(map.def.tileset or '')})do
  local name=value:upper():gsub('[^A-Z0-9]','')
  if name:find('POKECENTER',1,true) or name:find('POKEMONCENTER',1,true)then return tostring(source or map.id)end
 end
end
function C.supported()
 local v=require('src.core.GameVersion');return v.generation()<=3 or v.get()=='platinum'
end
function C.stop()
 if C.near then C.near:close();C.near=nil end
 if C.job then C.job:cancel();C.job=nil end
 C.mode='off';C.players=nil;C.next=0
end
function C.open(game)
 if not C.center(game)then return nil,'Visit a Pokémon Center to open this lobby.'end
 local O=require('src.ui.RetroOverlay');O.open(game);O.page='centerLobby';O.selected=1;O.scroll=0
 return true
end
function C.tick(game)
 require('src.link.LocalLink').tick(game)
 local center=C.center(game);local account=Auth.signedIn() and Auth.accountId()or nil
 if C.game~=game or C.account~=account or C.centerId~=center then C.stop();C.game=game;C.account=account;C.centerId=center end
 if not center or not game or game.linkSession or game.retroArena then C.stop();return end
 if C.near then
  C.near:update()
  if C.near.phase=='accepted'then
   local net,host,mode=C.near:take();C.near=nil
   local ok,why=require('src.link.LocalLink').start(game,net,mode,host);if not ok then C.error=why end
  end
 end
 if C.job then
  local result=C.job:poll()
  if result then C.job=nil;if result.kind=='done'and result.first then C.players=result.first.players;C.error=nil else C.error=tostring(result.second or result.error or 'Lobby unavailable.');C.players=nil end end
 elseif account and C.onlineDirty or account and C.mode~='off' and love.timer.getTime()>=C.next then
  if not play().read()then return end
  C.onlineDirty=nil;C.next=love.timer.getTime()+5
  local input={mode=C.mode,public=C.public,center=center}
  C.job=Task.new(function()return play().request('POST','center-lobby',input)end)
 end
end
function C.action(O,id)
 if id=='centerLobby'then C.open(O.game);return true end
 if O.page~='centerLobby'then return false end
 if id=='compatCable'then
  if O.job then O.notice='Wait for the upload, or cancel it first.';return true end
  local game=O.game
  C.stop();local overlay=require('src.ui.RetroOverlay');overlay.close()
  local screen,why=require('src.features.Gen1CableLobby').open(game)
  if not screen then overlay.open(game);overlay.page='centerLobby';overlay.notice=why;C.error=why end
  return true
 end
 if id=='centerOff'then
  C.stop();C.onlineDirty=Auth.signedIn();return true
 end
 if id=='centerFriends'or id=='centerPublic'then
  if not Auth.signedIn()then O.notice='Sign in to use the online lobby. Local WLAN play works without an account.';return true end
  if not O.game.save.party or #O.game.save.party==0 then O.notice='Choose a party in a supported edition first.';return true end
  if not C.supported()then O.notice='Native links are not qualified for this edition yet.';return true end
  if C.near then C.near:close();C.near=nil end
  C.mode='both';C.public=id=='centerPublic';C.next=0;return true
 end
 if id=='nearTrade'or id=='nearBattle'then
  if not C.supported()or not O.game.save.party or #O.game.save.party==0 then O.notice='Choose a party in a supported edition first.';return true end
  C.stop();C.onlineDirty=Auth.signedIn()
  C.near,C.error=require('src.link.Nearby').new(O.game,id=='nearTrade'and'trade'or'battle');return true
 end
 if id=='nearAccept'or id=='nearDecline'then if C.near then C.near:respond(id=='nearAccept')end;return true end
 local peer=id:match('^near:(.+)$');if peer and C.near then local ok,why=C.near:request(peer);if not ok then C.error=why end;return true end
 local mode,device=id:match('^centerInvite:(%a+):([a-f0-9%-]+)$')
 if mode and #device==36 then
  if C.job then return true end
  C.job=Task.new(function()return play().request('POST','invites',{device=device,mode=mode,center_lobby=true})end)
  O.notice='Waiting for the other player to accept.';play().refresh();return true
 end
 if id:match('^acceptLink:')or id:match('^declineLink:')or id:match('^leaveLink:')then
  O.page='friends';require('src.ui.FriendsMenu').action(O,id);O.page='centerLobby';return true
 end
 return false
end
function C.rows(O)
 local rows={};local function add(id,label,note,avatar)rows[#rows+1]={id=id,label=L(label),note=note and L(note),avatar=avatar}end
 add('home','‹ Quick menu')
 add('noop','POKÉMON CENTER · LINK LOBBY','Both players choose and confirm. Trades use your party; friend battles keep your adventure unchanged.')
 add('centerFriends','ONLINE · READY FOR FRIENDS',C.mode~='off'and not C.public and L('READY')or'Only accepted friends who are ready.')
 add('centerPublic','ONLINE · FIND OTHER PLAYERS',C.mode~='off'and C.public and L('READY')or'Opt in to public search · Matching edition and link rules.')
 add('centerOff','NOT READY · STOP DISCOVERY','Leave the online and nearby waiting rooms.')
 local doc=play().read()or{}
 for _,i in ipairs(doc.invites or{})do
  if i.incoming and i.state=='pending'and i.mode~='meet'and not i.wager then
   add('acceptLink:'..i.id,L('ACCEPT · ')..L(i.mode=='trade'and'Trade'or'Battle'):upper()..' · '..i.nickname,'The connection starts only after your confirmation.')
   add('declineLink:'..i.id,'Decline invitation')
  elseif i.state=='pending'and not i.incoming then add('leaveLink:'..i.id,L('CANCEL · ')..L(i.mode=='trade'and'Trade'or'Battle'):upper()..' · '..i.nickname,'Waiting for the other player.')end
 end
 for _,p in ipairs(C.players or{})do
  add('noop',require('src.ui.PlayerRole').label(p.friend_tag or p.nickname,p),p.edition:upper()..' · '..L('READY'),{preset=p.avatar_preset,color=p.avatar_color})
  for _,mode in ipairs(p.modes or{})do add('centerInvite:'..mode..':'..p.device,mode=='trade'and'TRADE WITH THIS PLAYER'or'BATTLE WITH THIS PLAYER','Send an invitation; the other player can decline.')end
 end
 if C.mode~='off'and #(C.players or{})==0 then add('noop','Waiting for ready players','Open the lobby on both devices and choose Friends or Public.')end
 add('nearTrade','NEARBY · WLAN TRADE LOBBY','Automatic discovery on the same network · No Internet or account required.')
 if require('src.core.GameVersion').generation()<=3 then add('compatCable','OPTIONAL · COMPATIBILITY CABLE','Private relay · Resume trades · Shared Gen3 battle rules.')end
 add('nearBattle','NEARBY · WLAN BATTLE LOBBY','Same edition and link rules · Accept or decline on the other device.')
 if C.near then
  if C.near.phase=='incoming'then
   add('nearAccept',L('ACCEPT NEARBY · ')..C.near.incoming.name,C.near.mode:upper()..' · Local player identity is not account-verified.')
   add('nearDecline','Decline nearby request')
  elseif C.near.phase=='requesting'then add('noop','Waiting for nearby confirmation','The other player can accept or decline.')
  else
   local peers={};for _,p in pairs(C.near.peers)do peers[#peers+1]=p end;table.sort(peers,function(a,b)return a.name<b.name end)
   for _,p in ipairs(peers)do add('near:'..p.id,p.name..' · '..C.near.edition:upper(),L('Select to request a connection. No party data is shared before consent.'))end
   if #peers==0 then add('noop','Searching the local network…','Enable the same nearby lobby on the other device. Guest Wi-Fi isolation may prevent discovery.')end
  end
 end
 add('noop','Bluetooth','A native Bluetooth transport is not available in this build. Use the nearby WLAN lobby.')
 if C.error or C.near and C.near.error then add('noop',C.error or C.near.error)end
 return rows
end
return C
