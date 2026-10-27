-- Synthetic account-service contract; no production credentials or friends.
-- Exercises the real Friends, CloudNet and Duel modules. By Roxas2712.
package.path='./?.lua;'..package.path
love=require('tests.love_stub')
local clock,identity,checks=0,'1',0
love.timer.getTime=function()return clock end
-- Plain Lua has no crypto: protocol identity comparisons only; production uses SHA256.
love.data={hash=function(_,s)return s end,encode=function(_,_,s)return s end}
local Auth={signedIn=function()return identity~=nil end,accountId=function()return identity end}
local Task={new=function(fn)
 local done=false
 return {poll=function()assert(not done);done=true;local a,b=fn();return{kind='done',first=a,second=b}end,cancel=function()done=true end}
end}
package.loaded['src.cloud.RetroCloud']=Auth;package.loaded['src.cloud.Task']=Task
local Friends=require('src.pinball.Friends');local CloudNet=require('src.link.CloudNet');local Duel=require('src.pinball.Duel')
local Json=require('src.link.Json')
local function copy(v)return Json.decode(Json.encode(v))end
local function check(v,m)assert(v,m);checks=checks+1 end
local devices={'11111111-1111-4111-8111-111111111111','22222222-2222-4222-8222-222222222222'}
local id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
local session={rom_sha1='own-rom-sha1',backend='native-build-bios',content='USA',locale='en'}
local invite,entered,streams,closed,duels,starts
local function reset()
 invite=nil;entered={};streams={['1']={},['2']={}};closed={};duels={};starts={}
 local function doc(who)
  local peer=who=='1'and'2'or'1';local invites={}
  if invite then local i=copy(invite);i.peer=peer;i.incoming=who~='1';i.nickname='QA Friend';invites={i}end
  return {invites=invites,friends={{account_id=peer,playing={{device=devices[tonumber(peer)],edition='pinballrs',available=true,compatible=true}}}}}
 end
 local function request(who,method,path,p)
  check(method=='POST','all friend actions use authenticated POST')
  local peer=who=='1'and'2'or'1'
  if path=='invites'then
   check(who=='1'and p.device==devices[2]and p.mode=='pinball','dedicated Pinball invitation')
   invite={id=id,host='1',mode='pinball',edition='pinballrs',state='pending',rules=copy(p.rules),fingerprint=p.fingerprint}
   return doc(who)
  end
  check(invite and path:sub(1,44)=='invites/'..id,'same invitation throughout')
  if path:match('/respond$')then
   check(who=='2'and invite.state=='pending','only invitee responds once')
   invite.state=p.accept and'accepted'or'declined';return doc(who)
  elseif path:match('/cancel$')then invite.state='cancelled';return doc(who)
  elseif path:match('/enter$')then
   check(invite.state=='accepted'and p.fingerprint==invite.fingerprint and not p.party and not p.save,'enter is bound to native build, without RPG party or save')
   entered[who]=true;return{ready=entered['1']and entered['2']or false}
  elseif path:match('/wire$')then
   if invite.state~='accepted'then return nil,'Invitation cancelled',422 end
   local out=streams[peer]
   for _,row in ipairs(p.messages)do
    if row.sequence>#out then check(row.sequence==#out+1,'ordered outgoing stream');out[#out+1]=copy(row)end
   end
   if p.close then closed[who]=true end
   local incoming={};for n=p.after+1,math.min(#streams[who],p.after+8)do incoming[#incoming+1]=copy(streams[who][n])end
   return{battle=id,sent=#out,messages=incoming,peer_online=true,peer_closed=closed[peer]or false}
  end
  error(path)
 end
 local function client(who)
  identity=who
  return Friends.new(session,{auth=Auth,task=Task,net=CloudNet,field=1,
   play={read=function()return doc(who)end,refresh=function()end,request=function(...)return request(who,...)end},
   start=function(net,host,rules)
    check(rules.field==1 and rules.frames==18000,'accepted table and 5 minute budget')
    starts[who]=(starts[who]or 0)+1;duels[who]=Duel.new(net,host,rules);return true
   end,stop=function()starts.stopped=true end})
 end
 local a,b=client('1'),client('2');identity='1';return a,b
end
local function tick(a,b,n)
 for _=1,n or 1 do clock=clock+.5
  identity='1';a:tick(true);if duels['1']then duels['1']:update(.5)end
  identity='2';b:tick(true);if duels['2']then duels['2']:update(.5)end
 end
end
local function invitePair(a,b)
 identity='1';check(a:action('pinball:invite:'..devices[2]),'invite UI action');tick(a,b,1)
 check(invite.state=='pending'and not starts['1']and not starts['2'],'no premature start')
 identity='2';check(b:rows()[1].id=='pinball:accept:'..id,'incoming accept row')
end
local function acceptPair(a,b)
 invitePair(a,b);identity='2';check(b:action('pinball:accept:'..id),'accept action');tick(a,b,14)
 check(starts['1']==1 and starts['2']==1,'both clients launch exactly once')
 check(duels['1'].state=='lobby'and duels['2'].state=='lobby','real CloudNet carries both native Duel hellos')
end
local a,b=reset();check(a:context(true).edition=='pinballrs'and a:context(true).available,'Pinball presence')
acceptPair(a,b)
check(duels['1']:ready(string.rep('a',40)),'host native checkpoint');tick(a,b,3)
check(not duels['1'].started and not duels['2'].started,'wait for both native checkpoints')
check(duels['2']:ready(string.rep('a',40)),'guest native checkpoint');tick(a,b,8)
check(duels['1'].started and duels['2'].started,'joint launch after both ready')
check(duels['1']:progress(18000,123450,true)and duels['2']:progress(18000,4200,true),'independent native scores')
tick(a,b,8);check(duels['1'].result=='win'and duels['2'].result=='loss','consistent duel result over account wire')
a,b=reset();invitePair(a,b);identity='2';b:action('pinball:decline:'..id);tick(a,b,4)
check(invite.state=='declined'and not starts['1']and not starts['2'],'decline never launches')
a,b=reset();acceptPair(a,b);identity='1';a:action('pinball:cancel:'..id);tick(a,b,5)
check(duels['2'].state=='cancelled'and not duels['2'].result,'cancellation never invents winner')
a,b=reset();invitePair(a,b);invite.rules.backend='different-native-build';identity='2';b:action('pinball:accept:'..id)
check(not b.job and invite.state=='pending'and b.notice,'wrong build cannot be accepted')
check(Friends.fingerprint(session)~=Friends.fingerprint{rom_sha1=session.rom_sha1,backend=session.backend,content='EU'},'content identity separated')
a,b=reset();acceptPair(a,b);identity=nil;a:tick(true)
check(a.state=='idle'and not a.net and not a.job and starts.stopped,'signout closes queued launch and transport')
a,b=reset();invitePair(a,b);invite.state='accepted';identity='1';a:tick(true);a:tick(true)
check(a.state=='entering'and a.job,'pending enter prepared')
local cancelled=false;a.job={poll=function()return nil end,cancel=function()cancelled=true end}
clock=clock+91;a:tick(true)
check(cancelled and a.state=='idle'and a.purpose=='cancel','timeout cancels an in-flight enter before queuing cancellation')
print(checks..' synthetic ModCompass Pinball checks passed (not a live server test)')
