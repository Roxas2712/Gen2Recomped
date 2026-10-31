-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit');local Assets=require('src.import.Gen3NativePartyAssets')
local View=require('src.ui.Gen3NativeParty');local V=require('src.core.GameVersion')
local Fs=require('src.import.CacheFs');local Writer=require('src.import.LuaWriter')
local oldRead,oldExists=Fs.read,Fs.exists
local oldLoad=love.filesystem.load;love.filesystem.load=loadfile
for _,version in ipairs{'emerald','firered','leafgreen'}do
 local load,options=Assets.context(version)
 T.eq(type(load('src.import.gba.party_chrome_extract').run),'function','extractor loads with edition-specific dependencies')
 if version~='emerald'then T.eq(type(options.keys.PARTY_MENU_BG_GFX),'number')end
end
love.filesystem.load=oldLoad
local game={data={constants={},items={CURE={type='medicine'}},pokemon={TEST={name='BULBASAUR',dex=1}}},
 save={player={name='TEST'},options={}}}
for _,version in ipairs{'emerald','firered','leafgreen'}do
 local spec={format=1,version=version,root=Assets.ROOT,textIR={},resources={}}
 for role in pairs(Assets.labels(version))do spec.textIR[role]={{op='text',text=role}}end
 local files={}
 for _,name in ipairs(Assets.files)do local path=Assets.ROOT..name;spec.resources[#spec.resources+1]=path;files[path]='fixture'end
 files['data/generated/constants.lua']=Writer.encode({gen3NativeParty=spec,gen3PartyActions=require('tests.fixtures.frlg_party_actions').record(version)})
 Fs.read=function(p)return files[p]end;Fs.exists=function(p)return files[p]~=nil end
 V.set(version);game.data.constants.gen3NativeParty=spec
 T.eq(Assets.valid(spec,version),true);T.eq(View.available(game),true);T.eq(#Assets.missing(version),0)
 local bag=setmetatable({},require('src.ui.Gen3BagMenu'));game.data.items.CURE={key='ANTIDOTE',name='Custom cure'}
 T.eq(View.retainStatus(game,nil,'CURE',bag),true,'native status target uses stable item identity')
 T.eq(View.retainStatus(game,{},'CURE',bag),false,'battle retains its own target route')
 T.eq(View.retainStatus(game,nil,'CURE',{}),false,'legacy lists do not retain a native target')
 T.eq(View.retainStatus(game,nil,'MISSING',bag),false)
 for i,path in ipairs(spec.resources)do
  spec.resources[i]='foreign';T.eq(Assets.valid(spec,version),false);spec.resources[i]=path
  files[path]=nil;T.eq(#Assets.missing(version),1);files[path]='fixture'
 end
 for role,ir in pairs(spec.textIR)do spec.textIR[role]={};T.eq(Assets.valid(spec,version),false);spec.textIR[role]=ir end
 local owner={game=game};T.eq(View.forHost(owner),true)
 for _,flag in ipairs{'battle','chooseOrder','noInput'}do owner[flag]=true;T.eq(View.forHost(owner),false);owner[flag]=nil end
 game.stack={states={{isBattleState=true},{isMenu=true}}}
 T.eq(View.forHost(owner),false,'a battle item picker is identified by its actual underlying battle')
 game.stack=nil
 for _,foreign in ipairs{'ruby','sapphire','gold'}do T.eq(Assets.valid(spec,foreign),false);T.eq(#Assets.missing(foreign),0)end
end
Fs.read,Fs.exists=oldRead,oldExists
V.set('emerald')
local texts,statuses,slots,frames,cancels={},{},{},{},{}
local font={COLOR={NORMAL={},PARTY_MALE={},PARTY_FEMALE={}},
 draw=function(text,x,y,opts)texts[#texts+1]={text=text,x=x,y=y,opts=opts}end,
 advance=function()return 6 end}
local chrome={textColors=function()return{}end,palColor=function()return 1,1,1 end,
 statusFrameFor=function(status)return status=='PAR'and 2 or status=='FNT'and 7 or 0 end,
 drawSlot=function(...)slots[#slots+1]={...}end,drawBall=function()end,drawBg=function()end,
 drawStatus=function(...)statuses[#statuses+1]={...}end,
 drawCancelButton=function(...)cancels[#cancels+1]={...}end}
local win={template=function(...)return{...}end,stdFrame=function(r)frames[#frames+1]=r end,cursorPx=function()end}
local mon={species='TEST',nickname='LONG CUSTOM NAME',level=18,hp=15,stats={hp=40},gender='male'}
game.save.party={mon};game.stack={states={},top=function(self)return self.states[#self.states]end}
local owner={game=game,index=1,party=function()return game.save.party end,drawIcon=function()end}
local view=setmetatable({owner=owner,game=game,version='emerald',font=font,chrome=chrome,window=win,
 text=function(key)return key end,quads={},images={}},View)
local Serial=require('src.core.SaveSerializer');local before=Serial.encode(game.save)
view:body();T.eq(Serial.encode(game.save),before,'native draw does not persist display aliases')
T.eq(texts[1].text,'LONG CUSTOM NAME');T.eq(texts[1].opts.maxWidth,56);T.eq(texts[1].opts.small,true)
T.same(frames[1],{1,17,21,2});T.same(cancels[1],{184,136,false});T.eq(#slots,6)
T.eq(texts[#texts].text,'choose');owner.switchFrom=1;texts={};view:body();T.eq(texts[#texts].text,'move');owner.switchFrom=nil
texts,statuses={},{};mon.status='PAR';view:member(1,mon)
T.eq(#statuses,1);T.same(statuses[1],{34,48,2})
local hasLevel=false;for _,row in ipairs(texts)do if row.text=='level18'then hasLevel=true end end
T.eq(hasLevel,false,'status replaces the native level row')
mon.status=nil;mon.hp=0;statuses={};view:member(1,mon);T.eq(statuses[1][3],7,'fainted badge precedes other ailments')
mon.hp=15;mon.gen3Pokerus=1;statuses={};view:member(1,mon);T.eq(statuses[1][3],6)
mon.gen3Pokerus=nil
mon.status=nil
for word,code in pairs{[8]=1,[128]=1,[64]=2,[7]=3,[32]=4,[16]=5,[0]=0}do
 mon.statusWord=word;T.eq(view:ailment(mon,15),code,'native imported status word')
end
mon.statusWord=nil;mon.gen3Pokerus=16;T.eq(view:ailment(mon,15),0,'cured Pokerus has no active status badge');mon.gen3Pokerus=nil
for _,version in ipairs{'firered','leafgreen'}do
 view.version=version;statuses={};mon.status='PAR';view:member(2,mon);T.same(statuses[1],{128,23,2})
end
local pages={{string.rep('W',80),'SECOND'},{'THIRD'}};pages.contBefore={{true,false},{false}}
local wrapped=view:messagePages(pages);T.eq(#wrapped[1],4);T.eq(wrapped.contBefore[1][1],true)
T.eq(wrapped.contBefore[1][2],false);T.eq(wrapped[2][1],'THIRD');T.eq(table.concat(wrapped[1]),string.rep('W',80)..'SECOND')
local Party=require('src.ui.Gen3PartyMenu');setmetatable(owner,Party);owner.keepOpen=true;owner.gbaNative=view
game.stack.states={owner};local calls=0
local box=View.message(game,'Recovered HP.',function()calls=calls+1 end)
T.eq(box.gbaPartyOwner,owner);T.eq(calls,0);T.eq(box.maxPixels,216)
owner.keepOpen=false;T.eq(View.message(game,'No held item.').gbaPartyOwner,owner,'ordinary party feedback uses the same native window')
local marker={gbaPartyOwner=owner};game.stack.states={owner,marker};texts={};frames={};view:body()
T.eq(#frames,0,'retained result owns the bottom prompt frame')
game.stack.states={};T.eq(View.message(game,'fallback'),nil)
local released=0;owner.gbaNative={exit=function()released=released+1 end};owner:exit();owner:exit()
T.eq(released,1,'popping a party releases its private native canvas once')
V.set('red');T.finish('native E/FRLG field party')
