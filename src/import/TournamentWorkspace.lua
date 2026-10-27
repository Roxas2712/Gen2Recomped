local function F(...) return require('src.translation.Service').launcherFormat(...) end
local function L(value) return require('src.translation.Service').launcherLookup(value) end
local W={}
local Auth=require('src.cloud.RetroCloud')
local API=require('src.cloud.Tournaments')
local Task=require('src.cloud.Task')
local League=require('src.cloud.League')
local Versions=require('src.core.GameVersion')
local Art=require('src.import.ArenaPresentation')
local editions={'red','blue','yellow','gold','silver','crystal','ruby','sapphire','emerald','firered','leafgreen','platinum','heartgold','soulsilver','black','white'}
local function imported(self) local out={};for _,v in ipairs(editions) do if self.ready[v] then out[#out+1]=v end end;return out end
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
 local d={id=cup and cup.id,title=cup and cup.title or '',edition=cup and cup.edition or 'crystal',capacity=tostring(cup and cup.capacity or 16),
  format=cup and cup.format,team_size=tostring(cup and cup.team_size or 3),level=tostring(cup and cup.level or 50),rules=cup and cup.rules or '',starts_at=cup and cup.starts_at or '',
  dex=p.dex and tostring(p.dex) or '',prizeLevel=tostring(p.level or 5),egg=p.egg==true,shiny=p.shiny==true,moves=table.concat(p.moves or {},',')}
 require('src.import.GiftDesigner').init(d,p)
 if not next(p) then d.giftKind='none' end
 return d
end
function W.action(self,id)
 local f=state(self);if not f then return end
 if f.job then return end
 if id:match('^field:') then focus(f,id:sub(7));return end
 focus(f,nil)
 if f.form and require('src.import.GiftDesigner').action(f.form,id) then self.pageScroll=0;return end
 if id=='back' then f.cup=nil;f.form=nil;f.choose=nil;f.confirm=nil;f.leagueOpen=nil;f.accessForm=nil;self.pageScroll=0;refresh(self)
 elseif id=='shop' then self.pageScroll=0;job(self,'shop',function() return require('src.cloud.ArenaShop').request('GET') end)
 elseif id=='shopBack' then f.shop=nil;f.shopConfirm=nil;self.pageScroll=0;refresh(self)
 elseif id=='shopEdition' then
  local at=1;for i,v in ipairs(editions) do if v==(f.shopEdition or 'crystal') then at=i end end;f.shopEdition=editions[at%#editions+1];f.shopConfirm=nil
 elseif id:match('^shopBuy:') then
  for _,row in ipairs(f.shop and f.shop.catalogue or {}) do if row.id==id:sub(9) then
   if Versions.generation(f.shopEdition or 'crystal')<row.generation then f.notice='This edition has no compatible held-item slot.'
   elseif f.shop.coins<row.price then f.notice='Earn more Liga Coins before buying this item.'
   else f.shopConfirm=row;self.pageScroll=0 end
  end end
 elseif id=='shopCancel' then f.shopConfirm=nil
 elseif id=='shopConfirm' or id=='shopRetry' then
  local order=id=='shopRetry' and f.shopPending;local row=f.shopConfirm
  if order or row then local item=order and order.item or row.id;local edition=order and order.edition or f.shopEdition or 'crystal'
   job(self,'shop',function() return require('src.cloud.ArenaShop').purchase(item,edition) end)
  end
 elseif id=='shopCollect' then job(self,'shop',function() return require('src.cloud.ArenaShop').collect() end)
 elseif id=='refresh' then refresh(self)
 elseif id=='nextPage' or id=='prevPage' then
  f.page=math.max(1,f.page+(id=='nextPage' and 1 or -1));local page=f.page
  job(self,'index',function() local doc,why=require('src.cloud.NativeAccount').request('GET','/tournaments?page='..page,nil,true);return doc,why end)
 elseif id:match('^open:') then
  local key=id:sub(6);self.pageScroll=0;f.choose=nil;f.confirm=nil;f.accessForm=nil
  job(self,'cup',function() return API.request('GET',key) end)
 elseif id=='rankings' then f.leagueOpen=true;self.pageScroll=0
 elseif id=='joinLeague' or id=='leaveLeague' then local active=id=='joinLeague';job(self,'league',function() return League.request('POST','league/registration',{active=active}) end)
 elseif id:match('^challenge:') then local uid=tonumber(id:sub(11));local selected=f.selected or 'rookie';local games=imported(self);job(self,'league',function() return League.request('POST','league/challenges',{recipient=uid,format=selected,editions=games}) end)
 elseif id:match('^acceptChallenge:') or id:match('^declineChallenge:') then
  local accept=id:match('^acceptChallenge:')~=nil;local key=id:match(':(.+)$');local games=imported(self)
  job(self,'league',function() return League.request('POST','league/challenges/'..key..'/respond',{accept=accept,editions=games}) end)
 elseif id:match('^claimEggs:') then local key=id:sub(11);job(self,'eggs',function() return League.claim(key) end)
 elseif id=='giftStudio' then self:_openAccount('giftAdmin')
 elseif id:match('^format:') then f.selected=id:sub(8)
 elseif id:match('^arenaGeneration:') then
  local gen=tonumber(id:match(':(%d+)$'));f.queueEdition=({[1]='red',[2]='crystal',[3]='emerald',[4]='platinum',[5]='black'})[gen] or 'crystal';f.selected=nil
 elseif id:match('^arenaEdition:') then f.queueEdition=id:sub(14);f.selected=nil
 elseif id=='findRival' then
  local edition=f.queueEdition or 'crystal';local selected=f.selected or 'rookie'
  local league=f.index and f.index.arena and f.index.arena.league
  if league then
   if not league.registered then f.notice='Join this season before using league Auto-Match.';return end
   local games=imported(self);job(self,'arena',function() return League.request('POST','auto',{format=selected,editions=games}) end)
  else job(self,'arena',function() return API.arena('POST',{format=selected,edition=edition}) end) end
 elseif id=='leaveQueue' then job(self,'arena',function() return API.arena('DELETE') end)
 elseif id:match('^preset:') then
  local key=id:sub(8);f.form.format=key~='custom' and key or nil
  for _,c in ipairs(f.index and f.index.arena and f.index.arena.formats or {}) do if c.id==key then f.form.team_size=tostring(c.team_size);f.form.level=tostring(c.level);f.form.rules=c.rules;if f.form.title=='' then f.form.title=c.title end end end
 elseif id=='create' then f.form=form();self.pageScroll=0
 elseif id=='edit' then f.form=form(f.cup);self.pageScroll=0
 elseif id=='edition' then local at=1;for i,v in ipairs(editions) do if v==f.form.edition then at=i end end;f.form.edition=editions[at%#editions+1];f.form.format=nil
 elseif id=='egg' or id=='shiny' then f.form[id]=not f.form[id]
 elseif id=='saveCup' then
  local d=f.form
  for _,key in ipairs({'capacity','team_size','level','prizeLevel'}) do if not tonumber(d[key]) then f.notice=L('Enter a number for ')..key..'.';return end end
  local payload={format=d.format or 'custom',title=d.title,edition=d.edition,capacity=tonumber(d.capacity),team_size=tonumber(d.team_size),level=tonumber(d.level),rules=d.rules,starts_at=d.starts_at}
  local reward,why=require('src.import.GiftDesigner').payload(d);if why then f.notice=why;return end
  if reward then payload.prize=reward elseif d.id then payload.clear_prize=true end
  local key=d.id
  job(self,'saved',function() return API.request(key and 'PATCH' or 'POST',key,nil,payload) end)
 elseif id=='join' or id=='ready' or id=='notready' then
  local key=f.cup.id;job(self,'cup',function() return API.request('POST',key,'entry',{ready=id~='notready'}) end)
 elseif id=='leave' then local key=f.cup.id;job(self,'cup',function() return API.request('DELETE',key,'entry') end)
 elseif id=='cupAccess' then f.accessForm=true;f.accessReason='';f.accessTag='';self.pageScroll=0
 elseif id=='accessBack' then f.accessForm=nil;self.pageScroll=0
 elseif id=='accessMode' or id:match('^access:') then
  if #(f.accessReason or '')<15 then f.notice='Enter a reason of at least 15 characters.';return end
  local payload={reason=f.accessReason};local key=f.cup.id
  if id=='accessMode' then payload.invite_only=not f.cup.invite_only else payload.action=id:sub(8);payload.friend_tag=f.accessTag end
  job(self,'cup',function()return API.request('POST',key,'access',payload)end)
 elseif id=='start' then f.confirm={kind='start'}
 elseif id=='cancel' then f.confirm={kind='cancel',reason=''}
 elseif id=='dismiss' then f.accessForm=nil;f.confirm=nil;f.choose=nil;f.form=nil
 elseif id:match('^fight:') or id:match('^resumeFight:') then
  local index=tonumber(id:match(':(%d+)$'));local m=f.cup.matches[index]
  if m and m.state=='ready' then f.choose=index;f.resumeBattle=id:match('^resumeFight:')~=nil;self.pageScroll=0 end
 elseif id:match('^slot:') then
  local slot=id:sub(6);local cup=f.cup;local match=cup.matches[f.choose]
  job(self,'launch',function()
   local fresh,why=API.request('GET',cup.id);if not fresh then return nil,why end
   local current;for _,m in ipairs(fresh.matches or {}) do if m.id==match.id then current=m end end
   if not current then return nil,'This pairing is no longer available.' end
   local ok,problem=require('src.link.CloudArena').queue(fresh,current,slot,f.resumeBattle)
   return ok and {edition=cup.edition} or nil,problem
  end)
 elseif id:match('^report:') or id:match('^resolve:') then
  local kind,index,side=id:match('^(%a+):(%d+):(%a+)$');local match=f.cup.matches[tonumber(index)]
  if match then f.confirm={kind=kind,match=match.id,winner=match[side],reason=''} end
 elseif id=='confirm' then
  local key,c=f.cup.id,f.confirm;local payload={winner=c.winner and tonumber(c.winner),reason=c.reason}
  job(self,'changed',function() return API.request('POST',key,c.kind=='report' and 'result' or c.kind,payload,c.match) end)
 elseif id:match('^copyPrize:') or id:match('^redeemPrize:') then
  local gift=id:match(':(.+)$')
  for _,award in ipairs(f.index and f.index.awards or {}) do if award.gift_id==gift then
   if id:match('^copyPrize:') then love.system.setClipboardText(award.gift_code);f.notice='Private prize code copied.'
   else local code,edition=award.gift_code,award.edition;job(self,'prize',function() return require('src.cloud.GiftCodes').redeem(code,edition) end) end
  end end
 elseif id:match('^prize:') then local receipt=id:sub(7);job(self,'prize',function() return API.prize(receipt) end)
 end
end
function W.tick(self)
 require('src.link.ArenaResults').pump()
 if self.section~='tournaments' then if self._tournaments then close(self) end;return end
 local f=state(self);if not f then self:_sbGo('games');return end
 if f.job then
  local result=f.job:poll()
  if result then
   local purpose=f.purpose;f.job=nil
   if f.account~=Auth.accountId() or not Auth.signedIn() then close(self);return end
   if result.kind~='done' or not result.first then f.notice=tostring(result.error or result.second or 'The Arena is unavailable. Try Refresh.');f.nextRefresh=os.time()+30;return end
   local doc=result.first
   if purpose=='shop' then
    f.shop=doc;f.shopConfirm=nil;f.shopPending=require('src.cloud.ArenaShop').pending();f.notice=doc.collected and (tostring(doc.collected)..' account items reconciled with your Item Bank.') or doc.order and 'Purchase saved to your account. Collect into Item Bank to equip it.' or 'Wallet and purchases updated.';f.nextRefresh=os.time()+60;return
   elseif purpose=='launch' then
    f.choose=nil;self._arenaLaunch=true
    local ok,why=pcall(self.play,self,doc.edition);self._arenaLaunch=nil
    if not ok then require('src.link.CloudArena').cancelPending();f.notice=L('Battle launch failed: ')..tostring(why) end
    return
   elseif purpose=='league' then f.index=f.index or {arena={}};f.index.arena=f.index.arena or {};f.index.arena.league=doc;f.notice='League profile updated.'
   elseif purpose=='eggs' then f.notice=F('%d league eggs stored in your Bank. Compatible editions can receive them; unsupported species stay in the Bank.',#(doc.kept or {}));f.nextRefresh=0
   elseif purpose=='prize' then f.notice=doc.kind and 'Prize in your account inbox. Open Account > Gift codes to deliver it to a save copy.' or 'Prize restored to your Bank. Open the Bank to copy it to a compatible save.'
   elseif tostring(doc.account_id)~=f.account then f.notice='The account changed. Refresh the Arena.'
   elseif purpose=='arena' then
    f.index=f.index or {};f.index.arena=doc;f.notice=doc.queue and (doc.queue.tournament_id and 'Rival assigned. Open your pairing below.' or 'Searching for an online rival in this edition...') or 'You left the queue.';f.nextQueue=os.time()+20
   elseif purpose=='index' then f.index=doc;f.notice=doc.verification_notice or ''
   else f.cup=doc;f.confirm=nil;f.choose=nil;if purpose=='saved' then f.form=nil end;f.notice='Results require both players or an organizer decision.' end
   f.nextRefresh=os.time()+20
  end
 elseif not f.shop and not f.form and not f.confirm and not f.choose and not f.accessForm and f.index and f.index.arena and f.index.arena.queue and f.index.arena.queue.state=='searching' and os.time()>=(f.nextQueue or 0) then
  local q=f.index.arena.queue;f.nextQueue=os.time()+20
  job(self,'arena',function() if q.league then return League.request('POST','auto',{format=q.format,editions=q.editions}) end;return API.arena('POST',{format=q.format,edition=q.edition}) end)
 elseif not f.shop and not f.form and not f.confirm and not f.choose and not f.accessForm and (not f.index and not f.cup or os.time()>=(f.nextRefresh or 0)) then refresh(self) end
 local n=require('src.link.CloudArena').takeNotice()
 if n and n.account==f.account then f.notice=n.text;f.nextRefresh=os.time()+30;local key=n.id;job(self,'cup',function() return API.request('GET',key) end);f.returnNotice=n.text end
 if f.returnNotice and not f.job then f.notice=f.returnNotice;f.returnNotice=nil end
end
function W.draw(self,x,y,w,h)
 local f=state(self);if not f then return 0 end
 local U,P,g,s=self._ui,self.palette(),love.graphics,self._s
 local paint=require('src.import.LauncherLibrary').paint
 local top=y;f.rects={}
 local function text(value,big,color,inset)
  value=L(tostring(value or ''));local font=big and self.stateFont or self.hintFont
  local pad=(inset or 0);local _,lines=font:getWrap(value,w-28*s-pad);g.setFont(font);U.col(color or P.detail);g.printf(value,x+14*s+pad,y,w-28*s-pad,'left');y=y+math.max(1,#lines)*font:getHeight()+12*s
 end
 local function button(label,id,bw,bx,by)
  local r=self:_chipButton(bx or x,by or y,label,{w=bw or w,h=38*s,kind='accent'});r.id=id;f.rects[#f.rects+1]=r
  if not by then y=y+46*s end;return r
 end
 local function field(label,id,value)
  text(label);button((value and value~='' and value or 'Click to enter')..(f.focus==id and ' |' or ''),'field:'..id)
 end
 if f.shop then
  require('src.import.ArenaShopView').draw(self,f,x,function()return y end,w,text,button);return y-top
 end
 if f.form then
  local d=f.form;text(d.id and 'EDIT TOURNAMENT' or 'CREATE A CUP',true,P.ink)
  text('Community competition · Single elimination · Edition rules · Account-bound prizes')
  button('BACK','dismiss');button(L('Edition: ')..d.edition:upper(),'edition')
  local regional=false;for _,c in ipairs(f.index and f.index.arena and f.index.arena.formats or {}) do if c.generation==Versions.generation(d.edition) then regional=true end end
  for _,c in ipairs(f.index and f.index.arena and f.index.arena.formats or {}) do if c.generation==Versions.generation(d.edition) or c.id=='worlds' or not regional and not c.generation then button((d.format==c.id and '* ' or '')..c.title..' · '..c.team_size..L(' Pokémon'),'preset:'..c.id) end end
  button('Custom rules','preset:custom');field('Title','title',d.title)
  field('Capacity (2–64)','capacity',d.capacity);field('Team size (1–6)','team_size',d.team_size);field('Battle level (1–100)','level',d.level)
  field('Rules shown to all players','rules',d.rules);field('Scheduled start · optional ISO date with timezone','starts_at',d.starts_at)
  local tabAt=0
  require('src.import.GiftDesigner').draw(d,{d.edition},{text=text,row=button,field=function(label,id) field(label,id,d[id]) end,allowNone=true,tab=function(label,id,active)
   local bw=(w-12*s)/7;button((active and '• ' or '')..label,id,bw,x+tabAt*(bw+2*s),y)
   tabAt=tabAt+1;if tabAt==7 then y=y+52*s end
  end})
  button('SAVE TOURNAMENT','saveCup');text(f.notice);return y-top
 end
 if f.cup then
  local c=f.cup;local names={};local mine
  for _,p in ipairs(c.players or {}) do names[p.id]=p.nickname;if p.id==f.account then mine=p end end
  local function name(id) return id and (names[id] or 'Unavailable player') or 'Awaiting winner' end
  y=y+Art.hero(self,x,y,w,c.title,L('GEN ')..c.generation..' · '..c.edition:upper()..' · '..c.team_size..L(' Pokémon'))
  text(F('GEN %d · %s · %s · %d / %d players',c.generation,c.edition:upper(),require('src.translation.Service').launcherState(c.state),c.entries,c.capacity),false,P.link)
  button('ALL TOURNAMENTS','back');button('REFRESH LOBBY','refresh')
  text(c.invite_only and 'INVITATION ONLY · Organizer approval required' or 'OPEN REGISTRATION · Eligible players may join')
  if f.accessForm and c.manage then
   text('STAFF · PARTICIPATION CONTROLS',true,P.link)
   text('Changes are audited. Added players must confirm readiness themselves. Access is locked when the bracket starts.')
   field('Reason · at least 15 characters','accessReason',f.accessReason or '')
   button(c.invite_only and 'ALLOW OPEN REGISTRATION' or 'REQUIRE ORGANIZER INVITATION','accessMode')
   field('Complete friend tag · Trainer#1234','accessTag',f.accessTag or '')
   button('ADD / INVITE PLAYER','access:add');button('REMOVE PLAYER FROM LOBBY','access:remove');button('BLOCK FROM THIS CUP','access:block');button('REMOVE CUP BLOCK / INVITATION','access:unblock')
   for _,a in ipairs(c.access or {})do text(a.friend_tag..(a.blocked and L(' · BLOCKED') or L(' · INVITED')))end
   button('BACK TO LOBBY','accessBack');text(f.notice);return y-top
  end
  text(F('%d per team · Level %d · Single elimination · Community results',c.team_size,c.level))
  if c.starts_at then text(L('Scheduled: ')..c.starts_at..L(' UTC')) end
  if c.rules~='' then text(c.rules) end
  text(L('CHAMPION: ')..require('src.import.GiftDesigner').describe(c.prize)..L(' + Champion achievement'),false,P.link)
  text(f.notice)
  if c.battle_gate~='native_rules' then text('NATIVE MODULE UNAVAILABLE · This edition is not enabled by the private battle verifier. This bracket can still use community results.',false,P.link) else text('BANK PREFLIGHT · Native edition rules and two matching battle reports. Community result buttons do not award season points.',false,P.link) end
  if f.confirm then
   local q=f.confirm;text(L('CONFIRM ')..q.kind:upper(),true,P.ink)
   if q.winner then text(L('Winner: ')..name(q.winner)) end
   if q.kind=='cancel' or q.kind=='resolve' then field('Reason · recorded for organizers','reason',q.reason) end
   button('CONFIRM','confirm');button('GO BACK','dismiss');return y-top
  end
  if f.choose then
   text('CHOOSE YOUR BATTLE TEAM',true,P.link)
   text(F('Uses a temporary copy of the selected save party. Exactly %d members required; the battle sets level %d. The adventure save stays intact. Gameplay mods must be disabled.',c.team_size,c.level))
   if not self.ready[c.edition] then text(F('Import %s before entering this battle.',c.edition))
   else
    local count=0;for _,slot in ipairs(require('src.core.SaveData').listSlots(c.edition)) do
     if slot.exists and not slot.unreadable then button((slot.label or slot.name or slot.id)..L(' · ENTER LINK BATTLE'),'slot:'..slot.id);count=count+1 end
    end
    if count==0 then text('No saved party available yet. Start this edition and save a team first.') end
   end
   button('BACK TO LOBBY','dismiss');return y-top
  end
  if c.state=='open' then
   if not mine then button('JOIN TOURNAMENT · ACCEPT THESE RULES','join')
   else button(mine.ready and 'READY · CONFIRM AGAIN' or 'I AM READY','ready');button('NOT READY','notready');button('LEAVE TOURNAMENT','leave') end
   if c.manage then
    if not c.matchmaking then button('STAFF · PARTICIPATION CONTROLS','cupAccess')end
    button('START BRACKET · ALL PLAYERS MUST BE READY','start')
    if c.entries==0 then button('EDIT RULES & PRIZES','edit') end
    button('CANCEL TOURNAMENT','cancel')
   end
  elseif c.state=='running' and (c.manage or c.matchmaking and mine) then button(c.matchmaking and 'CANCEL THIS PAIRING · NO POINTS' or 'CANCEL TOURNAMENT','cancel') end
  y=y+Art.bracket(self,x,y,w,c,names)
  text('LOBBY',true,P.ink)
  for _,p in ipairs(c.players or {}) do text((p.online and '[ON] ONLINE  ' or '[OFF] OFFLINE  ')..(p.ready and 'READY · ' or 'WAITING · ')..require('src.ui.PlayerRole').label(p.nickname,p),false,p.ready and P.link or P.detail) end
  local round
  for i,m in ipairs(c.matches or {}) do
   if round~=m.round then round=m.round;y=y+14*s;text(L('ROUND ')..round,true,P.link) end
   local height=(m.can_report and 244 or 108)*s
   if m.can_report and m.state=='ready' and c.battle_gate=='native_rules'then height=height+92*s end
   if c.manage and (m.state=='ready' or m.state=='disputed') then height=height+92*s end
   paint.surface(x,y,w,height,12*s,m.state=='disputed' and P.chooseTop or P.link,false)
   y=y+14*s;text(name(m.left)..L('  vs  ')..name(m.right),true,P.ink)
   text(require('src.translation.Service').launcherState(m.state)..(m.winner and F(L(' · Winner: %s'),name(m.winner)) or ''))
   if m.can_report then
    if m.state=='ready' and c.battle_gate=='native_rules' then
     text('Both players enter here. Your frozen Bank teams connect through the account cloud; no room code is needed.')
     button('ENTER LINK BATTLE','fight:'..i)
     button('TAKE OVER RUNNING BATTLE ON THIS DEVICE','resumeFight:'..i)
    end
    button('I WON · CONFIRM RESULT','report:'..i..':'..(m.left==f.account and 'left' or 'right'))
    button('OPPONENT WON · CONFIRM RESULT','report:'..i..':'..(m.left==f.account and 'right' or 'left'))
   end
   if c.manage and (m.state=='ready' or m.state=='disputed') then
    button(L('RESOLVE: ')..name(m.left),'resolve:'..i..':left');button(L('RESOLVE: ')..name(m.right),'resolve:'..i..':right')
   end
   y=y+18*s
  end
 else
  if not f.leagueOpen then
   local heroY=y;y=y+Art.hero(self,x,y,w)
   f.rects[#f.rects+1]={x=x+w*.72,y=heroY,width=w*.28,height=244*s,id='rankings'}
  else text('SEASON RANKINGS',true,P.ink) end
  local arena=f.index and f.index.arena
  if arena then
   local league=arena.league
   y=y+Art.progress(self,x,y,w,league or arena)
   if league then
    text(league.season.title..' · '..league.season.starts_at..L(' to ')..league.season.ends_at..L(' UTC'),false,P.link)
    text(league.registered and (L('REGISTERED · Rank ')..tostring(league.rank or '--')..' / '..league.participants) or 'JOIN THIS THREE-MONTH SEASON · Participation is optional')
    button(league.registered and 'LEAVE THIS SEASON' or 'JOIN THIS THREE-MONTH SEASON',league.registered and 'leaveLeague' or 'joinLeague')
    button('LIGA COINS · ITEM SHOP & BATTLE DROPS','shop')
    button(f.leagueOpen and 'BACK TO CUPS' or 'TROPHY · RANKINGS, CHALLENGES & DAILY EGGS',f.leagueOpen and 'back' or 'rankings')
    if f.leagueOpen then
     text(f.notice)
     text('SEASON RANKINGS · TOP 100',true,P.ink)
     text('Challenge using the cup selected in the Arena. Accepting is optional; Auto-Match finds other online rivals.')
     for _,r in ipairs(league.ranking or {}) do
      text('#'..r.rank..'  '..r.friend_tag..' · '..r.points..L(' points · ')..r.wins..L(' wins')..(r.online and L(' · ONLINE') or ''),false,r.rank<=3 and P.link or P.detail)
      if league.registered and r.account_id~=f.account then button(L('CHALLENGE ')..r.nickname,'challenge:'..r.account_id) end
     end
     if #(league.ranking or {})==0 then text('Be the first player to join this season.') end
     text('DAILY PODIUM · 3 / 2 / 1 EGGS',true,P.link)
     text('At each UTC day close: 75% shiny chance per egg · All 1,025 species, including legends. Eggs stay in the Bank until a compatible edition supports them. Generation 1 cannot receive eggs.')
     text(league.reward_notice)
     for _,r in ipairs(league.rewards or {}) do
      text(r.day..L(' · Rank ')..r.rank..' · '..r.eggs..L(' eggs'))
      button(r.claimed and 'RESTORE THE SAME EGGS' or 'CLAIM DAILY EGGS','claimEggs:'..r.id)
     end
     if #(league.rewards or {})==0 then text('Your earned daily eggs will appear here after the UTC day closes.') end
     text('VOLUNTARY CHALLENGES',true,P.ink)
     for _,c in ipairs(league.challenges or {}) do
      text((c.sender==f.account and L('SENT TO #')..c.recipient or L('FROM #')..c.sender)..' · '..c.format:upper()..' · '..c.state:upper())
      if c.state=='accepted' and c.tournament_id then button('OPEN CHALLENGE','open:'..c.tournament_id)
      elseif c.recipient==f.account and c.state=='pending' then button('ACCEPT · USE A SHARED IMPORTED EDITION','acceptChallenge:'..c.id);button('DECLINE · NO POINT PENALTY','declineChallenge:'..c.id) end
     end
     text(f.notice);button('REFRESH LEAGUE','refresh');return y-top
    end
   end
   local q=arena.queue
   if q then
    text(q.tournament_id and 'RIVAL ASSIGNED · YOUR MATCH IS READY' or 'FINDING YOUR NEXT RIVAL',true,P.link)
    text(q.edition:upper()..' · '..q.format:upper()..L(' · Online accounts only · One queue across all your devices'))
    if q.tournament_id then button('OPEN ASSIGNED PAIRING','open:'..q.tournament_id) else button('LEAVE MATCHMAKING','leaveQueue') end
   end
   local edition=f.queueEdition or 'crystal';local generation=Versions.generation(edition)
   text(L('CHOOSE YOUR GAME · GEN ')..generation..' / '..edition:upper(),true,P.ink)
   local gw=(w-16*s)/5
   for gen=1,5 do button((gen==generation and '*' or '')..(w<520*s and 'G' or 'GEN ')..gen,'arenaGeneration:'..gen,gw,x+(gen-1)*(gw+4*s),y) end;y=y+46*s
   local choices={};for _,v in ipairs(editions) do if Versions.generation(v)==generation then choices[#choices+1]=v end end
   local ew=(w-4*s*(#choices-1))/#choices
   local short={sapphire='SAPPH.',emerald='EMER.',firered='F.RED',leafgreen='L.GREEN',platinum='PLAT.',heartgold='H.GOLD',soulsilver='S.SILV'}
   for i,v in ipairs(choices) do button((v==edition and '*' or '')..(ew<100*s and short[v] or v:upper()),'arenaEdition:'..v,ew,x+(i-1)*(ew+4*s),y) end;y=y+52*s
   text(L('CUPS FOR ')..edition:upper(),true,P.ink)
   local available={};local hasRegional=false
   for _,c in ipairs(arena.formats or {}) do if c.generation==generation then hasRegional=true end end
   for _,c in ipairs(arena.formats or {}) do
    if c.generation==generation or c.id=='worlds' or not hasRegional and not c.generation then available[#available+1]=c end
   end
   table.sort(available,function(a,b) if a.id=='worlds' then return false elseif b.id=='worlds' then return true end;return a.team_size<b.team_size end)
   local valid=false;for _,c in ipairs(available) do if c.id==f.selected then valid=true end end
   if not valid and available[1] then f.selected=available[1].id end
   local cols=w>=620*s and 2 or 1;local gap=14*s;local cw=(w-gap*(cols-1))/cols
   for i,c in ipairs(available) do
    local col=(i-1)%cols;local row=math.floor((i-1)/cols);local by=y+row*184*s;local bx=x+col*(cw+gap)
    local cardWidth=(i==#available and col==0 and cols==2) and w or cw
    Art.format(self,bx,by,cardWidth,c,((arena.league or arena).points or 0)<c.minimum_points,f.selected==c.id,edition)
    f.rects[#f.rects+1]={x=bx,y=by,width=cardWidth,height=170*s,id='format:'..c.id}
   end
   y=y+math.ceil(#available/cols)*184*s
   local selectedTitle='';for _,cup in ipairs(available)do if cup.id==f.selected then selectedTitle=L(cup.title);break end end
   button(L(arena.league and 'AUTO-MATCH · ' or 'FIND AN ONLINE RIVAL · ')..selectedTitle,'findRival')
   text('Auto-Match uses shared editions imported on this device. Both players enter a temporary native link battle from the pairing. Completed matching reports award +50 for a win and -25 for a loss.')
   if not arena.league and arena.points_notice then text(arena.points_notice) end
  end
  button('REFRESH ARENA','refresh')
  if f.index and f.index.manage then button('+ CREATE TOURNAMENT','create');button('STAFF · PRIZE STUDIO','giftStudio') end
  text(f.notice)
  if f.index then
   for _,award in ipairs(f.index.awards or {}) do
    text(L('★ CHAMPION · ')..award.title,true,P.link)
    if award.gift_code then
     text(L('YOUR PRIVATE GIFT CODE · ')..award.gift_code,true,P.link)
     text(L('For ')..award.edition:upper()..L('. Only your account can claim this prize.'))
     button('COPY PRIZE CODE','copyPrize:'..award.gift_id)
     button('REDEEM MY PRIZE','redeemPrize:'..award.gift_id)
    end
    if award.receipt_id then button('RESTORE MY PRIZE TO BANK','prize:'..award.receipt_id) end
   end
   if #(f.index.tournaments or {})==0 then text('The Arena is ready for its first cup. Organizers can create a tournament with edition rules and a champion prize.') end
   for _,c in ipairs(f.index.tournaments or {}) do
    y=y+Art.cup(self,x,y,w,c)+8*s
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
 local d=f.confirm or f.form or (f.accessForm and f);if not d then return end
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
   if k=='backspace' then local d=f.confirm or f.form or (f.accessForm and f);if not d then return end;d[f.focus]=(d[f.focus] or ''):gsub('[%z\1-\127\194-\244][\128-\191]*$','')
   elseif k=='escape' or k=='return' then focus(f,nil)
   elseif k=='v' and love.keyboard.isDown('lctrl','rctrl','lgui','rgui') then append(f,love.system.getClipboardText() or '') end
   return
  end
  if self.section=='tournaments' and f and k=='escape' then W.action(self,(f.confirm or f.choose or f.form or f.accessForm) and 'dismiss' or 'back');return end
  return key(self,k,...)
 end
end
W.close=close
return W
