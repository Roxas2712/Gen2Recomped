local C={}
local Auth=require('src.cloud.RetroCloud')
local Task=require('src.cloud.Task')
local Composer=require('src.ui.TextComposer')
local serial=0
local function uuid()
 serial=serial+1
 local b=love.data.encode('string','hex',love.data.hash('sha256',tostring(love.timer.getTime())..':'..serial..':'..tostring(Auth.accountId())..':'..love.math.random()))
 return b:sub(1,8)..'-'..b:sub(9,12)..'-4'..b:sub(14,16)..'-a'..b:sub(18,20)..'-'..b:sub(21,32)
end
function C.clear(O)
 if O.chatJob then O.chatJob:cancel()end
 O.chatJob=nil;O.chat=nil;O.chatDoc=nil;O.chatError=nil;O.chatSending=nil;O.chatSend=nil;O.chatDraft='';O.chatNext=nil;O.chatAccount=nil
 Composer.close(O,false)
end
function C.open(O,friend)
 C.clear(O);O.chat=tostring(friend);O.chatAccount=Auth.accountId();O.scroll=0;O.selected=1
end
function C.tick(O)
 if not O.chat then return end
 if not Auth.signedIn() or Auth.accountId()~=O.chatAccount then C.clear(O);return end
 if O.chatJob then
  local r=O.chatJob:poll();if not r then return end;O.chatJob=nil;O.chatNext=love.timer.getTime()+3
  if r.kind=='done' and r.first and tostring(r.first.friend_id)==O.chat then
   O.chatDoc=r.first;O.chatError=nil
   if O.chatSending then O.chatDraft='';O.chatSend=nil;O.chatSending=nil end
  else O.chatError=tostring(r.second or r.error or 'Chat unavailable.');O.chatSending=nil end
 elseif love.timer.getTime()>=(O.chatNext or 0)then
  local friend=O.chat;O.chatJob=Task.new(function()return require('src.cloud.Play').request('GET','friends/'..friend..'/chat')end)
 end
end
function C.action(O,id)
 local friend=id:match('^chat:(%d+)$');if friend then C.open(O,friend);return true end
 if not O.chat then return false end
 if id=='chatBack'then C.clear(O);O.scroll=0;O.selected=1;return true end
 if id=='chatCompose'then
  Composer.open(O,O.chatDraft,function(value)O.chatDraft=value;O.chatSend=nil end,1000);return true
 end
 if id=='chatSend'then
  if O.chatJob or (O.chatDraft or ''):match('^%s*$')then return true end
  if O.chatDoc and O.chatDoc.enabled==false then O.chatError='Chat is disabled for this friendship.';return true end
  O.chatSend=O.chatSend or {id=uuid(),body=O.chatDraft};local payload=O.chatSend;local target=O.chat
  O.chatSending=true;O.chatJob=Task.new(function()return require('src.cloud.Play').request('POST','friends/'..target..'/chat',payload)end)
  return true
 end
 return id=='noop'
end
function C.rows(O)
 local rows={{id='chatBack',label='‹ Back to friends'},{id='chatCompose',label='WRITE A MESSAGE',note=(O.chatDraft~=''and O.chatDraft or 'System keyboard on phones / Switch · Controller keyboard available')},
  {id='chatSend',label=O.chatSending and 'SENDING…'or O.chatSend and 'RETRY MESSAGE'or'SEND MESSAGE',note=O.chatError or 'Accepted friends only · Synced across your devices · History: 30 days'}}
 if O.chatDoc and O.chatDoc.enabled==false then rows[#rows+1]={id='noop',label='Chat disabled',note='You or your friend disabled chat in privacy settings.'}end
 local list=O.chatDoc and O.chatDoc.messages or {}
 for i=#list,math.max(1,#list-19),-1 do
  local m=list[i];rows[#rows+1]={id='noop',label=(tostring(m.sender)==Auth.accountId()and'YOU'or'FRIEND')..' · '..tostring(m.created_at)..' UTC',note=m.body}
 end
 if #list==0 then rows[#rows+1]={id='noop',label='No messages yet',note='Send your friend the first message.'}end
 return rows
end
return C
