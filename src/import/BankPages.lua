local function L(value) return require('src.translation.Service').launcherLookup(value) end
-- Bank subpages share the native box workspace, not browser windows.
local P={}
local B=require('src.storage.PokemonBank')
local Versions=require('src.core.GameVersion')
local function versionLabel(v) return (Versions.info(v) or {}).label or 'Universal Bank' end
function P.draw(self,f,x,y,w,h,s,button,text,col)
  if f.mode=='bank' or not f.mode then return false end
  local g=love.graphics;local font=self.hintFont
  local bottom=y+h
  local function line(label,by,big) text(label,x,by,w,big) end
  if f.mode=='details' then
    line('POKÉMON · ORIGIN AND LUA DATA',y,true)
    local entry=f.inspected and f.inspected.entry
    if not entry then line('Select a Pokémon in Bank boxes first.',y+42*s)
    else
      local origin=entry.origin or entry.mon.retroBankOrigin or entry.source
      local rows={entry.mon.nickname or tostring(entry.mon.species),'LEVEL · '..tostring(entry.mon.level),
        'GAME · '..versionLabel(origin.version or entry.source.version),
        'SAVE · '..tostring(origin.slot or entry.source.slot)..' / '..tostring(origin.saveId or entry.source.saveId or 'Legacy save'),
        'TRAINER ID · '..tostring(origin.trainerId or entry.mon.otId or 'Unknown'),
        'POKÉMON ID · '..tostring(origin.recordId or entry.id or 'Deposit to allocate'),
        'ITEM · '..tostring(entry.mon.item or entry.mon.heldItem or entry.mon.retroBankHeld and ('In Item Bank: '..entry.mon.retroBankHeld.canonical) or 'None')}
      local report=require('src.storage.LuaData').inspect(entry.mon)
      local fields={};for _,field in ipairs(report.fields) do fields[#fields+1]=field.name..' ('..field.kind..')' end
      rows[#rows+1]='LUA · '..report.nodes..' data nodes · '..table.concat(fields,', ')
      local top=y+42*s
      for _,row in ipairs(rows) do
        row=L(row);local _,lines=font:getWrap(row,w);g.setFont(font);col(37,68,79);g.printf(row,x,top,w,'left');top=top+#lines*font:getHeight()+12*s
      end
      button('COPY POKÉMON ID',x,top,w,'copyPokemonId')
    end
  elseif f.mode=='interop' then
    require('src.import.BankInterchangeWorkspace').draw(self,f,x,y,w,h,s,button,text,col)
  elseif f.mode=='items' then
    line('ITEM BANK · HELD ITEMS IN SAFEKEEPING',y,true)
    line('Choose an available item, then attach it to a selected Bank Pokémon.',y+32*s)
    local pageSize=math.max(1,math.floor((h-140*s)/(54*s)));local from=(f.modePage or 0)*pageSize+1
    for i=from,math.min(#(f.items or {}),from+pageSize-1) do
      local row=f.items[i];local by=y+70*s+(i-from)*54*s
      col(211,231,249);g.rectangle('fill',x,by,w,46*s,8*s,8*s)
      col(255,209,91);g.circle('fill',x+22*s,by+22*s,10*s)
      text(row.canonical..' · '..row.state,x+44*s,by+8*s,w-160*s)
      text(Versions.info(row.version).label,x+44*s,by+27*s,w-160*s)
      if row.state=='available' then button(f.itemSelected==row.id and 'SELECTED' or 'CHOOSE',x+w-110*s,by+6*s,105*s,'itemSelect',{id=row.id}) end
    end
    if #(f.items or {})==0 then line('No stored items yet. Held items from incompatible destinations appear here after saving the copy.',y+80*s) end
    button('‹',x,bottom-62*s,42*s,'modePage',{delta=-1})
    button('›',x+52*s,bottom-62*s,42*s,'modePage',{delta=1,max=math.max(0,math.ceil(#(f.items or {})/pageSize)-1)})
    if f.itemSelected and f.inspected then button('ATTACH TO SELECTED POKÉMON',x+108*s,bottom-62*s,math.max(90*s,w-108*s),'itemEquip') end
  elseif f.mode=='dex' then
    line('GLOBAL POKÉDEX · ALL YOUR ADVENTURES',y,true)
    line(tostring(f.dexOwned or 0)..' caught · '..tostring(#(f.dexRows or {}))..' seen · Shared across your saves and Bank.',y+32*s)
    local columns=w>650*s and 5 or w>380*s and 3 or 2
    local rowHeight=55*s;local count=math.max(1,math.floor((h-142*s)/rowHeight));local pageSize=columns*count
    local byId={};for _,row in ipairs(f.dexRows or {}) do byId[row.id]=row end
    local from=(f.modePage or 0)*pageSize+1;local width=(w-(columns-1)*10*s)/columns
    for i=from,math.min(649,from+pageSize-1) do
      local row=byId[i];local n=i-from;local bx=x+(n%columns)*(width+10*s);local by=y+72*s+math.floor(n/columns)*rowHeight
      col(row and 185 or 221,row and 223 or 232,244);g.rectangle('fill',bx,by,width,47*s,7*s,7*s)
      button(('%03d · %s'):format(i,row and (row.owned and '● ' or '○ ')..row.name or '—'),bx+3*s,by+6*s,width-6*s,'dexSpecies',{id=i})
    end
    button('‹',x,bottom-62*s,42*s,'modePage',{delta=-1})
    button('›',x+52*s,bottom-62*s,42*s,'modePage',{delta=1,max=math.max(0,math.ceil(649/pageSize)-1)})
    local row=f.dexSelected and byId[f.dexSelected]
    if row then
      local sources={};for _,source in pairs(row.sources) do sources[#sources+1]=versionLabel(source.version)..' / '..source.slot end
      table.sort(sources);text(table.concat(sources,' · '),x+112*s,bottom-52*s,w-112*s)
    end
  else
    local wonder=f.mode=='wonder'
    line(wonder and 'WONDER TRADE · A NEW ENCOUNTER' or 'LINK TRADE · CONNECT YOUR ADVENTURES',y,true)
    local profile=f.tradeProfile
    if not require('src.cloud.RetroCloud').signedIn() then
      line('Registration and verified email are required for both trade modes.',y+45*s)
      button('REGISTER / SIGN IN',x,y+92*s,math.min(w,290*s),'tradeLogin');return true
    end
    local own=profile and profile.recompiler_id or 'Connecting...'
    text('THIS DEVICE · '..own,x,y+40*s,w-150*s)
    button('COPY MY ID',x+w-140*s,y+34*s,140*s,'copyDeviceId')
    local deviceCount=profile and #(profile.devices or {}) or 0
    text(tostring(deviceCount)..' device IDs belong to this account. Exchanges follow the account; device IDs identify the endpoints.',x,y+78*s,w)
    local top=y+113*s
    if f.tradeChoose then
      local pageSize=math.max(1,math.floor((h-210*s)/(45*s)));local from=(f.tradeChoosePage or 0)*pageSize+1
      for i=from,math.min(#f.bank,from+pageSize-1) do
        local entry=f.bank[i]
        button((entry.mon.nickname or tostring(entry.mon.species))..' · Lv.'..entry.mon.level..' · '..versionLabel(entry.source.version),x,top+(i-from)*45*s,w,'tradePick',{entry=entry})
      end
      button('‹',x,bottom-62*s,42*s,'tradePickPage',{delta=-1})
      button('›',x+52*s,bottom-62*s,42*s,'tradePickPage',{delta=1,max=math.max(0,math.ceil(#f.bank/pageSize)-1)})
      button('CANCEL',x+w-120*s,bottom-62*s,120*s,'tradePickCancel');return true
    end
    local selected=f.tradeSelected
    button(selected and ((selected.mon.nickname or tostring(selected.mon.species))..' · Lv.'..selected.mon.level) or 'CHOOSE A BANK POKÉMON',x,top,w,'tradeChoose');top=top+46*s
    if not wonder and not f.replying then
      button('TO · '..tostring(f.recipient or 'ENTER RECOMPILER ID')..(f.tradeFocus and ' |' or ''),x,top,w-90*s,'tradeRecipient')
      button('PASTE',x+w-82*s,top,82*s,'tradePaste');top=top+46*s
    elseif f.replying then text('Reply to the selected incoming offer.',x,top,w);top=top+30*s end
    local notice='Share this Bank copy, including nickname, trainer and origin information, with the other player. Original saves and Bank archives remain intact.'
    if wonder then notice=notice..' Up to 30 active offers per account, including eggs. Results unlock after at least 10 minutes; after 6 hours without a partner you receive a random native Gen 1–5 encounter with OT RetroRecomp.' end
    notice=L(notice);local _,lines=font:getWrap(notice,w);g.setFont(font);col(43,76,103);g.printf(notice,x,top,w,'left');top=top+#lines*font:getHeight()+10*s
    button(f.tradeConsent and '✓ I AGREE TO SHARE THIS COPY' or '□ I AGREE TO SHARE THIS COPY',x,top,w,'tradeConsent');top=top+45*s
    local half=(w-10*s)/2
    button(f.tradeJob and 'WORKING...' or f.replying and 'SEND REPLY' or wonder and 'ENTER WONDER TRADE' or 'CREATE TRADE OFFER',x,top,half,'tradeSubmit')
    button('REFRESH EXCHANGES',x+half+10*s,top,half,'tradeRefresh');top=top+48*s
    local exchanges=profile and profile.exchanges or {}
    local pageSize=math.max(1,math.floor((bottom-top-60*s)/(63*s)));local from=(f.tradePage or 0)*pageSize+1
    for i=from,math.min(#exchanges,from+pageSize-1) do
      local row=exchanges[i];local by=top+(i-from)*63*s
      col(206,226,245);g.rectangle('fill',x,by,w,57*s,8*s,8*s)
      local offered=row.offered or {};local reply=row.reply or {}
      local action=row.status=='completed' and 'tradeReceive' or row.status=='prepared' and row.sender and 'tradeConfirm' or row.status=='pending' and not row.sender and 'tradeReply' or nil
      local textWidth=math.max(1,w-(action and row.status~='completed' and 282 or 155)*s)
      local partner=row.legacy_offer and 'Older offer · cancel and submit again' or row.system_partner and 'SYSTEM · OT RetroRecomp' or row.partner or 'Finding a partner · 10 min–6 h'
      text(tostring(row.mode):upper()..' · '..row.status..' · '..tostring(partner),x+10*s,by+5*s,textWidth)
      text(tostring(offered.nickname or offered.species or '?')..(row.reply and (' ⇄ '..tostring(reply.nickname or reply.species)) or ''),x+10*s,by+29*s,textWidth)
      if action and row.status~='completed' then button('CANCEL',x+w-264*s,by+12*s,118*s,'tradeCancel',{exchange=row.id}) end
      if action then button(action=='tradeReceive' and 'RECEIVE' or action=='tradeConfirm' and 'CONFIRM' or 'REPLY',x+w-136*s,by+12*s,126*s,action,{exchange=row.id})
      elseif row.status=='pending' or row.status=='prepared' then button('CANCEL',x+w-136*s,by+12*s,126*s,'tradeCancel',{exchange=row.id}) end
    end
    button('‹',x,bottom-39*s,42*s,'tradePage',{delta=-1})
    button('›',x+52*s,bottom-39*s,42*s,'tradePage',{delta=1,max=math.max(0,math.ceil(#exchanges/pageSize)-1)})
  end
  return true
end
function P.press(self,W,r)
  local f=self._bankOverlay
  if require('src.import.BankInterchangeWorkspace').press(self,r) then return true end
  if r.action=='mode' then W.mode(self,r.mode)
  elseif r.action=='modePage' or r.action=='tradePage' or r.action=='tradePickPage' then
    local key=r.action=='modePage' and 'modePage' or r.action=='tradePage' and 'tradePage' or 'tradeChoosePage'
    f[key]=math.max(0,math.min(r.max or math.huge,(f[key] or 0)+r.delta))
  elseif r.action=='itemSelect' then f.itemSelected=r.id
  elseif r.action=='itemEquip' then
    local id,why=require('src.storage.BankItems').equip(f.itemSelected,f.inspected.entry)
    if id then f.bank=B.list();f.items=require('src.storage.BankItems').list();f.notice='Equipped a new Bank copy. Drag it into a supported save to keep it there.';f.itemSelected=nil else f.notice=why end
  elseif r.action=='dexSpecies' then f.dexSelected=r.id
  elseif r.action=='copyPokemonId' then
    local entry=f.inspected and f.inspected.entry
    local origin=entry and (entry.origin or entry.mon.retroBankOrigin)
    if origin and origin.recordId and love.system and love.system.setClipboardText then love.system.setClipboardText(origin.recordId);f.notice='Pokémon origin ID copied.' end
  elseif r.action=='tradeLogin' then
    if f.left.dirty or f.right.dirty then f.notice='Save your staged copies before signing in.'
    else W.close(self);self:_openAccount() end
  elseif r.action=='copyDeviceId' then
    if f.tradeProfile and love.system.setClipboardText then love.system.setClipboardText(f.tradeProfile.recompiler_id);f.notice='This device’s Recompiler ID was copied.' end
  elseif r.action=='tradeChoose' then f.tradeChoose=true;f.tradeChoosePage=0
  elseif r.action=='tradePick' then f.tradeSelected=r.entry;f.tradeChoose=nil;f.tradeConsent=false
  elseif r.action=='tradePickCancel' then f.tradeChoose=nil
  elseif r.action=='tradeRecipient' then f.tradeFocus=true;if self._armTextInput then self:_armTextInput() end
  elseif r.action=='tradePaste' then
    if love.system.getClipboardText then f.recipient=tostring(love.system.getClipboardText() or ''):upper():gsub('[^A-F0-9RC%-]',''):sub(1,17) end
  elseif r.action=='tradeConsent' then f.tradeConsent=not f.tradeConsent
  elseif r.action=='tradeSubmit' then W.trade(self,'submit')
  elseif r.action=='tradeRefresh' then W.trade(self,'profile')
  elseif r.action=='tradeReply' then f.replying=r.exchange;f.mode='trade';f.tradeChoose=true;f.tradeConsent=false
  elseif r.action=='tradeConfirm' then W.trade(self,'confirm',r.exchange)
  elseif r.action=='tradeReceive' then W.trade(self,'receive',r.exchange)
  elseif r.action=='tradeCancel' then W.trade(self,'cancel',r.exchange)
  else return false end
  return true
end
function P.animation(self,f,x,y,w,h,s)
  if not f.animation then return end
  local a=f.animation;local g=love.graphics;local p=math.min(1,a.elapsed/3.6)
  g.setColor(.025,.075,.16,.97);g.rectangle('fill',x,y,w,h,14*s,14*s)
  local cx,cy=x+w/2,y+h*.46;local radius=math.min(w*.2,h*.25)
  for i=1,28 do
    local angle=i*math.pi*2/28+p*math.pi*5
    local k=.4+math.sin(math.pi*p)*.6
    g.setColor(.2,.8,1,.25+.5*k);g.circle('fill',cx+math.cos(angle)*radius*1.6,cy+math.sin(angle)*radius*.65,2*s+i%3*s)
  end
  for i,direction in ipairs({-1,1}) do
    local t=p*math.pi*2+(i-1)*math.pi;local bx=cx+math.cos(t)*radius;local by=cy+math.sin(t)*radius*.28
    g.setColor(i==1 and .28 or .7,i==1 and .8 or .4,1,1);g.circle('fill',bx,by,23*s)
    g.setColor(.93,1,1,1);g.circle('line',bx,by,30*s)
    g.setColor(.07,.18,.28,1);g.rectangle('fill',bx-22*s,by-2*s,44*s,4*s)
    g.setColor(1,1,1,1);g.circle('fill',bx,by,5*s)
  end
  g.setFont(self.stateFont or self.hintFont);g.setColor(.75,.94,1,1)
  g.printf(p<.8 and 'LINK ESTABLISHED · EXCHANGING BANK COPIES' or 'NEW COMPANION RECEIVED',x+20*s,y+h*.72,w-40*s,'center')
  g.setFont(self.hintFont);g.printf('From '..tostring(a.partner or 'Wonder Trade')..' · Original saves preserved',x+20*s,y+h*.84,w-40*s,'center')
end
return P
