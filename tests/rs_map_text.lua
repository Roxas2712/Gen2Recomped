love=require('tests.love_stub');love.filesystem.load=loadfile
local function read(p)local f=assert(io.open(p,'rb'));local b=f:read('*a');f:close();return b end
local edition=assert(arg[1]);local bytes=read(assert(arg[2]))
local manifest=require('src.link.Json').decode(read('tools/rom_manifest_'..edition..'.json'))
local x=require('src.import.RomExtractorGen3').new(bytes,edition,manifest)
x._maps={town={regionMapSection=0},route={regionMapSection=16}}
local writes=0;x.write=function(_,name)assert(name=='constants');writes=writes+1 end
x:extractMapSections();assert(writes==1)
local c=x._constants
assert(c.gen3MapSections[0]=='LITTLEROOT TOWN'and c.gen3MapSections[16]=='ROUTE 101')
local r=c.gen3MapSectionRects[0];assert(r.x==4 and r.y==11 and r.w==1 and r.h==1)
assert(c.gen3RegionMapGrid.width==28 and c.gen3RegionMapGrid.height==15 and #c.gen3RegionMapLayout.cells==420)
assert(c.gen3RegionMapLayout.cursorX==1 and c.gen3RegionMapLayout.cursorY==2 and c.gen3RegionMapLayout.none==88)
local count=0;for i=0,87 do assert(type(c.gen3MapSections[i])=='string');count=count+1 end
assert(count==88 and c.gen3RegionMapPlaces[0]and c.gen3RegionMapPlaces[16])
local S=require('compat.gen1-rs.Loader').new(edition)('src.import.gba.syms').of(edition)
local Data=require('src.import.Gen3RsMapData')
local route=Data.header(x,S.off('Route101'),{})
assert(route.showMapName and route.allowRunning and route.allowCycling and not route.allowEscaping)
local cave=Data.header(x,S.off('CaveOfOrigin_B4F'),{})
assert(not cave.allowCycling and cave.allowEscaping and cave.allowRunning)
local gate=Data.header(x,S.off('Route110_SeasideCyclingRoadSouthEntrance'),{})
assert(gate.allowCycling and not gate.allowRunning and not gate.allowEscaping)
print('PASS_RS_MAP_ROM '..edition)
