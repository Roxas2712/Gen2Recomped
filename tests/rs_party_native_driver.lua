return function(game)
  io.stdout:setvbuf('no')
  local U=require('tests.drivers.util');local J=require('src.link.Json')
  local Serialize=require('src.core.SaveSerializer');local Pokemon=require('src.pokemon.Pokemon')
  local Menu=require('src.ui.Gen3PartyMenu');local Assets=require('src.render.Assets')
  local edition=require('src.core.GameVersion').get()
  local identity=love.filesystem.getIdentity()
  assert(identity:match('^oasc%-rs%-bag%-qa%-')or identity:match('^oasc%-edition%-qa%-'..edition..'%-'))
  assert(game.data.constants.gen3RsParty.version==edition)
  assert(require('src.import.RomImporter').readyReport(edition).ok)
  local out=assert(os.getenv('RS_UI_QA_OUT')or os.getenv('EDITION_QA_OUT'))
  local report={edition=edition,status='running',captures={},fullStory=false}
  local function persist()local f=assert(io.open(out..'/result.json','w'));f:write(J.encode(report));f:close()end
  persist()
  -- Compare every cached icon against the independently sized native tables.
  local f=assert(io.open(assert(os.getenv('POKEPORT_IMPORT_ROM')),'rb'));local raw=f:read('*a');f:close()
  local metadata=J.decode(assert(love.filesystem.read('tools/rom_manifest_'..edition..'.json')))
  local x=require('src.import.RomExtractorGen3').new(raw,edition,metadata)
  local S=require('compat.gen1-rs.Loader').new(edition)('src.import.gba.syms').of(edition)
  local tableAt,indexAt,palAt=S.off('gMonIconTable'),S.off('gMonIconPaletteIndices'),S.off('gMonIconPaletteTable')
  local function expectedIcon(i,nativeRound)
    local which=x.rom:u8(indexAt+i)
    local start=assert(x.rom:pointer(palAt+which*8))
    local palette=require('src.import.RomGba').palette(x.rom:bytes(start,32))
    if nativeRound then for color=0,15 do
      local word=x.rom:u16(start+color*2)
      palette[color+1]={math.floor(word%32*255/31+.5),math.floor(math.floor(word/32)%32*255/31+.5),math.floor(math.floor(word/1024)%32*255/31+.5)}
    end end
    return x:iconImage(assert(x.rom:pointer(tableAt+i*4)),palette,0)
  end
  local count=0
  for id,entry in pairs(game.data.icons.bySpecies)do
    local expected=expectedIcon(assert(game.data.pokemon[id]).index)
    local actual=love.image.newImageData(Assets.resolve(entry.image))
    assert(expected:getString()==actual:getString(),'Wrong native RS icon '..id);count=count+1
  end
  assert(count>=386);report.ordinaryIconPixelChecks=count
  local chunk=assert(love.filesystem.load('data/generated/gba/rse/party_extras/manifest.lua'));setfenv(chunk,{})
  local extras=chunk()
  local function visiblePixelsEqual(a,b)
    local left,right=a:getString(),b:getString();if #left~=#right then return false end
    for pixel=1,#left,4 do
      if left:byte(pixel+3)~=right:byte(pixel+3)then return false end
      if left:byte(pixel+3)~=0 and left:sub(pixel,pixel+2)~=right:sub(pixel,pixel+2)then return false end
    end
    return true
  end
  for i=412,439 do
    local actual=love.image.newImageData(Assets.resolve(extras.icons[i]))
    assert(visiblePixelsEqual(expectedIcon(i,true),actual),'Wrong egg/Unown icon '..i)
  end
  report.extraIconPixelChecks=28;persist()
  U.teleport(game,'MAP_G00_N16',10,12,'up');local world=game.stack:top()
  local main=Pokemon.new(game.data,'TREECKO',20);main.nickname='TREECKOTREE';main.item='ORAN_BERRY'
  main.moves={{id='SURF',pp=3,ppUps=2},{id='TACKLE',pp=11,ppUps=1}}
  local egg=Pokemon.new(game.data,'TORCHIC',5);egg.isEgg=true
  local wet=Pokemon.new(game.data,'MUDKIP',17);wet.status='PAR'
  for id,d in pairs(game.data.items)do if d.index==121 then wet.item=id;break end end;assert(wet.item)
  local faint=Pokemon.new(game.data,'POOCHYENA',15);faint.hp=0
  local low=Pokemon.new(game.data,'RALTS',15);low.hp=math.max(1,math.floor(low.stats.hp/5))
  local unown=Pokemon.new(game.data,'UNOWN',15);unown.personality=27
  local full={main,egg,wet,faint,low,unown};game.save.party=full
  local screen
  local function press(key,wait)
    game.input:overlayPressed(key);U.wait(1);game.input:overlayReleased(key);U.wait(wait or 1)
  end
  local function immutable()
    local saved=Serialize.encode(game.save);local rng=love.math.getRandomState()
    love.graphics.push('all');local ok,why=pcall(screen.draw,screen);love.graphics.pop();assert(ok,why)
    assert(Serialize.encode(game.save)==saved,'Party drawing changed save data')
    assert(love.math.getRandomState()==rng,'Party drawing consumed gameplay RNG')
  end
  local function shot(name)
    immutable();assert(U.shot(game,out..'/'..name..'.png'));report.captures[#report.captures+1]=name;persist()
  end
  local function open(opts)
    screen=Menu.new(game,opts or {});assert(screen.rsNative);game.stack:push(screen);U.wait(35)
    assert(screen.rsNative.chrome.inputAllowed(),'Native party fade did not finish')
  end
  local function close()press('b');assert(game.stack:top()==world,'Party did not return to world')end
  open();shot('full-party')
  for i=2,6 do press('down');assert(screen.index==i);shot('selected-'..i)end
  press('down');assert(screen.index==7);shot('cancel')
  press('down');assert(screen.index==1)
  press('a');assert(screen.submenu[1].move=='SURF' and screen.submenu[2].action=='summary');shot('field-actions')
  press('down');press('a',35)
  local summary=game.stack:top();assert(summary.rsNative,'Party did not open native summary')
  press('down',40);assert(summary.mon==egg)
  press('b',90);assert(game.stack:top()==screen and screen.index==2,'Summary return lost selected party slot');shot('summary-return')
  press('a');assert(#screen.submenu==3 and screen.submenu[1].action=='summary');shot('egg-actions')
  press('b');press('up');press('a');press('down');press('down')
  assert(screen.submenu[screen.subIndex].action=='switchOrder');press('a')
  assert(screen.switchFrom==1);shot('switch-origin')
  press('down');press('down');assert(screen.index==3);shot('switch-target')
  press('a');assert(full[3]==main and full[1]==wet and not screen.switchFrom)
  assert(main.moves[1].id=='SURF' and main.moves[1].ppUps==2);shot('after-switch')
  screen.index=3;press('a')
  for i,row in ipairs(screen.submenu)do if row.action=='item' then screen.subIndex=i end end
  local parent=screen.subIndex;press('a');shot('item-actions')
  press('up');assert(screen.subIndex==1)
  press('down');press('down');press('down');assert(screen.subIndex==3)
  press('b');assert(screen.subIndex==parent and screen.submenu[parent].action=='item')
  press('a');screen.subIndex=3;press('a');assert(screen.submenu[parent].action=='item');press('b')
  local berryCount=game.save.inventory.ORAN_BERRY or 0
  press('a');for i,row in ipairs(screen.submenu)do if row.action=='item'then screen.subIndex=i end end
  press('a');press('down');press('a',90)
  assert(main.item==nil and game.save.inventory.ORAN_BERRY==berryCount+1,'TAKE lost its host inventory callback')
  for _=1,4 do if game.stack:top()~=screen then press('a',30)end end
  assert(game.stack:top()==screen);shot('item-taken')
  press('a');for i,row in ipairs(screen.submenu)do if row.action=='item'then screen.subIndex=i end end
  press('a');press('a',30)
  assert(game.stack:top().rs,'GIVE did not open native host bag');shot('give-bag')
  press('b');assert(game.stack:top()==screen and main.item==nil)
  local old=math.max(1,main.hp-12);local done=0;main.hp=main.stats.hp
  screen:animateTo(main,old,function()done=done+1 end)
  U.wait(5);assert(screen.heal and screen.heal.shown>old);shot('hp-medicine')
  U.wait(110);assert(not screen.heal and done==1);shot('hp-medicine-complete');close()
  game.save.party={main};open();shot('one-member');press('down');assert(screen.index==2);shot('one-member-cancel');close()
  game.save.party={};open();shot('empty-party');close()
  game.save.party=full;open({tmhm={move='SURF'}});shot('tm-learnability');close()
  local picked
  open({battle={},pickOnly=true,onSwitch=function(mon)picked=mon end});shot('battle-target')
  screen.index=3;press('a');assert(picked==main and game.stack:top()==world)
  open({battle={},onSwitch=function(mon)picked=mon end});press('a');shot('battle-actions')
  assert(screen.submenu[1].action=='switch' and screen.submenu[2].action=='summary');press('b');close()
  open({battle={isDouble=function()return true end}})
  assert(screen.rsNative.ui._nativeLayout==1);shot('double-party')
  press('right');assert(screen.index==3);shot('double-right')
  press('down');press('left');assert(screen.index==1);press('right');assert(screen.index==4);close()
  local order
  open({chooseOrder={least=1,most=3},onOrder=function(slots)order=slots end});shot('order-eligible')
  assert(screen.rsNative:description(2).nativeRsDescriptor==0x7E and screen.rsNative:description(4).nativeRsDescriptor==0x7E)
  assert(screen:orderActionsFor(2)[1].action=='summary','Egg incorrectly offers team entry')
  press('a');press('a');assert(screen.order[1]==1);shot('order-first')
  assert(screen.rsNative:description(1).nativeRsDescriptor==0x1C,'Chosen member was treated as its own duplicate')
  press('start');assert(screen.index==7);shot('order-confirm')
  press('a');assert(order and order[1]==1 and game.stack:top()==world)
  report.nativeParty=true;report.originalIconIdentity=true;report.nativeEggAndUnownIcons=true
  report.nativeSelection=true;report.nativeFieldActionOrder=true;report.eggActions=true
  report.hostSwitchCallback=true;report.summaryReturn=true;report.itemSubmenuClampAndReturn=true
  report.hostHpAnimation=true;report.hostBattleCallback=true;report.drawSaveAndRngImmutable=true
  report.hostItemTake=true;report.hostGiveCancel=true
  report.status='pass';persist();print('PASS_RS_PARTY_NATIVE '..edition);love.event.quit(0)
end
