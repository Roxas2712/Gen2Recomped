-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Real ROM reader/2bpp decoder; only the image device/encoder is captured.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local E=require('src.import.RomExtractorGen2');local Rom=require('src.import.Rom')
local A=require('src.import.Gen2TownMapAssets');local Importer=require('src.import.RomImporter')
local originalImage=love.image;love.image=love.image or{}
local originalNew=love.image.newImageData
love.image.newImageData=function(w,h)
 local image={w=w,h=h,pixels={}}
 function image:setPixel(x,y,r,g,b,a)self.pixels[y*self.w+x]={r,g,b,a}end
 function image:getPixel(x,y)return unpack(self.pixels[y*self.w+x])end
 function image:getDimensions()return self.w,self.h end
 return image
end
local raw={}
for y=0,7 do
 local lo,hi=0,0
 for x=0,7 do local shade=(x+2*y)%4
  lo=lo+shade%2*2^(7-x);hi=hi+math.floor(shade/2)*2^(7-x)
 end
 raw[#raw+1]=string.char(lo,hi)
end
raw=table.concat(raw)
for _,edition in ipairs{'gold','silver','crystal','prism','polishedcrystal'}do
 local saved={}
 local e=setmetatable({version=edition,manifest={layout={}},
  symbols={PokedexNestIconGFX={1,0x4000}},rom=Rom.new(string.rep('\0',0x4000)..raw..string.rep('\255',64))},E)
 function e:saveImage(image,path)saved[path]=image end
 -- Isolate surrounding map/sprite materialization; nest bytes/decoding run
 -- through the real extractor and strict dimension checks in ImageWriter.
 function e:gen2Landmarks()return{}end
 function e:gen2TownMapImage(_,path)return'assets/generated/'..path end
 function e:gen2Lz()return nil end
 local town=e:gen2TownMap();T.eq(town.nest.path,'assets/generated/ui/town_map_nest.png')
 local image=assert(saved['ui/town_map_nest.png'])
 T.eq(image.w,8);T.eq(image.h,8)
 for y=0,7 do for x=0,7 do
  local shade=(x+2*y)%4;local p=image.pixels[y*8+x]
  T.check(math.abs(p[1]-(1-shade/3))<1e-9,'raw tile luminance '..edition)
  T.eq(p[2],p[1]);T.eq(p[3],p[1]);T.eq(p[4],shade==0 and 0 or 1,'source transparent index')
 end end
 local marker=Importer.cacheContract(edition).marker
 T.check(marker:find('gen2%-townmap%-assets%-v1:')~=nil,'existing GSC generated cache is rebuilt for corrected asset')
 e.symbols={};saved={};T.eq(A.nest(e),nil,'unknown optional symbol does not invent another cursor tile')
 T.eq(next(saved),nil,'missing optional symbol creates no image')
 e.symbols.PokedexNestIconGFX={1,0x4000};e.rom=Rom.new(string.rep('\0',0x4000)..raw:sub(1,15))
 T.eq(A.nest(e),nil,'truncated raw tile rejected without zero-padding')
end
for _,edition in ipairs{'red','firered','emerald','platinum'}do
 T.check(not Importer.cacheContract(edition).marker:find('gen2%-townmap%-assets%-v'),'other-generation import markers retain their existing contract')
end
love.image.newImageData=originalNew;love.image=originalImage
T.finish('actual GSC nest-symbol import, transparent pixels and cache revision')
