-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit');local V=require('src.core.GameVersion')
local Assets=require('src.import.Gen3EmeraldMainMenuAssets')
local Menu=require('src.ui.Gen3EmeraldMainMenu');local Fs=require('src.import.CacheFs')
local Serialize=require('src.core.SaveSerializer');local Writer=require('src.import.LuaWriter')
local oldVersion,oldLoad,oldRead=V.get(),love.filesystem.load,Fs.read
love.filesystem.load=loadfile;V.set('emerald')
local load=require('compat.gen1-rs.Loader').new('emerald')
local S=load('src.import.gba.syms').of('emerald');local memory={};local n=0
-- Original symbol bounds drive reads; all bytes below are owned fixtures.
for _,name in ipairs{'gText_MainMenuNewGame','gText_MainMenuContinue','gText_MainMenuOption',
 'gText_MainMenuMysteryGift','gText_MainMenuMysteryGift2','gText_MainMenuMysteryEvents','gText_MenuExit',
 'gText_ContinueMenuPlayer','gText_ContinueMenuTime','gText_ContinueMenuPokedex','gText_ContinueMenuBadges',
 'gText_SaveFileErased','gText_SaveFileCorrupted','gText_BatteryRunDry',
 'gText_MysteryEventsCantUse','gText_WirelessNotConnected'}do
 n=n+1;local at=assert(S.off(name));memory[at]=0xBB+n;memory[at+1]=255
end
local x={version='emerald',_constants={},beginStage=function()end,
 rom={u8=function(_,at)return assert(memory[at],'Unexpected fixture read '..at)end}}
Assets.extract(x);local spec=x._constants.gen3EmeraldMainMenu
T.eq(Assets.valid(spec,'emerald'),true,'real native symbol reads produce a valid menu')
T.eq(Assets.valid(spec,'ruby'),false,'edition isolation')
Fs.read=function()return Writer.encode(x._constants)end
T.eq(#Assets.missing(),0,'complete imported labels')
local count=0
for key,value in pairs(spec.textIR)do
 count=count+1;spec.textIR[key]=nil;T.eq(Assets.valid(spec,'emerald'),false,'required label '..key)
 T.eq(Assets.missing()[1],'<emerald:native-main-menu>','aggregate readiness rejects missing label')
 spec.textIR[key]=value
end
T.eq(count,16,'complete common menu and error labels')
for _,raw in ipairs{'invalid Lua','return true','return {}'}do
 Fs.read=function()return raw end;T.eq(#Assets.missing(),1,'malformed cache safely rejected')
end
local C=load('src.core.game3.constants.emerald.flags').byName
local vars=load('src.core.game3.constants.emerald.vars').byName
local game={data={constants={gen3EmeraldMainMenu=spec,gen3HoennDex={numbers={TREECKO=1,PIKACHU=156}}},
 pokemon={TREECKO={index=277,dex=252},PIKACHU={index=25,dex=25},MEWTWO={index=150,dex=150}}},
 save={version='emerald',player={name='CUSTOM',gender='girl'},options={gen3Frame=20},
 playTime={hours=123,minutes=45,seconds=6},gen3Vars={},flags={},
 pokedex={owned={TREECKO=true,PIKACHU=true,MEWTWO=true},caught={[277]=true}},
 modData={cartImport={dexOwned={252}}}}}
local save=game.save
local function flag(id,on)save.flags[('FLAG_G3_%04X'):format(id)]=on end
flag(C.FLAG_BADGE01_GET,true);flag(C.FLAG_SYS_POKEDEX_GET,true)
local before=Serialize.encode(save);local info=Menu.snapshot(game,save)
T.eq(info.name,'CUSTOM');T.eq(info.gender,1);T.eq(info.hours,123);T.eq(info.minutes,45)
T.eq(info.frameType,19);T.eq(info.badges,1);T.eq(info.dexCount,2,'regional dedup across native and imported keys')
T.eq(info.hasDex,true);T.eq(Serialize.encode(save),before,'snapshot is read-only')
save.nationalDex=true;flag(C.FLAG_SYS_NATIONAL_DEX,true)
T.eq(Menu.snapshot(game,save).dexCount,2,'national flag alone is insufficient')
save.gen3Vars[vars.VAR_NATIONAL_DEX]=0x302
T.eq(Menu.snapshot(game,save).dexCount,3,'national gating uses Emerald constants')
save.pokedex.nationalMagic=0;T.eq(Menu.snapshot(game,save).dexCount,2,'invalid magic blocks national dex')
flag(C.FLAG_SYS_POKEDEX_GET,false);T.eq(Menu.snapshot(game,save).hasDex,false)
save.flags[C.FLAG_SYS_POKEDEX_GET]=1;T.eq(Menu.snapshot(game,save).hasDex,true,'numeric import flag')
T.eq(Menu.snapshot(game,nil),nil)
local stock={{key='newGame',label='NEW GAME'},{key='option',label='OPTION'},{key='exit',label='EXIT GAME'}}
local owner={game=game,items=stock};T.eq(Menu.available(owner),true)
owner.items={stock[1],stock[2],stock[3],{key='custom',label='CUSTOM'}}
T.eq(Menu.available(owner),false,'custom row preserved by host fallback')
owner.items={stock[1],stock[2],stock[3],stock[3]};T.eq(Menu.available(owner),false,'duplicate row fallback')
owner.items={{key='newGame',label='RENAMED'},stock[2],stock[3]};T.eq(Menu.available(owner),false,'mod labels fallback')
owner.items={{key='newGame',label='NEW GAME',onSelect=function()end},stock[2],stock[3]}
T.eq(Menu.available(owner),false,'custom callback fallback')
for _,version in ipairs{'ruby','sapphire','firered','leafgreen','gold'}do
 V.set(version);owner.items=stock;T.eq(Menu.available(owner),false,'other editions unchanged')
end
-- Exercise geometry from the exact original module, without a renderer stub verdict.
local bindings={};for _,name in ipairs{'src.ui.game3.rse.scene_kit','src.core.game3.rtc',
 'src.core.game3.rom_text','src.ui.game3.frlg_font','src.core.game3.constants','src.core.game3.pal_fade',
 'src.ui.game3.stack','src.ui.game3.screens','src.render.PixelCanvas'}do bindings[name]={}end
local native=require('compat.gen1-rs.Loader').new('emerald',bindings)('src.ui.game3.rse.main_menu_rse')
local t=native.TYPE
T.eq(#native.items(t.HAS_NO_SAVED_GAME),3);T.eq(#native.items(t.HAS_SAVED_GAME),4)
for i,top in ipairs{1,9,13,17}do
 local w=native.windowFor(t.HAS_SAVED_GAME,i)
 T.eq(w.left,2);T.eq(w.width,26);T.eq(w.top,top);T.eq(w.height,i==1 and 6 or 2)
end
local frame
local adapter=setmetatable({scene={},load=function()return{setFrameType=function(f)frame=f end}end},Menu)
adapter:setFrame(19);T.eq(frame,19);T.eq(adapter.scene.frameType,19,'options-return frame belongs to original menu too')
-- The original scene-kit indexes named effects directly, while other
-- consumers use resolve(). Both must reach the same original numeric ID.
V.set('emerald');local newCanvas=love.graphics.newCanvas
love.graphics.newCanvas=function()return{setFilter=function()end}end
local played={};local songs={SE_SELECT=5,SE_SAVE=55,SE_APPLAUSE=56}
game.data.constants.gen3EmeraldCredits={fonts='owned-fixture/'}
game.data.constants.gen3EmeraldPresentation={songIds=songs}
local context=require('src.ui.Gen3EmeraldSceneContext').new(game,{textIR={},bindings={
 ['src.core.game3.audio']={playSe=function(id)played[#played+1]=id end}}})
local se=context.load('src.core.game3.se_ids')
local kit=context.load('src.ui.game3.rse.scene_kit')
for _,name in ipairs{'SE_SELECT','SE_SAVE','SE_APPLAUSE'}do
 kit.playSe(name);T.eq(played[#played],songs[name],'original named effect reaches native ID')
 T.eq(se.resolve(name),songs[name]);T.eq(se.resolve(songs[name]),songs[name])
end
T.eq(#played,3,'one call per original effect')
love.graphics.newCanvas=newCanvas
Fs.read,love.filesystem.load=oldRead,oldLoad;V.set(oldVersion)
T.finish('Emerald original main menu labels, save view, native geometry and mod fallback')
