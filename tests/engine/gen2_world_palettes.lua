-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local Version=require('src.core.GameVersion');local originalVersion=Version.get()
local Game=require('src.core.Game');local originalData=Game.data
local Data=require('src.core.Data');local World=require('src.world.OverworldController')
local Palettes=require('src.render.PaletteFX');local oldMode=Palettes.mode
local originalMap=rawget(World,'map');local originalPalettes=rawget(World,'palettes')
local index=getmetatable(World).__index
local gameSlot,previousGame
for i=1,100 do
 local name,value=debug.getupvalue(index,i)
 if not name then break end
 if name=='Game'then gameSlot,previousGame=i,value;break end
end
assert(gameSlot,'native active-world Game owner missing')
debug.setupvalue(index,gameSlot,Game)
local oldDark,oldTod,oldPalette=Palettes.darkWorld(),Palettes.gen2Tod(),Palettes.gen2MapPalette()
local function rows(seed)
 local out={}
 for slot=1,8 do out[slot]={{255,255,255},{seed,slot,40},{20,30,40},{0,0,0}}end
 return out
end
local function data(day,night)
 return{tilesets={LAB={id='LAB',palColorsByTod={DAY=day,NITE=night}}}}
end
local mapDef={tileset='LAB',mapPalette=1}
rawset(World,'palettes',nil);World.map={def=mapDef}
for _,edition in ipairs{'gold','silver','crystal'}do
 Version.set(edition);Palettes.mode='gbc'
 Palettes.setDarkWorld(false);Palettes.setGen2MapPalette(1,mapDef)
 local day,night=rows(170),rows(60);Game.data=data(day,night)
 T.eq(Data.publishGen2Palettes(Game.data),true,'native data publishes a palette view')
 T.eq(World.palettes,Game.data.gen2Palettes,'world shares actual owner-bound native view')
 -- The published Gen2WorldAdapter consumer, without its private atlas/cache.
 local function paletteSet(world,map)
  if not(Palettes.bgSet and world.palettes and map and map.def)then return nil end
  return Palettes.bgSet(world.palettes,map.def,world.daytime or world.tod or 'DAY')
 end
 T.eq(paletteSet(World,World.map),day,'unchanged consumer reaches native map palette')
 T.eq(Palettes.bgSet(World.palettes,mapDef,'NITE'),night,'explicit neighbor time uses native night row')
 local updated=rows(95);Game.data.tilesets.LAB.palColorsByTod.DAY=updated
 T.eq(paletteSet(World,World.map),updated,'in-place palette edits remain live')
 local savedView=World.palettes;local fresh=rows(210)
 Game.data=data(fresh,night);Data.publishGen2Palettes(Game.data)
 T.neq(World.palettes,savedView,'dataset replacement does not retain previous view')
 T.eq(paletteSet(World,World.map),fresh,'replacement dataset reaches source consumer')
 local authored={custom=true};World.palettes=authored
 T.eq(World.palettes,authored,'explicit Gen2 mod field retains precedence')
 rawset(World,'palettes',nil)
 Game.data={tilesets={}};Data.publishGen2Palettes(Game.data)
 T.eq(World.palettes,nil,'missing native palettes never invented')
end
for _,edition in ipairs{'red','yellow','firered','emerald'}do
 Version.set(edition);Game.data={gen2Palettes={foreign=true}}
 T.eq(World.palettes,nil,'other generations do not expose stale Gen2 palette view')
end
Game.data=originalData;rawset(World,'map',originalMap);rawset(World,'palettes',originalPalettes)
debug.setupvalue(index,gameSlot,previousGame)
Palettes.setDarkWorld(oldDark);Palettes.setGen2Tod(oldTod);Palettes.setGen2MapPalette(oldPalette)
Palettes.mode=oldMode;Version.set(originalVersion)
T.finish('live native Gen2 world palette consumer')
