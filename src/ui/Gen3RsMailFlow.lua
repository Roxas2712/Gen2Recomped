-- Host callbacks and save transactions around the authored RS mail screens.
local M={}
local View=require('src.ui.Gen3RsMailView')
local function model(game)return require('src.inventory.Gen3RsMail').new(game)end
local function name(game,mon)return mon.nickname or mon.name or(game.data.pokemon[mon.species]or{}).name or''end
function M.text(game,key,vars)
  local ir=assert(game.data.constants.gen3RsMail.textIR[key],'Missing native mail label '..key)
  return require('compat.gen1-rs.reference.src.core.game3.scripting.text_ir').toAscii(ir,{stringVars=vars or{}})
end
function M.say(party,text,done)
  local game=party.game;local native=assert(party.rsNative)
  party.rsMailPrompt=nil
  local box=require('src.render.TextBox').new(game,text,done,{box={tx=4,ty=15,tw=22,th=4},
    maxPixels=176,uiWidth=240,uiHeight=160,textX=32,line1Y=120,line2Y=136,
    drawFrame=false,softWrap=false,scrollDistance=16,scrollStep=2})
  box.pages=native:machinePages(box.pages);box.shown={};box:beginLine();box.rsMachineParty=party
  box.draw=function(self)return native:drawMachineMessage(self)end
  game.stack:push(box)
end
local function ask(party,text,done)
  M.say(party,text,function()
    party.rsMailPrompt=text
    party.game.stack:push(require('src.ui.ChoiceBox').new(party.game,function(yes)
      party.rsMailPrompt=nil;done(yes)
    end,{tx=24,ty=9,tw=5,th=4}))
  end)
end
function M.give(party,mon,id,selection,onDone)
  local game=party.game;if not View.available(game)or not party.rsNative then return false end
  local mail=model(game)
  if not mail:isMail(id)and not mail:isMail(mon.item)then return false end
  local function done()if onDone then onDone()end end
  if not mail.valid or mail:isMail(mon.item)then
    M.say(party,M.text(game,'gOtherText_MailMustBeRemoved'),done);return true
  end
  if require('src.pokemon.Party').isEgg(mon)then return true end
  local index
  for i,p in ipairs(game.save.party or{})do if p==mon then index=i;break end end
  if not index then done();return true end
  local function write()
    local tx,why=mail:prepareGive(index,id,selection)
    if not tx then
      if why=='bag_full'then M.say(party,M.text(game,'gOtherText_BagFullCannotRemoveItem'),done)
      else done()end
      return
    end
    local function open()
      game.stack:push(View.new(game,{kind='composer',record=tx.record,onDone=function(accepted,words)
        if not accepted then mail:cancel(tx);done();return end
        if not mail:accept(tx,words)then done();return end
        M.say(party,M.text(game,'gOtherText_WasGivenToHold',{name(game,mon),game.data.items[id].name}),done)
      end}))
    end
    if tx.previous then
      M.say(party,M.text(game,'gOtherText_ReceivedTheThingFrom',{name(game,mon),game.data.items[tx.previous].name}),open)
    else open()end
  end
  if mon.item then
    ask(party,M.text(game,'gOtherText_AlreadyHolding',{name(game,mon),game.data.items[mon.item].name}),function(yes)
      if yes then write()else done()end
    end)
  else write()end
  return true
end
function M.giveFromBag(bag,id)
  local game=bag.game;if not View.available(game)then return false end
  local selected=bag:selected();local slot=selected and selected.rsSlot
  local picker=require('src.ui.Gen3PartyMenu').new(game,{pickOnly=true,keepOpen=true})
  picker.rsMailGive=true
  picker.onSwitch=function(mon)
    if M.give(picker,mon,id,slot,function()bag:rebuild();picker:close()end)then return end
    picker:close()
    require('src.ui.BagMenu').handOver(game,mon,id,function()bag:rebuild()end,{bagSlot=slot})
  end
  game.stack:push(picker);return true
end
function M.check(bag,id)
  local game=bag.game;if not View.available(game)then return false end
  local mail=model(game);if not mail:isMail(id)then return false end
  local record=mail.native.clear();record.itemId=mail.numbers[id];record.species=0
  game.stack:push(View.new(game,{kind='reader',record=record,hasText=false}));return true
end
function M.menu(party)
  if not View.available(party.game)or not party.rsNative then return false end
  party.submenu={
    {label=M.text(party.game,'OtherText_Read2'),action='readMail'},
    {label=M.text(party.game,'OtherText_Take'),action='takeMail'},
    {label=M.text(party.game,'gOtherText_CancelNoTerminator'),action='cancel'},
  };party.subIndex=1;return true
end
function M.read(party,mon)
  local game=party.game;local mail=model(game);local index
  for i,p in ipairs(game.save.party or{})do if p==mon then index=i end end
  local record=index and mail:readParty(index);if not record then return end
  game.stack:push(View.new(game,{kind='reader',record=record,onDone=function()
    party.submenu=party:fieldActionsFor(mon);party.subIndex=1
  end}))
end
function M.take(party,mon)
  local game=party.game;local mail=model(game);local index
  for i,p in ipairs(game.save.party or{})do if p==mon then index=i end end
  if not index then return end
  if not mail:readParty(index)then
    local item,why=require('src.inventory.Bag').takeHeld(game.save,mon,game.data)
    if item then
      M.say(party,M.text(game,'gOtherText_ReceivedTheThingFrom',{name(game,mon),game.data.items[item].name}))
    elseif why=='full'then M.say(party,M.text(game,'gOtherText_BagFullCannotRemoveItem'))end
    return
  end
  local expected=mail:fingerprint()
  local function done(key)M.say(party,M.text(game,key),function()party.submenu=nil end)end
  ask(party,M.text(game,'gOtherText_SendRemovedMailPrompt'),function(send)
    if expected~=mail:fingerprint()then return end
    if send then
      local ok=mail:store(index);done(ok and'gOtherText_MailWasSent'or'gOtherText_MailboxIsFull')
    else
      ask(party,M.text(game,'gOtherText_MailRemovedMessageLost'),function(discard)
        if not discard or expected~=mail:fingerprint()then return end
        local ok=mail:take(index);done(ok and'gOtherText_MailTaken'or'gOtherText_BagFullCannotRemoveItem')
      end)
    end
  end)
end
return M
