-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Real native panels must not send staged RGB HUD tiles through the classic
-- grayscale zone path. The publisher does not own combat or its HP clock.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local Version=require('src.core.GameVersion')
local Battle=require('src.battle.BattleState')
local Pokemon=require('src.pokemon.Pokemon')
local Save=require('src.core.SaveData')
local H=require('src.render.HudTiles')
local Palette=require('src.render.PaletteFX')
local originalVersion,originalTile,originalMode=Version.get(),H.tile,Palette.mode
Palette.setMode('redpp')
for _,edition in ipairs{'gold','silver','crystal','red'}do
 Version.set(edition)
 local data=T.fixtures.fresh();require('src.render.Font').load(data)
 data.palettes=data.palettes or {palettes={},pokemon={}}
 data.palettes.palettes.GREENBAR={{255,255,255},{247,214,123},{0,189,0},{0,0,0}}
 data.palettes.palettes.EXPBAR={{255,255,255},{247,214,123},{33,140,255},{0,0,0}}
 local save=Save.newGame();save.party={Pokemon.new(data,'FIXMON_A',30)}
 local mods={exports={}}
 local b=Battle.newWild({data=data,save=save,mods=mods,stack={top=function()end}},'FIXMON_C',23)
 b.phase='menu';b.showEnemyTrainer=false;b.showPlayerBack=false;b.enemySendingOut=false
 b.sendingOut=false;b.introBalls=nil;b.introSlide=0;b.colorMode=function()return true end
 b.bgCanvas=love.graphics.newCanvas(160,144);b.waveCanvas=love.graphics.newCanvas(160,144)
 b.drawPicsLayer=function()end;b.drawTextArea=function()end
 local zones,painted,unpainted=0,0,0
 b.drawZonePass=function()zones=zones+1 end
 H.tile=function(code,_,_,_,paint)
  if code>=0x63 and code<=0x6B then
   if paint then
    painted=painted+1;T.check(type(paint.colors)=='table','RGB tile retains its actual palette')
   else unpainted=unpainted+1 end
  end
 end
 local nativeHp,mon,hp=b.player.shownHP,save.party[1],save.party[1].hp
 local function draw(staged,owned)
  mods.exports={}
  if staged then mods.exports.any_world_provider={battleStage={state=function(screen)
   T.eq(screen,b,'actual native battle identity reaches publisher')
   return {staged=true,surfaceOwned=owned}
  end}}end
  b.frame=(b.frame or 0)+Battle.BACKDROP_POLL_FRAMES+1
  zones,painted,unpainted=0,0,0
  if Version.isGen2()then b:drawPanel()else b:drawClassic()end
 end
 draw(false,false)
 T.eq(zones,1,'ordinary cartridge panel retains its native zone colour pass')
 T.check(unpainted>=12 and painted==0,'ordinary full HP bars remain grayscale before zone colour')
 draw(true,true)
 if Version.isGen2()then
  T.eq(zones,0,'staged GSC RGB panel avoids a second grayscale recolour')
  T.check(painted>=12 and unpainted==0,'actual staged native HP and EXP tiles carry their palettes')
 else
  T.eq(zones,1,'Gen1 staged panel retains its original zone protocol')
  T.check(unpainted>=12 and painted==0,'Gen1 provider does not select the GSC tile route')
 end
 draw(true,false)
 T.eq(zones,1,'publisher without surface ownership cannot replace the native colour route')
 T.check(unpainted>=12 and painted==0,'declined surface keeps native grayscale HP input')
 draw(false,false)
 T.eq(zones,1,'unloaded world provider restores the ordinary panel')
 T.eq(save.party[1],mon,'drawing retains party identity')
 T.eq(mon.hp,hp,'drawing does not change combat HP')
 T.eq(b.player.shownHP,nativeHp,'drawing does not advance the native HP clock')
end
H.tile=originalTile;Palette.setMode(originalMode);Version.set(originalVersion)
T.finish('native staged GSC RGB HUD, ordinary zone panels and provider lifetime')
