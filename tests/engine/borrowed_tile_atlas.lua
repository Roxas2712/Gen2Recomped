-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
local T=require('tests.harness')
love=require('tests.love_stub')
require('src.core.GameVersion').set('red')
local Tiles=require('src.render.TileRenderer')
local Palette=require('src.render.PaletteFX')
Palette.usesGbcPack=function()return false end
Palette.usesGen2BgPal=function()return false end
local function image()
 local im={reads=0,releases=0}
 function im:getDimensions()
  assert(not self.dead,'released graphics object');self.reads=self.reads+1;return 16,16
 end
 function im:release()self.dead=true;self.releases=self.releases+1 end
 return im
end
local native=image()
Tiles.atlasImage=function()return native end
local block={};for i=1,16 do block[i]=0 end
local map={id='ATLAS_LIFETIME',def={width=2,height=2},
 tileset={id='CUSTOM',image='fixture.png',tilesPerRow=2,blocks={block},animatedTiles={}},
 tileAt=function()return 0 end,blockAt=function()return 0 end}
local draws={}
love.graphics.draw=function(im)assert(not im.dead,'draw used a released image');draws[#draws+1]=im end
local redraws={}
Palette.markSpriteRedraw=function(im)assert(not im.dead);redraws[#redraws+1]=im end
for _,path in ipairs({'raw','late','window'})do
 local r=Tiles.new(map)
 T.eq(r.nativeAtlasImage,native,'constructor retains the original native atlas')
 r:ensureWindow(0,0,16,16)
 local batch=r.winBatch
 local reads=native.reads
 r:restoreNativeAtlas()
 T.eq(native.reads,reads,'ordinary native rendering needs no liveness probe')
 local borrowed=image();r.image=borrowed;r.gbcAtlas=true;r.trueColor=true
 r:drawCellBottomRaw(0,0,0,0)
 T.eq(draws[#draws],borrowed,'valid replacement remains authoritative')
 T.eq(r.image,borrowed)
 batch:setTexture(borrowed)
 borrowed:release()
 if path=='raw'then r:drawCellBottomRaw(0,0,0,0)
 elseif path=='late'then r:markCellBottomRedraw(0,0,0,0,{})
 else r:ensureWindow(0,0,16,16)end
 T.eq(r.image,native,path..' recovers the native atlas after foreign retirement')
 T.eq(r.gbcAtlas,nil,'borrowed color-format flags are restored')
 T.eq(r.trueColor,nil)
 T.eq(batch:getTexture(),native,'existing window batch is rebound')
 if path~='window'then T.eq(r.win,nil,'window bounds must be refilled')end
 r:ensureWindow(0,0,16,16)
 T.check(r.win~=nil and batch:getCount()>0,'the native window is usable again')
 r:release()
 T.eq(native.releases,0,'shared native atlas is not owned by the map')
 T.eq(borrowed.releases,1,'native eviction does not release a borrowed texture')
end
local r=Tiles.new(map);local foreign=image()
r.image=foreign;r.gbcAtlas=true
r:release()
T.eq(foreign.releases,0,'a live borrowed GBC atlas stays with its external owner')
T.eq(native.releases,0,'borrowed metadata cannot transfer native ownership')
-- A native per-map bake remains owned even when a replacement changes the
-- published format flags. Substitute only the bake producer in this fixture.
local owned=image()
local slot,producer
for i=1,100 do
 local name,value=debug.getupvalue(Tiles.new,i)
 if name=='getGbcAtlas'then slot,producer=i,value;break end
 if not name then break end
end
assert(slot)
debug.setupvalue(Tiles.new,slot,function()return owned end)
Palette.usesGbcPack=function()return true end
Palette.hasWorldTileset=function()return true end
Palette.worldGroupColors=function()return nil end
local baked=Tiles.new(map,{})
T.eq(baked.nativeAtlasImage,owned,'constructor retains its own palette bake')
local replacement=image();baked.image=replacement;baked.gbcAtlas=false
baked:release();baked:release()
T.eq(owned.releases,1,'owned bake is retired exactly once independently of public flags')
T.eq(replacement.releases,0,'foreign replacement is never retired by native eviction')
debug.setupvalue(Tiles.new,slot,producer)
T.finish('native tile atlas survives presentation retirement')
