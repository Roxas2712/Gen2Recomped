package.path='./?.lua;./?/init.lua;'..package.path
love=require('tests.love_stub')
love.data={hash=function(_,bytes)return bytes end,encode=function(_,_,bytes)return require('src.link.Fingerprint').digest(bytes):rep(4)end}
local T=require('tests.harness')
package.loaded['src.core.Game']={data={maps={}}}
local V=require('src.core.GameVersion');V.set('red')
local M=require('src.world.FriendMap')
local function world()
 local map={id='PALLET_TOWN',def={width=2,height=2,warps={{x=1,y=1,map='HOUSE',warp=1}}},widthCells=4,heightCells=4,tileset={blockCells=2},gridRevision=1}
 map.isWalkableCell=function(self,x,y)return not (self.wall and x==1 and y==1)end
 map.isWaterCell=function()return false end
 map.cellTile=function()return 1 end
 return {map=map}
end
local a,b=world(),world()
local one=M.describe(a);b.map.def.art='different.png';V.set('blue')
T.check(M.same(one,M.describe(b)),'different cartridge art does not split identical native navigation')
b.map.wall=true;b.map.gridRevision=2
T.check(not M.same(one,M.describe(b)),'changed passability invalidates the cached signature and hides visitors')
b=world();b.map.def.warps[1].map='OTHER'
T.check(not M.same(one,M.describe(b)),'different exits cannot share navigation')
b=world();b.map.widthCells=5
T.check(not M.same(one,M.describe(b)),'different coordinate systems cannot share visitors')
T.check(not M.same(one,nil),'unqualified maps fail closed')
T.finish('Friend map compatibility')
