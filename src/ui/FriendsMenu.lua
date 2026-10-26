local F={}
local Auth=require('src.cloud.RetroCloud')
local Task=require('src.cloud.Task')
local API=require('src.cloud.NativeAccount')
local Play=require('src.cloud.Play')
local function job(O,kind,fn)
 if O.socialJob then return end
 O.socialJob=Task.new(fn);O.socialPurpose=kind;O.notice='Connecting with your friends…'
end
function F.tick(O)
 local account=Auth.signedIn() and Auth.accountId() or nil
 if F.account~=account then
  if O.socialJob then O.socialJob:cancel() end
  F.account=account;O.socialJob=nil;O.socialProfile=nil;O.foundFriend=nil;O.friendQuery='';O.friendTarget=nil;O.socialPreferences=nil
 end
 if O.socialJob then
  local r=O.socialJob:poll();if not r then return end;O.socialJob=nil
  if r.kind~='done' or not r.first then O.notice=tostring(r.second or r.error or 'Friend request failed.');return end
  if O.socialPurpose=='profile' then O.socialProfile=r.first;O.socialAvatar=require('src.ui.ProfileAvatar').decode(r.first.avatar);O.notice=nil
  elseif O.socialPurpose=='find' then O.foundFriend=r.first;O.notice='Player found. Send a request to connect.'
  elseif O.socialPurpose=='friend' then require('src.cloud.Presence').accept(r.first);O.notice='Friend list updated.';Play.refresh()
  elseif O.socialPurpose=='preferences' then O.socialPreferences=r.first.preferences;O.notice='Friend privacy settings saved on your account.';Play.refresh(true)
  else O.notice='Invitation updated.';Play.refresh() end
 elseif O.page=='friends' and account and not O.socialProfile then job(O,'profile',API.profile) end
end
function F.action(O,id)
 if id=='friends' then O.page='friends';O.scroll=0;O.selected=1;O.notice=nil;Play.refresh();F.tick(O);return true end
 if O.page~='friends' then return false end
 local settings=Play.read() and Play.read().preferences or O.socialPreferences or {}
 if id=='allRequests' or id=='allVisibility' then
  local key=id=='allRequests' and 'requests_enabled' or 'visibility_enabled'
  job(O,'preferences',function()return Play.request('PUT','preferences',{[key]=settings[key]==false})end);return true
 end
 local pref,friend=id:match('^pref:(%a+):(%d+)$')
 if pref then
  local current={};for _,p in ipairs(settings.friends or {}) do if tostring(p.account_id)==friend then current=p;break end end
  local key=pref=='visible' and 'visible' or 'requests_enabled'
  job(O,'preferences',function()return Play.request('PUT','preferences',{friend_id=tonumber(friend),[key]=current[key]==false})end);return true
 end
 if id=='friendsBack' then O.friendTarget=nil;O.scroll=0;O.selected=1;return true end
 if id=='friendTag' then O.friendFocus=true;if love.keyboard.setTextInput then love.keyboard.setTextInput(true) end;return true end
 if id=='findPlayer' then local tag=O.friendQuery or '';job(O,'find',function()return API.findPlayer(tag)end);return true end
 if id=='requestFriend' and O.foundFriend then local tag=O.foundFriend.friend_tag;job(O,'friend',function()return API.addFriend(tag)end);return true end
 local peer=id:match('^friend:(%d+)$')
 if peer then O.friendTarget=O.friendTarget==peer and nil or peer;O.scroll=0;O.selected=1;O.followSelection=true;return true end
 local kind,device=id:match('^invite:(%a+):([a-f0-9%-]+)$')
 if kind and #device==36 then job(O,'invite',function()return Play.request('POST','invites',{device=device,mode=kind})end);return true end
 local action,uuid=id:match('^(acceptLink):([a-f0-9%-]+)$')
 if not action then action,uuid=id:match('^(declineLink):([a-f0-9%-]+)$') end
 if not action then action,uuid=id:match('^(leaveLink):([a-f0-9%-]+)$') end
 if action and #uuid==36 then
  job(O,'invite',function()return Play.request('POST','invites/'..uuid..(action=='leaveLink' and '/cancel' or '/respond'),{accept=action=='acceptLink'})end);return true
 end
 local op,user=id:match('^(acceptFriend):(%d+)$')
 if not op then op,user=id:match('^(removeFriend):(%d+)$') end
 if op then job(O,'friend',function()return API.friendAction(user,op=='acceptFriend')end);return true end
 return false
end
function F.text(O,value)
 if O.page=='friends' and O.friendFocus then O.friendQuery=((O.friendQuery or '')..value:gsub('[%c]','')):sub(1,80);O.foundFriend=nil;return true end
end
function F.key(O,key)
 if O.page~='friends' or not O.friendFocus then return false end
 if key=='return' or key=='escape' then O.friendFocus=nil;if love.keyboard.setTextInput then love.keyboard.setTextInput(false) end
 elseif key=='backspace' then O.friendQuery=(O.friendQuery or ''):gsub('[%z\1-\127\194-\244][\128-\191]*$','');O.foundFriend=nil
 elseif key=='v' and love.keyboard.isDown('lctrl','rctrl','lgui','rgui') then F.text(O,love.system.getClipboardText() or '') end
 return true
end
function F.rows(O)
 if not Auth.signedIn() then return {{id='noop',label='Sign in to play with friends',note='Use My Profile in the library. Local play stays available.'},{id='library',label='Save & open library'}} end
 local doc=Play.read() or require('src.cloud.Presence').read() or {}
 local rows={};local function add(id,label,note,avatar)rows[#rows+1]={id=id,label=label,note=note,avatar=avatar}end
 local settings=doc.preferences or O.socialPreferences or {}
 if O.friendTarget then add('friendsBack','‹ All friends') else
 add('allRequests','Incoming invitations · '..(settings.requests_enabled==false and 'OFF' or 'ON'),'Trade, battle and meeting requests from accepted friends only.')
 add('allVisibility','Mutual map visibility · '..(settings.visibility_enabled==false and 'OFF' or 'ON'),'Up to 5 friends · Accepted meetings only · No effect on the world.')
 local own=O.socialProfile or doc
 add('noop',own.name or own.nickname or Auth.nickname(),own.friend_tag or 'Loading your friend tag…',{preset=own.avatar_preset,color=own.avatar_color,image=O.socialAvatar})
 end
 for _,i in ipairs(doc.invites or {}) do
  if (not O.friendTarget or tostring(i.peer)==O.friendTarget) and i.incoming and i.state=='pending' then
   add('acceptLink:'..i.id,'ACCEPT · '..i.mode:upper()..' · '..i.nickname,i.edition:upper()..' · Your game connects only after you accept.')
   add('declineLink:'..i.id,'Decline invitation')
  elseif (not O.friendTarget or tostring(i.peer)==O.friendTarget) and i.mode=='meet' and i.state=='accepted' then add('leaveLink:'..i.id,'LEAVE MEETING · '..i.nickname,'You can see each other on matching maps.')
  elseif (not O.friendTarget or tostring(i.peer)==O.friendTarget) and i.state=='pending' then add('leaveLink:'..i.id,'CANCEL · '..i.mode:upper()..' · '..i.nickname,'Waiting for your friend to accept.') end
 end
 for _,p in ipairs(not O.friendTarget and doc.incoming or {}) do add('acceptFriend:'..p.account_id,'ACCEPT FRIEND · '..p.nickname);add('removeFriend:'..p.account_id,'Decline friend request') end
 local peers={};for _,p in ipairs(doc.friends or {}) do peers[#peers+1]=p end
 table.sort(peers,function(a,b)if a.online~=b.online then return a.online==true end;return a.nickname<b.nickname end)
 for _,p in ipairs(peers) do
  if not O.friendTarget or O.friendTarget==tostring(p.account_id) then
  local playing=p.playing or {};local editions={};for _,d in ipairs(playing) do editions[#editions+1]=d.edition:upper() end
  add('friend:'..p.account_id,p.friend_tag or p.nickname,(p.online and 'ONLINE' or 'OFFLINE')..(#editions>0 and ' · '..table.concat(editions,' / ') or ''),{preset=p.avatar_preset,color=p.avatar_color})
  if O.friendTarget==tostring(p.account_id) then
   local pref={};for _,v in ipairs(settings.friends or {}) do if tostring(v.account_id)==tostring(p.account_id) then pref=v;break end end
   for _,d in ipairs(playing) do
    if d.compatible and d.available then
     add('invite:meet:'..d.device,'MEET ON THE MAP · '..d.edition:upper(),'Private meeting · Your adventures remain separate.')
     if d.link_supported~=false then
     add('invite:trade:'..d.device,'TRADE · '..d.edition:upper(),'Native party selection, confirmation and trade animation.')
     add('invite:battle:'..d.device,'FRIEND BATTLE · '..d.edition:upper(),'Unranked · Current party and levels · Adventure save stays intact.')
     else add('noop','Native trade & battle are not ready for this edition','Meeting friends is available. Native links currently support Gen 1–3.') end
    else add('noop',d.edition:upper()..' · '..(d.available and 'Different edition or link rules' or 'Busy in game'),'Both players must be in the matching overworld.') end
   end
   if #playing==0 then add('noop','Waiting for this friend to open a game') end
   add('pref:requests:'..p.account_id,'Invitations from this friend · '..(pref.requests_enabled==false and 'OFF' or 'ON'))
   add('pref:visible:'..p.account_id,'Mutual map visibility with this friend · '..(pref.visible==false and 'OFF' or 'ON'),'Turning this off hides both figures. Your friendship stays intact.')
  end
  end
 end
 if #peers==0 then add('noop','Your friends appear here','Add a friend by their complete Trainer#1234 tag.') end
 if not O.friendTarget then
 add('friendTag','FRIEND TAG · '..(O.friendQuery or '')..(O.friendFocus and ' |' or ''),'Select to type a complete tag.')
 add('findPlayer','Find player')
 if O.foundFriend then add('requestFriend','SEND REQUEST · '..O.foundFriend.friend_tag) end
 end
 return rows
end
function F.clear(O)
 if O.socialJob then O.socialJob:cancel() end
 O.socialJob=nil;O.friendFocus=nil
 if love.keyboard and love.keyboard.setTextInput then love.keyboard.setTextInput(false) end
end
return F
