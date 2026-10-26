-- Account-scoped presentation only. Never cache credentials or staff lists.
local B={}
local Auth=require('src.cloud.RetroCloud')
local Task=require('src.cloud.Task')
local function clock()return love.timer and love.timer.getTime() or os.clock()end
local function reset(id)
  for _,key in ipairs({'profileJob','countJob','presenceJob'})do if B[key]then B[key]:cancel();B[key]=nil end end
  B.account=id;B.profile=nil;B.image=nil;B.counts=nil;B.countAt=nil;B.profileAt=nil
  B.nextProfile=0;B.nextCount=0;B.nextPresence=0;B.presence=nil;B.lastState=nil;B.lastInput=clock()
end
function B.accept(doc,image)
  local id=Auth.accountId and Auth.accountId()
  if not Auth.signedIn() or not id or type(doc)~='table' or doc.account_id~=id then return end
  if id~=B.account then reset(id)end
  B.profile={name=doc.name,friend_tag=doc.friend_tag,avatar_preset=doc.avatar_preset,avatar_color=doc.avatar_color}
  B.image=image or require('src.ui.ProfileAvatar').decode(doc.avatar)
  B.profileAt=os.time()
end
function B.activity()
  B.lastInput=clock()
end
function B.state()
  return clock()-(B.lastInput or 0)>=300 and 'away' or 'online'
end
function B.acceptPresence(doc)
  if type(doc)=='table' and doc.account_id==B.account then B.presence=doc end
end
function B.tick()
  local id=Auth.accountId and Auth.accountId()
  if id~=B.account or not Auth.signedIn() then
    reset(id)
  end
  if not id or not Auth.signedIn() then return end
  local now=os.time();local API=require('src.cloud.NativeAccount')
  local state=B.state()
  if B.presenceJob then
    local result=B.presenceJob:poll()
    if result then B.presenceJob=nil;if result.kind=='done' then B.acceptPresence(result.first)end end
  elseif API.presence and (now>=(B.nextPresence or 0) or state~=B.lastState) then
    B.nextPresence=now+30;B.lastState=state;B.presenceJob=Task.new(function()return API.presence({state=state})end)
  end
  if B.profileJob then
    local result=B.profileJob:poll()
    if result then B.profileJob=nil;if result.kind=='done' then B.accept(result.first)end end
  elseif now>=(B.nextProfile or 0) and API.profile then B.nextProfile=now+120;B.profileJob=Task.new(API.profile) end
  if B.countJob then
    local result=B.countJob:poll()
    if result then
      B.countJob=nil;local doc=result.kind=='done' and result.first
      if type(doc)=='table' and doc.account_id==id then B.counts=doc;B.countAt=now end
    end
  elseif now>=(B.nextCount or 0) and API.playerCounts then B.nextCount=now+30;B.countJob=Task.new(API.playerCounts) end
end
function B.read()
  if not Auth.signedIn() or B.account~=(Auth.accountId and Auth.accountId()) then return end
  return B.profile,B.image,(B.countAt and os.time()-B.countAt<=90) and B.counts or nil
end
return B
