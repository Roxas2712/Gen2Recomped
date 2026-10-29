-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local Version=require('src.core.GameVersion');local oldVersion=Version.get()
local World=require('src.world.OverworldController');local Assets=require('src.render.Assets')
local oldImage=Assets.image;local paths={}
Assets.image=function(path)
 paths[#paths+1]=path
 if path=='missing.png'then error('synthetic missing asset')end
 return path..':actual-image'
end
for _,edition in ipairs{'gold','silver','crystal'}do
 Version.set(edition)
 local def={id='ROOM',tileset='LAB'}
 local sheet={id='LAB',image='raw-lab.png'}
 -- Exact shape supplied by published Gen2WorldAdapter.staticWorld: a plain
 -- data table, not a live state or an object inheriting all world methods.
 local source={tilesets={LAB=sheet},atlasFor=World.atlasFor,atlasCache={}}
 local image,tileset=source:atlasFor(def)
 T.eq(image,'raw-lab.png:actual-image','title precache reads supplied native raw atlas')
 T.eq(tileset,sheet,'source consumer retains actual tileset identity')
 T.eq(getmetatable(source),nil,'no hidden world state/metatable required')
 local live={id='LAB',image='edited-live.png'}
 source.map={def=def,tileset=live}
 T.eq(source:atlasFor(def),'edited-live.png:actual-image','resident edited tileset keeps priority')
 source.map=nil;source.neighbors={{map={def=def,tileset=live}}}
 T.eq(source:atlasFor(def),'edited-live.png:actual-image','resident neighbor image keeps priority')
 source.neighbors=nil;sheet.image='changed-source.png'
 T.eq(source:atlasFor(def),'changed-source.png:actual-image','source atlas edits remain live')
 sheet.image='missing.png';T.eq(source:atlasFor(def),nil,'missing asset remains a guarded failure')
 T.eq(source:atlasFor(false),nil,'invalid map definition refused')
end
Version.set('emerald')
local def={id='GBA',tileset='GBA'};local sheet={id='GBA'}
local descriptor={bottom={},tileset={atlasUnit='cell'}}
local called
local source={tilesets={GBA=sheet},gen3WorldFor=function(self,map,resident,ts)
 called={self,map,resident,ts};return descriptor
end}
local image,tileset,world=World.atlasFor(source,def)
T.eq(called[1],source,'custom Gen3 descriptor retains actual receiver')
T.eq(called[2],def,'Gen3 descriptor receives requested map')
T.eq(called[4],sheet,'Gen3 descriptor receives supplied actual tileset')
T.eq(image,descriptor.bottom,'Gen3 bottom sheet contract retained')
T.eq(tileset,descriptor.tileset,'Gen3 tile-unit descriptor retained')
T.eq(world,descriptor,'Gen3 third return retained')
Assets.image=oldImage;Version.set(oldVersion)
T.finish('native data-only Gen2 atlas source consumer')
