local W={}
local Auth=require('src.cloud.RetroCloud')
local API=require('src.cloud.Tournaments')
local Task=require('src.cloud.Task')
local Versions=require('src.core.GameVersion')
local editions={'red','blue','yellow','gold','silver','crystal','ruby','sapphire','emerald','firered','leafgreen','platinum','heartgold','soulsilver','black','white'}
local function focus(f,id) f.focus=id;if love.keyboard.setTextInput then love.keyboard.setTextInput(id~=nil) end end
local function close(self)
 local f=self._tournaments;if f then if f.job then f.job:cancel() end;focus(f,nil) end
 self._tournaments=nil
end
local function state(self)
 local id=Auth.accountId()
 if not Auth.signedIn() then close(self);return end
 if self._tournaments and self._tournaments.account~=id then close(self) end
 if not self._tournaments then self._tournaments={account=id,rects={},notice='',page=1} end
 return self._tournaments
end
local function job(self,purpose,fn)
 local f=state(self);if not f or f.job then return end
 f.job,f.notice=Task.new(fn);f.purpose=purpose
 if f.job then f.notice='Connecting to the Arena...' end
 focus(f,nil)
end
local function refresh(self)
 local f=state(self);if not f then return end
 local id=f.cup and f.cup.id
 job(self,id and 'cup' or 'index',function() return API.request('GET',id) end)
end
local function form(cup)
 local p=cup and cup.prize or {}
 return {id=cup and cup.id,title=cup and cup.title or '',edition=cup and cup.edition or 'crystal',capacity=tostring(cup and cup.capacity or 16),
  team_size=tostring(cup and cup.team_size or 3),level=tostring(cup and cup.level or 50),rules=cup and cup.rules or '',starts_at=cup and cup.starts_at or '',
  dex=p.dex and tostring(p.dex) or '',prizeLevel=tostring(p.level or 5),egg=p.egg==true,shiny=p.shiny==true,moves=table.concat(p.moves or {},',')}
end
function W.action(self,id)
 local f=state(self);if not f then return end
 if f.job then return end
 if id:match('^field:') then focus(f,id:sub(7));return end
 focus(f,nil)
 if id=='back' then f.cup=nil;f.form=nil;f.choose=nil;f.confirm=nil;self.pageScroll=0;refresh(self)
 elseif id=='refresh' then refresh(self)
 elseif id=='nextPage' or id=='prevPage' then
  f.page=math.max(1,f.page+(id=='nextPage' and 1 or -1));local page=f.page
  job(self,'index',function() local doc,why=require('src.cloud.NativeAccount').request('GET','/tournaments?page='..page,nil,true);return doc,why end)
 elseif id:match('^open:') then
  local key=id:sub(6);self.pageScroll=0;f.choose=nil;f.confirm=nil
  job(self,'cup',function() return API.request('GET',key) end)
 elseif id=='create' then f.form=form();self.pageScroll=0
 elseif id=='edit' then f.form=form(f.cup);self.pageScroll=0
 elseif id=='edition' then local at=1;for i,v in ipairs(editions) do if v==f.form.edition then at=i end end;f.form.edition=editions[at%#editions+1]
 elseif id=='egg' or id=='shiny' then f.form[id]=not f.form[id]
 elseif id=='saveCup' then
  local d=f.form;local payload={title=d.title,edition=d.edition,capacity=tonumber(d.capacity),team_size=tonumber(d.team_size),level=tonumber(d.level),rules=d.rules,starts_at=d.starts_at~='' and d.starts_at or nil}
  if d.dex~='' then
   local moves={};for move in d.moves:upper():gmatch('[^,%s]+') do moves[#moves+1]=move end
   payload.prize={dex=tonumber(d.dex),level=tonumber(d.prizeLevel),egg=d.egg,shiny=d.shiny,moves=moves}
  elseif d.id then payload.clear_prize=true end
  local key=d.id
  job(self,'saved',function() return API.request(key and 'PATCH' or 'POST',key,nil,payload) end)
 elseif id=='join' or id=='ready' or id=='notready' then
  local key=f.cup.id;job(self,'cup',function() return API.request('POST',key,'entry',{ready=id~='notready'}) end)
 elseif id=='leave' then local key=f.cup.id;job(self,'cup',function() return API.request('DELETE',key,'entry') end)
 elseif id=='start' then f.confirm={kind='start'}
 elseif id=='cancel' then f.confirm={kind='cancel',reason=''}
 elseif id=='dismiss' then f.confirm=nil;f.choose=nil;f.form=nil
 elseif id:match('^fight:') then
  local index=tonumber(id:match(':(%d+)$'));local m=f.cup.matches[index]
  if m and m.state=='ready' then f.choose=index;self.pageScroll=0 end
 elseif id:match('^slot:') then
  local slot=id:sub(6);local cup=f.cup;local match=cup.matches[f.choose]
  job(self,'launch',function()
   local fresh,why=API.request('GET',cup.id);if not fresh then return nil,why end
   local current;for _,m in ipairs(fresh.matches or {}) do if m.id==match.id then current=m end end
   if not current then return nil,'This pairing is no longer available.' end
   local ok,problem=require('src.link.CloudArena').queue(fresh,current,slot)
   return ok and {edition=cup.edition} or nil,problem
  end)
 elseif id:match('^report:') or id:match('^resolve:') then
  local kind,index,side=id:match('^(%a+):(%d+):(%a+)$');local match=f.cup.matches[tonumber(index)]
  if match then f.confirm={kind=kind,match=match.id,winner=match[side],reason=''} end
 elseif id=='confirm' then
  local key,c=f.cup.id,f.confirm;local payload={winner=c.winner and tonumber(c.winner),reason=c.reason}
  job(self,'changed',function() return API.request('POST',key,c.kind=='report' and 'result' or c.kind,payload,c.match) end)
 elseif id:match('^prize:') then local receipt=id:sub(7);job(self,'prize',function() return API.prize(receipt) end)
 end
end
function W.tick(self)
 if self.section~='tournaments' then if self._tournaments then close(self) end;return end
 local f=state(self);if not f then self:_sbGo('games');return end
 if f.job then
  local result=f.job:poll()
  if result then
   local purpose=f.purpose;f.job=nil
   if f.account~=Auth.accountId() or not Auth.signedIn() then close(self);return end
   if result.kind~='done' or not result.first then f.notice=tostring(result.error or result.second or 'The Arena is unavailable. Try Refresh.');f.nextRefresh=os.time()+30;return end
   local doc=result.first
   if purpose=='launch' then
    f.choose=nil;self._arenaLaunch=true
    local ok,why=pcall(self.play,self,doc.edition);self._arenaLaunch=nil
    if not ok then require('src.link.CloudArena').cancelPending();f.notice='Battle launch failed: '..tostring(why) end
    return
   elseif purpose=='prize' then f.notice='Prize restored to your Bank. Open the Bank to copy it to a compatible save.'
   elseif tostring(doc.account_id)~=f.account then f.notice='The account changed. Refresh the Arena.'
   elseif purpose=='index' then f.index=doc;f.notice=doc.verification_notice or ''
   else f.cup=doc;f.confirm=nil;f.choose=nil;if purpose=='saved' then f.form=nil end;f.notice='Results require both players or an organizer decision.' end
   f.nextRefresh=os.time()+20
  end
 elseif not f.form and not f.confirm and not f.choose and (not f.index and not f.cup or os.time()>=(f.nextRefresh or 0)) then refresh(self) end
 local n=require('src.link.CloudArena').takeNotice()
 if n and n.account==f.account then f.notice=n.text;f.nextRefresh=os.time()+30;local key=n.id;job(self,'cup',function() return API.request('GET',key) end);f.returnNotice=n.text end
 if f.returnNotice and not f.job then f.notice=f.returnNotice;f.returnNotice=nil end
end
function W.draw(self,x,y,w,h)
 local f=state(self);if not f then return 0 end
 local U,P,g,s=self._ui,self.palette(),love.graphics,self._s
 local paint=require('src.import.LauncherLibrary').paint
 local top=y;f.rects={}
 local function text(value,big,color)
  value=tostring(value or '');local font=big and self.stateFont or self.hintFont
  local _,lines=font:getWrap(value,w-28*s);g.setFont(font);U.col(color or P.detail);g.printf(value,x+14*s,y,w-28*s,'left');y=y+math.max(1,#lines)*font:getHeight()+12*s
 end
 local function button(label,id,bw,bx,by)
  local r=self:_chipButton(bx or x,by or y,label,{w=bw or w,h=38*s,kind='accent'});r.id=id;f.rects[#f.rects+1]=r
  if not by then y=y+46*s end;return r
 end
 local function field(label,id,value)
  text(label);button((value and value~='' and value or 'Click to enter')..(f.focus==id and ' |' or ''),'field:'..id)
 end
 local function trophy(cx,cy,r)
  U.col(P.link);g.setLineWidth(2*s);g.rectangle('line',cx-r*.5,cy-r*.6,r,r,5*s,5*s)
  g.arc('line','open',cx-r*.5,cy-r*.1,r*.4,math.pi/2,math.pi*1.5);g.arc('line','open',cx+r*.5,cy-r*.1,r*.4,-math.pi/2,math.pi/2)
  g.line(cx,cy+r*.4,cx,cy+r*.8);g.line(cx-r*.5,cy+r*.8,cx+r*.5,cy+r*.8)
 end
 if f.form then
  local d=f.form;text(d.id and 'EDIT TOURNAMENT' or 'CREATE A CUP',true,P.ink)
  text('Community competition · Single elimination · Edition rules · Account-bound prizes')
  button('BACK','dismiss');field('Title','title',d.title);button('Edition: '..d.edition:upper(),'edition')
  field('Capacity (2–64)','capacity',d.capacity);field('Team size (1–6)','team_size',d.team_size);field('Battle level (1–100)','level',d.level)
  field('Rules shown to all players','rules',d.rules);field('Scheduled start · optional ISO date with timezone','starts_at',d.starts_at)
  text('CHAMPION’S PRIZE',true,P.link);text('Leave the species blank for an achievement only. Gen 1 supports special Pokémon, but no eggs or shiny setting.')
  field('National species number','dex',d.dex);field('Prize level','prizeLevel',d.prizeLevel);field('Special moves · optional canonical names, comma-separated','moves',d.moves)
  button((d.egg and '[x]' or '[ ]')..' Egg','egg');button((d.shiny and '[x]' or '[ ]')..' Shiny','shiny')
  button('SAVE TOURNAMENT','saveCup');text(f.notice);return y-top
 end
 if f.cup then
  local c=f.cup;local names={};local mine
  for _,p in ipairs(c.players or {}) do names[p.id]=p.nickname;if p.id==f.account then mine=p end end
  local function name(id) return id and (names[id] or 'Unavailable player') or 'Awaiting winner' end
  text(c.title,true,P.ink);text('GEN '..c.generation..' · '..c.edition:upper()..' · '..c.state:upper()..' · '..c.entries..' / '..c.capacity..' players',false,P.link)
  button('ALL TOURNAMENTS','back');button('REFRESH LOBBY','refresh')
  text(c.team_size..' per team · Level '..c.level..' · Single elimination · Community results')
  if c.starts_at then text('Scheduled: '..c.starts_at..' UTC') end
  if c.rules~='' then text(c.rules) end
  if c.prize then text('CHAMPION: # '..c.prize.dex..(c.prize.shiny and ' · SHINY' or '')..(c.prize.egg and ' · EGG' or '')..' + Champion achievement',false,P.link) else text('CHAMPION: permanent achievement',false,P.link) end
  text(f.notice)
  if f.confirm then
   local q=f.confirm;text('CONFIRM '..q.kind:upper(),true,P.ink)
   if q.winner then text('Winner: '..name(q.winner)) end
   if q.kind=='cancel' or q.kind=='resolve' then field('Reason · recorded for organizers','reason',q.reason) end
   button('CONFIRM','confirm');button('GO BACK','dismiss');return y-top
  end
  if f.choose then
   text('CHOOSE YOUR BATTLE TEAM',true,P.link)
   text('Uses a temporary copy of the selected save party. Exactly '..c.team_size..' members required; the battle sets level '..c.level..'. The adventure save stays intact. Gameplay mods must be disabled.')
   if not self.ready[c.edition] then text('Import '..c.edition..' before entering this battle.')
   else
    local count=0;for _,slot in ipairs(require('src.core.SaveData').listSlots(c.edition)) do
     if slot.exists and not slot.unreadable then button((slot.label or slot.name or slot.id)..' · ENTER LINK BATTLE','slot:'..slot.id);count=count+1 end
    end
    if count==0 then text('No saved party available yet. Start this edition and save a team first.') end
   end
   button('BACK TO LOBBY','dismiss');return y-top
  end
  if c.state=='open' then
   if not mine then button('JOIN TOURNAMENT · ACCEPT THESE RULES','join')
   else button(mine.ready and 'READY · CONFIRM AGAIN' or 'I AM READY','ready');button('NOT READY','notready');button('LEAVE TOURNAMENT','leave') end
   if c.manage then
    button('START BRACKET · ALL PLAYERS MUST BE READY','start')
    if c.entries==0 then button('EDIT RULES & PRIZES','edit') end
    button('CANCEL TOURNAMENT','cancel')
   end
  elseif c.state=='running' and c.manage then button('CANCEL TOURNAMENT','cancel') end
  text('LOBBY',true,P.ink)
  for _,p in ipairs(c.players or {}) do text((p.ready and '● READY  ' or '○ WAITING  ')..p.nickname,false,p.ready and P.link or P.detail) end
  local round
  for i,m in ipairs(c.matches or {}) do
   if round~=m.round then round=m.round;y=y+14*s;text('ROUND '..round,true,P.link) end
   local height=(m.can_report and 244 or 108)*s
   if c.manage and m.state=='disputed' then height=height+92*s end
   paint.surface(x,y,w,height,12*s,m.state=='disputed' and P.chooseTop or P.link,false)
   y=y+14*s;text(name(m.left)..'  vs  '..name(m.right),true,P.ink)
   text(m.state:upper()..(m.winner and ' · Winner: '..name(m.winner) or ''))
   if m.can_report then
    if m.state=='ready' then
     text(m.left==f.account and 'You host this pairing. Enter to publish its room.' or (m.room and 'Host room ready · '..m.room or 'Waiting for the host to open the battle.'))
     button('ENTER LINK BATTLE','fight:'..i)
    end
    button('I WON · CONFIRM RESULT','report:'..i..':'..(m.left==f.account and 'left' or 'right'))
    button('OPPONENT WON · CONFIRM RESULT','report:'..i..':'..(m.left==f.account and 'right' or 'left'))
   end
   if c.manage and m.state=='disputed' then
    button('RESOLVE: '..name(m.left),'resolve:'..i..':left');button('RESOLVE: '..name(m.right),'resolve:'..i..':right')
   end
   y=y+18*s
  end
 else
  paint.surface(x,y,w,154*s,14*s,P.link,false);trophy(x+w-68*s,y+70*s,35*s)
  local before=y;y=y+18*s;text('THE ARENA',true,P.ink);text('Find your rivals. Earn your place.');text('Cups · Link battles · Champion rewards',false,P.link);y=math.max(y,before+172*s)
  button('REFRESH','refresh')
  if f.index and f.index.manage then button('+ CREATE TOURNAMENT','create') end
  text(f.notice)
  if f.index then
   for _,award in ipairs(f.index.awards or {}) do
    text('★ CHAMPION · '..award.title,true,P.link)
    if award.receipt_id then button('RESTORE MY PRIZE TO BANK','prize:'..award.receipt_id) end
   end
   if #(f.index.tournaments or {})==0 then text('The Arena is ready for its first cup. Organizers can create a tournament with edition rules and a champion prize.') end
   for _,c in ipairs(f.index.tournaments or {}) do
    paint.surface(x,y,w,166*s,12*s,P.link,false);y=y+14*s
    text(c.title,true,P.ink);text('GEN '..c.generation..' · '..c.edition:upper()..' · '..c.team_size..' per team · Lv. '..c.level,false,P.link)
    text(c.state:upper()..' · '..c.entries..' / '..c.capacity..' players'..(c.prize and ' · Champion prize' or ' · Champion achievement'))
    button('OPEN LOBBY & BRACKET','open:'..c.id);y=y+18*s
   end
   if f.page>1 then button('PREVIOUS PAGE','prevPage') end
   if f.page*20<f.index.total then button('NEXT PAGE','nextPage') end
  end
 end
 return y-top
end
local function append(f,value)
 if not f.focus then return end
 local d=f.confirm or f.form;if not d then return end
 local limit=f.focus=='rules' and 3000 or f.focus=='reason' and 1000 or 160
 d[f.focus]=((d[f.focus] or '')..value:gsub('[%c]','')):sub(1,limit)
end
function W.install(RI)
 local new=RI.new;RI.new=function(...)
  local self=new(...);local n=require('src.link.CloudArena').takeNotice()
  if n and Auth.signedIn() and n.account==Auth.accountId() then
   self:_sbGo('tournaments');local f=state(self);f.returnNotice=n.text
   job(self,'cup',function() return API.request('GET',n.id) end)
  end
  return self
 end
 local open=RI._openAccount;RI._openAccount=function(self,...) if self._tournaments then focus(self._tournaments,nil) end;return open(self,...) end
 local play=RI.play;RI.play=function(self,...) if not self._arenaLaunch then require('src.link.CloudArena').cancelPending() end;return play(self,...) end
 local owns=RI._sbOwns;RI._sbOwns=function(self,...) if self.section=='tournaments' then return true end;return owns(self,...) end
 local draw=RI._sbDrawContent;RI._sbDrawContent=function(self,x,y,w,h,...) if self.section=='tournaments' then return W.draw(self,x,y,w,h) end;return draw(self,x,y,w,h,...) end
 local update=RI.update;RI.update=function(self,dt,...) W.tick(self);return update(self,dt,...) end
 local press=RI._sbMousepressed;RI._sbMousepressed=function(self,x,y,...)
  local f=self._tournaments;local area=self._sbContentRect
  if self.section=='tournaments' and f and area and x>=area.x and y>=area.y and y<area.y+area.h then
   for _,r in ipairs(f.rects or {}) do if self._ui.inside(r,x,y) then W.action(self,r.id);return true end end
   focus(f,nil)
  end
  return press(self,x,y,...)
 end
 local input=RI.textinput;RI.textinput=function(self,value,...) local f=self._tournaments;if self.section=='tournaments' and f and f.focus then append(f,value);return end;return input(self,value,...) end
 local key=RI.keypressed;RI.keypressed=function(self,k,...)
  local f=self._tournaments
  if self.section=='tournaments' and f and f.focus then
   if k=='backspace' then local d=f.confirm or f.form;d[f.focus]=(d[f.focus] or ''):gsub('[%z\1-\127\194-\244][\128-\191]*$','')
   elseif k=='escape' or k=='return' then focus(f,nil)
   elseif k=='v' and love.keyboard.isDown('lctrl','rctrl','lgui','rgui') then append(f,love.system.getClipboardText() or '') end
   return
  end
  if self.section=='tournaments' and f and k=='escape' then W.action(self,(f.confirm or f.choose or f.form) and 'dismiss' or 'back');return end
  return key(self,k,...)
 end
end
W.close=close
return W
