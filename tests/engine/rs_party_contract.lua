package.path='./?.lua;./?/init.lua;'..package.path
love=require('tests.love_stub')
local T=require('tests.harness')
local V=require('src.core.GameVersion');V.set('ruby')
local Fs=require('src.import.CacheFs');local Writer=require('src.import.LuaWriter')
local PartyAssets=require('src.import.Gen3RsPartyAssets')
local oldRead,oldExists=Fs.read,Fs.exists;local manifests,exists={},{}
for _,sub in ipairs({'party','menus','party_extras'})do
  local png='data/generated/gba/rse/'..sub..'/test.png'
  manifests['data/generated/gba/rse/'..sub..'/manifest.lua']=Writer.encode({layout='rs',game='ruby',files=sub=='menus' and {} or {png},
    party={cursorOptions={},fieldMoves={}},icons={},font4={widths={},count=247}})
  exists[png]=true
end
Fs.read=function(p)return manifests[p]end;Fs.exists=function(p)return exists[p]end
T.eq(#PartyAssets.missing('ruby'),0,'native party files and metadata satisfy readiness')
T.eq(#PartyAssets.missing('sapphire'),3,'another edition cannot satisfy party readiness')
exists['data/generated/gba/rse/party/test.png']=nil
T.eq(#PartyAssets.missing('ruby'),1,'missing native panel invalidates the cache')
Fs.read,Fs.exists=oldRead,oldExists
local native={layout='rs',game='ruby',monIconAnims={}}
for i=1,5 do native.monIconAnims[i]={{op='frame',tile=0,duration=5},{op='jump',target=0}}end
local menu={layout='rs',game='ruby',party={cursorOptions={'SUMMARY','SWITCH','ITEM','CANCEL','GIVE','TAKE','TAKE','MAIL','READ','CANCEL','SURF'},fieldMoves={57}}}
love.filesystem.load=function(path)
  if path=='data/generated/gba/rse/party/manifest.lua'then return function()return native end end
  if path=='data/generated/gba/rse/menus/manifest.lua'then return function()return menu end end
  return loadfile(path)
end
local text={OtherText_Summary='SUMMARY',OtherText_Switch2='SWITCH',OtherText_Item='ITEM',gOtherText_CancelNoTerminator='CANCEL',
  OtherText_Give2='GIVE',OtherText_Take2='TAKE',OtherText_Take='TAKE',OtherText_Mail='MAIL',OtherText_Read2='READ',
  OtherText_Shift='SHIFT',OtherText_SendOut='SEND OUT',OtherText_Enter2='ENTER',OtherText_NoEntry='NO ENTRY'}
local function mon(name)return {species='TEST',nickname=name,gender='male',level=12,hp=20,stats={hp=31},moves={{id='SURF',pp=3,ppUps=2}}}end
local first,egg,last=mon('FIRST'),mon('EGG'),mon('LAST');egg.isEgg=true
local game={data={pokemon={TEST={index=1,dex=1,name='TEST',tmhm={'SURF'}}},moves={SURF={index=57,name='SURF'}},
  items={BERRY={index=139,name='BERRY'},MAIL={index=121,name='MAIL',mail=true}},audio={},constants={
    gen3RsParty={format=1,version='ruby',text=text},gen3RsSummary={eggName='EGG'}}},
  save={party={first,egg,last},options={},player={name='TEST'}},input={pressed={}}}
function game.input:wasPressed(key)return self.pressed[key]end
local screen,pops,updated
game.stack={pop=function()pops=pops+1 end}
local Menu=require('src.ui.Gen3PartyMenu')
local function open(opts)
  pops=0;screen=Menu.new(game,opts or {})
  for _=1,30 do game.input.pressed={};screen:update(1/60)end
  return screen
end
local function press(key,frames)
  game.input.pressed={[key]=true};screen:update(1/60)
  for _=1,frames or 0 do game.input.pressed={};screen:update(1/60)end
end
open()
T.check(screen.rsNative~=nil,'native RS party selected from edition metadata')
T.eq(screen:actionWord('takeItem',8,'fallback'),'TAKE','item labels come from the native dictionary')
local rows=screen:fieldActionsFor(first)
T.eq(rows[1].move,'SURF','native field moves precede summary and retain stable host IDs')
T.eq(rows[2].action,'summary','native summary follows field moves')
T.eq(rows[3].action,'switchOrder','native switch uses the host reorder callback')
T.eq(#screen:fieldActionsFor(egg),3,'egg offers only summary, switch and cancel')
press('left');T.eq(screen.index,1,'left on lead is inert')
press('right');T.eq(screen.index,2,'right reaches the remembered right-column slot')
press('down');press('left');press('right');T.eq(screen.index,3,'right restores the last right-column slot')
press('down');T.eq(screen.index,4,'last member reaches native cancel')
press('down');T.eq(screen.index,1,'cancel down returns to lead')
press('up');T.eq(screen.index,4,'lead up reaches cancel')
press('up');T.eq(screen.index,3,'cancel up reaches last member')
screen.index=1;press('a');T.eq(screen.submenu[1].action,'field','confirm opens the original action order')
game.input.pressed={down=true,a=true};screen:update(1/60)
T.eq(screen.subIndex,2,'native action navigation wins over simultaneous A')
T.check(screen.submenu~=nil,'simultaneous down/A does not execute the newly selected action')
screen.subIndex=4;press('a');T.eq(screen.submenu[1].action,'give','ITEM enters host item actions')
press('up');T.eq(screen.subIndex,1,'RS item submenu clamps at the first row')
press('down');press('down');press('down');T.eq(screen.subIndex,3,'RS item submenu clamps at the last row')
press('b');T.eq(screen.subIndex,4,'item B restores its parent action cursor')
T.eq(screen.submenu[4].action,'item','item B restores parent actions')
press('a');screen.subIndex=3;press('a');T.eq(screen.submenu[4].action,'item','item CANCEL restores parent actions')
press('b');T.eq(screen.submenu,nil,'main submenu B returns to list')
screen.submenu={};press('down');T.eq(screen.submenu,nil,'empty hook-provided actions safely return to the list')
screen:runAction('switchOrder',first);screen.index=3;screen:choose()
T.eq(game.save.party[3],first,'switch reorders original host objects')
T.eq(first.moves[1].id,'SURF','switch never converts saved move IDs')
T.eq(first.moves[1].ppUps,2,'switch retains move PP Ups')
screen.switchFrom=1;press('b');T.eq(screen.switchFrom,nil,'B cancels a pending switch without closing')
T.eq(pops,0,'canceling a switch leaves the party screen open')
screen.heal={mon=first,shown=1};first.hp=10;press('down')
T.eq(screen.heal.shown,1+31/96,'host medicine animation remains authoritative')
local v=screen.rsNative.view(first);T.eq(v.maxHp,31,'native view exposes host maximum HP')
first.gen3Pokerus=1;first.statusWord=64
v=screen.rsNative.view(first);T.eq(v.pokerus,1,'imported Pokerus alias is read without persistence')
T.eq(v.status,64,'imported numeric status reaches the native status renderer')
T.eq(first.maxHp,nil,'view aliases never enter the saved Pokemon')
screen.heal=nil;press('start');T.eq(pops,1,'START closes the host party exactly once')
local selected
open({battle={},pickOnly=true,onSwitch=function(raw)selected=raw end})
screen.index=2;press('a');T.eq(selected,egg,'battle target picker receives the original object')
open({tmhm={move='SURF'}})
screen.index=1
T.eq(screen.rsNative:description(2).nativeRsDescriptor,0x9A,'egg cannot learn a machine')
T.eq(screen.rsNative:description(3).nativeRsDescriptor,0xA8,'known moves use the native LEARNED descriptor')
T.eq(screen.rsNative.chrome.hpLevel(1,100),1,'one living HP keeps a visible red tick')
T.eq(screen.rsNative.chrome.hpLevel(20,48),2,'yellow HP uses native 48-tick threshold')
T.eq(screen.rsNative.chrome.hpLevel(25,48),3,'green HP uses native 48-tick threshold')
open({battle={isDouble=function()return true end}})
T.eq(screen.rsNative.ui._nativeLayout,1,'double battles select original RS two-lead layout')
press('right');T.eq(screen.index,3,'double lead moves right to third slot')
press('left');T.eq(screen.index,1,'double third slot returns to first lead')
screen.switchFrom=1;screen.index=4;press('a')
T.eq(screen.switchFrom,nil,'confirming cancel clears a pending switch')
T.eq(pops,0,'confirming cancel while switching keeps party open')
local orderAnswer='pending'
open({chooseOrder={least=1,most=3},onOrder=function(slots)orderAnswer=slots end})
T.eq(screen.rsNative:description(2).nativeRsDescriptor,0x7E,'egg is NOT ABLE in team selection')
T.eq(screen:orderActionsFor(2)[1].action,'summary','team egg has no ENTER action')
screen.order={1}
T.eq(screen.rsNative:description(1).nativeRsDescriptor,0x1C,'chosen member remains FIRST rather than self-duplicate NOT ABLE')
local old=game.save.party[3].hp;game.save.party[3].hp=0
T.eq(screen.rsNative:description(3).nativeRsDescriptor,0x7E,'fainted member is NOT ABLE in team selection')
game.save.party[3].hp=old
native.textSettings={{{x=0,y=0,oam={{0,0}}},{x=0,y=16,oam={{0,0}}},{x=0,y=32,oam={{0,0}}}}}
native.coordinates={descriptors={{{4,0},{4,2},{4,4}}}}
T.eq(screen.rsNative:labelWidth(0,0,64),32,'long native name stops at the descriptor field')
T.eq(screen.rsNative:labelWidth(0,8,64),64,'other native text runs retain their bounds')
native.textSettings=nil;native.coordinates=nil
screen.rsEligibility=function(slot,raw)T.eq(raw,screen:party()[slot],'eligibility callback receives original host object');return 1 end
T.eq(screen.rsNative:eligible(1),true,'eligibility callback preserves native truthy return contract')
screen.rsEligibility={2};T.eq(screen.rsNative:eligible(3),true,'native eligibility slot lists are zero-based')
T.eq(screen.rsNative:eligible(1),false,'slot list excludes members not named by the caller')
screen.rsEligibility=nil
press('start');T.eq(screen.index,4,'team START selects native confirm button')
press('down');T.eq(screen.index,5,'team confirm moves down to separate cancel button')
press('up');T.eq(screen.index,4,'team cancel moves up to confirm')
press('down');press('a');T.eq(orderAnswer,nil,'team cancel returns nil through original callback')
T.eq(pops,1,'team cancel pops once')
V.set('leafgreen');T.eq(require('src.ui.Gen3RsParty').available(game),false,'LeafGreen retains its own party implementation')
T.finish('Native RS party readiness, input, item/egg/switch and host callback contracts')
