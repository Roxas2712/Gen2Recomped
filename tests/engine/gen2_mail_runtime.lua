-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local V=require('src.core.GameVersion')
local original=V.get()
V.set('crystal')
local data=T.fixtures.fresh()
require('src.render.Font').load(data)
data.items.ITEM_158={id='ITEM_158',key='FLOWER_MAIL',name='Letter',pocket='ITEM'}
local Mail=require('src.pokemon.Gen2Mail');Mail.load(data)
local Pokemon=require('src.pokemon.Pokemon')
local function mon()
  return Pokemon.new(data,T.fixtures.ids.species[1],5,function(lo)return lo end)
end
local game={data=data,save={},stack={states={}}}
function game.stack:push(screen)self.states[#self.states+1]=screen;if screen.enter then screen:enter()end end
function game.stack:pop()return table.remove(self.states)end
function game.stack:top()return self.states[#self.states]end
local function press(screen,key)
  game.input={wasPressed=function(_,k)return k==key end,isDown=function()return false end}
  screen:update(1/60)
end
local function reset()
  game.save={party={mon(),mon()},player={name='AUTHOR',id=17},inventory={ITEM_158=2},bagOrder={'ITEM_158'}}
  game.stack.states={{parent=true}}
end
local Compose=require('src.ui.Gen2MailCompose')
reset()
local parent=game.stack:top();local inv,order=game.save.inventory,game.save.bagOrder
local cancelled=0
local screen=Compose.new(game,{mon=game.save.party[1],item='ITEM_158',onCancel=function()cancelled=cancelled+1 end})
game.stack:push(screen);screen.text='UNSENT';press(screen,'select')
T.eq(game.stack:top(),parent,'SELECT cancels the actual keyboard')
T.eq(game.save.inventory.ITEM_158,2,'cancel does not consume stationery')
T.eq(game.save.party[1].item,nil,'cancel leaves the held item unchanged')
T.eq(game.save.mail,nil,'cancel creates no pending letter')
T.eq(cancelled,1,'cancel callback runs once')
local completed=0
screen=Compose.new(game,{mon=game.save.party[1],item='ITEM_158',onDone=function()completed=completed+1 end})
game.stack:push(screen);screen.text=string.rep('X',33)
T.eq(#screen.glyphs,32,'actual native keyboard caps the message at 32 glyphs')
press(screen,'start')
T.eq(completed,1,'START completes once')
T.eq(game.stack:top(),parent,'composition closes its own screen exactly once')
T.eq(game.save.inventory,inv,'composition preserves live inventory identity')
T.eq(game.save.bagOrder,order,'composition preserves live acquisition order identity')
T.eq(game.save.inventory.ITEM_158,1,'composition consumes one stationery')
T.eq(game.save.party[1].item,'ITEM_158','composition gives the actual native held item')
T.eq(game.save.mail.party[1].message,string.rep('X',32),'actual keyboard result becomes the native letter')
T.eq(game.save.mail.party[1].authorId,17,'composition records the real trainer ID')
local Bag=require('src.inventory.Bag')
T.eq(Bag.takeHeld(game.save,game.save.party[1],data),nil,'ordinary take cannot destroy a held letter')
T.eq(game.save.mail.party[1].message,string.rep('X',32),'refused take keeps message')
reset()
local held='PREVIOUS_ITEM';data.items[held]={id=held,name='Held item',pocket='ITEM'}
game.save.party[1].item=held;game.save.inventory[held]=99
local before=require('src.core.SaveData').encode(game.save)
T.eq(Mail.attachFromBag(game.save,1,'ITEM_158','FAIL',data),false,'full previous-item stack refuses the exchange')
T.eq(require('src.core.SaveData').encode(game.save),before,'failed exchange changes no persisted fields')
game.save.inventory[held]=98
T.check(Mail.attachFromBag(game.save,1,'ITEM_158','SWAP',data),'previous held item can return to bag')
T.eq(game.save.inventory[held],99,'previous held item is returned exactly once')
reset()
local gone=game.save.party[1]
screen=Compose.new(game,{mon=gone,item='ITEM_158'});game.stack:push(screen)
game.save.party[1]=mon();screen.text='STALE';press(screen,'start')
T.eq(game.save.inventory.ITEM_158,2,'stale keyboard target consumes no stationery')
T.eq(game.save.party[1].item,nil,'stale target cannot affect a replacement mon')
T.eq(game.save.mail,nil,'stale target creates no letter')

-- Exercise real party-menu callbacks and coroutine continuation, not a
-- substitute handler or a fabricated result variable.
local Runner=require('src.script.ScriptRunner')
local VM=require('src.script.Gen2ScriptVM')
for _,case in ipairs({
  {name='cancel',result=2}, {name='missing',result=3,pick=true},
  {name='wrong',result=0,pick=true,text='OTHER'},
  {name='last',result=4,pick=true,text='MATCH',last=true},
  {name='correct',result=1,pick=true,text='MATCH'},
})do
  reset();local carrier=game.save.party[1]
  if case.last then game.save.party[2].hp=0 end
  if case.text then carrier.item='ITEM_158';Mail.set(game.save,1,Mail.entry('ITEM_158',case.text,'R',2,carrier.species))end
  local finish=0
  local scriptData={map_scripts={scripts={probe={{'checkpokemail',{message='MATCH'}},{'end'}}}}}
  local rows=assert(VM.compile(scriptData,'probe'))
  local runner=Runner.new(game,{})
  runner:run(rows,{onDone=function()finish=finish+1 end})
  T.check(runner:isRunning(),'mail check suspends for real party input: '..case.name)
  T.eq(finish,0,'script does not continue before selection: '..case.name)
  local picker=game.stack:top()
  press(picker,case.pick and 'a' or 'b')
  T.eq(runner.ctx.g2Var,case.result,'native bytecode result: '..case.name)
  T.eq(finish,1,'script resumes once after real picker: '..case.name)
  T.eq(runner:isRunning(),false,'mail script terminates: '..case.name)
  T.eq(#game.save.party,case.result==1 and 1 or 2,'delivery changes party only for CORRECT: '..case.name)
end
reset()
local runner=Runner.new(game,{})
local rows=assert(VM.compile({map_scripts={scripts={gift={{'givepokemail',{item='ITEM_158',message='GIFT'}},{'end'}}}}},'gift'))
runner:run(rows,{g2Var=91})
T.eq(game.save.mail.party[2].message,'GIFT','compiled native gift targets the last party member')
T.eq(runner.ctx.g2Var,91,'gift does not overwrite the script result variable')

-- Binary fixtures cover the pointer width which previously desynchronised
-- Gold/Silver and ensure mail data never enters the dialogue/script queues.
local Extractor=require('src.import.RomExtractorGen2')
local Rom=require('src.import.Rom');local Ops=require('src.import.Gen2ScriptOps')
local Writer=require('src.import.LuaWriter')
for _,version in ipairs({'gold','silver','crystal'})do
  local codes={};for i,row in ipairs(Ops.commandsFor(version))do codes[row[1]]=i-1 end
  local bytes={};for i=1,0x8000 do bytes[i]=0 end
  local function put(at,values)for i,v in ipairs(values)do bytes[at+i]=v end end
  put(0x4000,{codes.givepokemail,0x00,0x41,codes.checkpokemail,0x01,0x41,codes.setval,77,codes['end']})
  put(0x4100,{158,0x80,0x4e,0x81,0x50})
  local chunks={};for i=1,#bytes,256 do chunks[#chunks+1]=string.char(unpack(bytes,i,math.min(i+255,#bytes)))end
  local extractor=setmetatable({version=version,rom=Rom.new(table.concat(chunks)),_gen2MailCharmap={['128']='A',['129']='B'}},Extractor)
  local pool={scripts={},queue={},instructions=0,desyncs=0}
  extractor:gen2DecodeScript(1,0x4000,'probe',pool)
  local decoded=pool.scripts.probe
  T.eq(#decoded,4,'word-sized mail operands retain following commands: '..version)
  T.eq(decoded[1][2].item,'ITEM_158','gift stationery resolves to native ID: '..version)
  T.eq(decoded[1][2].message,'A\nB','gift reads raw line break and terminator: '..version)
  T.eq(decoded[2][2].message,'A\nB','expected message skips no first character: '..version)
  T.eq(decoded[3][1],'setval','decoder remains aligned after both operands: '..version)
  T.eq(decoded[3][2],77,'following command retains its actual byte: '..version)
  T.eq(#pool.queue,0,'raw letters are not queued as scripts: '..version)
  T.eq(pool.desyncs,0,'native mail bytecode has no desync: '..version)
  local round=assert(loadstring(Writer.encodeSplit(pool)))()
  T.eq(round.scripts.probe[2][2].message,'A\nB','actual LuaWriter retains semantic letter data: '..version)
  T.eq(extractor:gen2MailOperand(1,0x8000,true),nil,'out-of-bank pointer is rejected: '..version)
  T.eq(extractor:gen2MailOperand(1,0x7fff,true),nil,'truncated gift cannot read across bank boundary: '..version)
end
-- Native party switches keep letters pinned to their actual carriers.
reset()
local PartyMenu=require('src.ui.PartyMenu')
local carrier=game.save.party[1];carrier.item='ITEM_158'
Mail.set(game.save,1,Mail.entry('ITEM_158','CARRIER'))
local partyScreen=PartyMenu.new(game,{})
game.stack:push(partyScreen);partyScreen.swapFrom=1;partyScreen.index=2;press(partyScreen,'a')
T.eq(game.save.party[2],carrier,'actual party screen reorders the carrier')
T.eq(game.save.mail.party[2].message,'CARRIER','actual party screen moves its letter')
T.eq(game.save.mail.party[1],nil,'actual party screen clears the old mail slot')

-- Mailbox actions use the same save and preserve entries on failed moves.
local Mailbox=require('src.ui.Gen2MailboxMenu')
reset();game.save.mail={party={},box={Mail.entry('ITEM_158','ONE','A'),Mail.entry('ITEM_158','TWO','B'),Mail.entry('ITEM_158','THREE','C')}}
local list=Mailbox.new(game);game.stack:push(list);list.index=2;press(list,'a')
local actions=game.stack:top();actions.index=2;press(actions,'a')
local picker=game.stack:top();press(picker,'a')
T.eq(game.save.mail.party[1].message,'TWO','real mailbox GIVE attaches the selected letter')
T.eq(game.save.mail.box[2].message,'THREE','real mailbox compacts after middle deletion')
T.eq(list.items[2].value,2,'display rows follow compacted native indexes')
game.stack.states={parent,list};list.index=2;press(list,'a')
actions=game.stack:top();actions.index=2;press(actions,'a')
picker=game.stack:top();press(picker,'a')
T.eq(#game.save.mail.box,2,'occupied target preserves the mailbox')
T.eq(game.save.mail.party[1].message,'TWO','failed mailbox attachment preserves held letter')
game.stack.states={parent,list};list.index=2;press(list,'a')
actions=game.stack:top();actions.index=3;press(actions,'a')
local warning=game.stack:pop();warning.choice(false)
T.eq(#game.save.mail.box,2,'declining message loss retains mailbox contents')
T.eq(game.save.inventory.ITEM_158,2,'declining message loss adds no stationery')

-- The compatibility PC's dismissal is caller-owned; its close callback may
-- pop exactly one screen, as existing Gen2 hosts do.
require('src.core.ModCompat').install()
local BoxMenu=require('src.ui.gen2.BoxMenu')
T.eq(BoxMenu,require('src.ui.BoxMenu'),'legacy Gen2 PC namespace reaches the actual native factory')
reset();parent=game.stack:top();local calls=0;local pc
pc=BoxMenu.new(game,{onClose=function()
  calls=calls+1;T.eq(game.stack:top(),pc,'PC remains on stack during caller-owned close');game.stack:pop()
end})
game.stack:push(pc);press(pc,'b')
T.eq(calls,1,'PC B invokes one close callback')
T.eq(game.stack:top(),parent,'PC does not pop the parent below its caller')
T.eq(pc.save,game.save,'native PC exposes the actual save required by Gen2 hosts')
local alternate={party={mon(),mon()}}
pc=BoxMenu.new(game,{save=alternate})
T.eq(pc.save,alternate,'alternate-save native PC uses the supplied save')
T.eq(pc.game.writeSave,false,'alternate-save native PC cannot write the live profile')

-- Unknown carriers are quarantined by the production save validator. Their
-- detached letters survive the real codec without duplicating stationery.
reset();local unknown=mon();unknown.species='REMOVED_MOD_SPECIES';unknown.item='ITEM_158'
game.save.party[2]=unknown
Mail.set(game.save,2,Mail.entry('ITEM_158','KEEP','MOD',9,unknown.species))
local Save=require('src.core.SaveData')
local report=Save.validate(game.save,data)
T.eq(game.save.mail.box[1].message,'KEEP','missing-carrier letter is retained in native mailbox')
T.eq(unknown.item,nil,'quarantined carrier cannot duplicate detached stationery')
T.eq(#report.restoredMail,1,'mail recovery is reported')
T.eq(assert(Save.decode(Save.encode(game.save))).mail.box[1].message,'KEEP','quarantined letter survives actual save encoding')
local recovered={orphaned={mail={Mail.entry('ITEM_158','RECOVER')}}}
Mail.validate(recovered,{})
T.eq(recovered.mail.box[1].message,'RECOVER','pending letters reclaim even when no live mail table exists')

local run=T.sdk.loadMods({'mods/mail_probe'},{data=data,fs=T.sdk.memfs({
  ['mods/mail_probe/manifest.json']='{"id":"mail_probe","name":"Mail probe","version":"1.0.0","api":2,"entry":"main.lua"}',
  ['mods/mail_probe/main.lua']=[[
    local mod=...
    mod.exports.reads=0;mod.exports.writes=0
    assert(mod:supports('events','mail.read'))
    assert(mod:supports('events','mail.written'))
    mod.events:on("mail.read",function(e)mod.exports.reads=mod.exports.reads+1;mod.exports.message=e.message end)
    mod.events:on("mail.written",function(e)mod.exports.writes=mod.exports.writes+1 end)
  ]],
})})
T.eq(#run.errors,0,'actual SDK mail event subscriptions load')
reset();Mail.load(data);Mail.compose(game.save,1,'PUBLIC',game.save.party[1],'ITEM_158')
Mail.lines(Mail.get(game.save,1));Mail.lines(game.save.mail.party[1])
local exports=run.loader.exports.mail_probe
T.eq(exports.writes,1,'public SDK receives the native write once')
T.eq(exports.reads,1,'public SDK receives the native read once, not every redraw')
T.eq(exports.message,'PUBLIC','public SDK receives actual letter contents')
run.release()
for _,api in ipairs({2,3})do
  local sdkData=T.fixtures.fresh()
  sdkData.items.ITEM_158={id='ITEM_158',key='FLOWER_MAIL',name='Letter',pocket='ITEM'}
  local unified=T.sdk.loadMods({'mods/mail_unified'},{data=sdkData,fs=T.sdk.memfs({
    ['mods/mail_unified/manifest.json']='{"id":"mail_unified","name":"Unified mail","version":"1.0.0","api":'..api..',"callback_format":"unified","entry":"main.lua"}',
    ['mods/mail_unified/main.lua']=[[
      local mod=...
      mod.events:on("mail.written",function(e)
        mod.exports.item=e.entry.type;mod.exports.species=e.mon.species
        e.entry.message='CHANGED';e.mon.hp=0
      end)
      mod.events:on("mail.read",function(e)mod.exports.read=e.message;e.entry.author='CHANGED' end)
    ]],
  })})
  T.eq(#unified.errors,0,'unified mail subscriptions load for API '..api)
  reset();Mail.load(data);local hp=game.save.party[1].hp
  Mail.compose(game.save,1,'UNCHANGED',game.save.party[1],'ITEM_158')
  Mail.lines(Mail.get(game.save,1))
  local got=unified.loader.exports.mail_unified
  T.eq(got.item,'LETTER','unified event translates native stationery to its public item ID for API '..api)
  T.eq(got.species,T.fixtures.ids.species[1],'unified event translates actual carrier for API '..api)
  T.eq(got.read,'UNCHANGED','unified listener receives actual read for API '..api)
  T.eq(game.save.party[1].hp,hp,'unified mail event cannot mutate actual carrier for API '..api)
  T.eq(game.save.mail.party[1].message,'UNCHANGED','unified mail event cannot mutate actual message for API '..api)
  T.eq(game.save.mail.party[1].author,'AUTHOR','unified read cannot mutate actual author for API '..api)
  unified.release()
end
local Caps=require('src.mods.Capabilities')
for _,version in ipairs({'gold','silver','crystal'})do
  T.check(Caps.supports('events','mail.read',version),'native mail read available: '..version)
  T.check(Caps.supports('events','mail.written',version),'native mail written available: '..version)
end
T.eq(Caps.supports('events','mail.read','red'),false,'Gen1 cannot claim native mail read')
T.eq(Caps.supports('events','mail.written','emerald'),false,'unimplemented Gen3 mail is not advertised')
V.set(original);Mail.load(nil)
T.finish('native GSC mail keyboard, atomic inventory exchange, actual script runner and ROM bytecode')
