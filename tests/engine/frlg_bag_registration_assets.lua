-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit');local M=require('src.import.Gen3BagRegistrationAssets')
local Writer=require('src.import.LuaWriter');local Fs=require('src.import.CacheFs')
local Image=require('src.import.ImageWriter');local V=require('src.core.GameVersion')
local loadFile=love.filesystem.load;love.filesystem.load=loadfile
local blank,read,exists=Image.blank,Fs.read,Fs.exists
local addresses={}
for _,version in ipairs{'firered','leafgreen'}do
  local gfx,pal,load=M.addresses(version);addresses[version]={gfx,pal}
  local K=load('src.import.gba.rse.boot_gfx')
  local bytes={};for n=0,191 do bytes[#bytes+1]=string.char((n*37)%256)end
  local raw=table.concat(bytes);local expected=K.bakeSprite(raw,24,16,0,4)
  local function word(index)return index+(15-index)*32+((index*2)%32)*1024 end
  local pixels={};local saved,constants
  Image.blank=function(w,h)
    T.eq(w,24);T.eq(h,16)
    return{setPixel=function(_,x,y,r,g,b,a)pixels[y*24+x+1]={r,g,b,a}end}
  end
  local x={version=version,_constants={gen3BagScreen={layout='frlg'},untouched='KEEP'},rom={}}
  x.rom.u8=function(_,at)
    assert(at>=gfx and at<gfx+192,'Read outside own bitmap')
    return raw:byte(at-gfx+1)
  end
  x.rom.u16=function(_,at)
    assert(at>=pal and at<pal+32 and(at-pal)%2==0,'Read outside own window palette')
    return word((at-pal)/2)
  end
  x.saveImage=function(_,image,path)saved=path end
  x.write=function(_,key,value)T.eq(key,'constants');constants=value end
  M.extract(x)
  for i,index in ipairs(expected)do
    local actual=pixels[i]or{0,0,0,0};local want={0,0,0,0}
    if index~=0 then
      local r,g,b=K.rgb8(word(index));want={r/255,g/255,b/255,1}
    end
    T.same(actual,want,version..' own tiled bitmap pixel '..i..' matches pinned generic bake')
  end
  T.eq(saved,'ui/bag_registered.png');T.eq(constants.untouched,'KEEP')
  local spec=constants.gen3BagScreen.registered
  T.eq(M.valid(spec,version),true);T.eq(spec.x,112);T.eq(spec.dy,0)
  local serialized=Writer.encode(constants)
  Fs.read=function()return serialized end;Fs.exists=function(path)return path==spec.male end
  T.eq(#M.missing(version),0,'complete own badge satisfies readiness')
  Fs.exists=function()return false end
  T.eq(#M.missing(version),1,'missing image cannot satisfy readiness')
  Fs.exists=function()return true end
  local other=version=='firered'and'leafgreen'or'firered'
  T.eq(M.valid(spec,other),false);T.eq(#M.missing(other),1,'another cartridge cannot satisfy readiness')
  for _,key in ipairs{'format','version','male','female','width','height','x','dy'}do
    local old=spec[key];spec[key]=nil
    T.eq(M.valid(spec,version),false,'required native badge field '..key);spec[key]=old
  end
end
T.check(addresses.firered[1]~=addresses.leafgreen[1],'LeafGreen uses its own bitmap address')
T.check(addresses.firered[2]~=addresses.leafgreen[2],'LeafGreen uses its own window palette address')
for _,version in ipairs{'ruby','sapphire','emerald','gold'}do
  T.eq(M.supports(version),false);T.eq(M.valid({},version),false);T.eq(#M.missing(version),0)
  local x={version=version};M.extract(x);T.eq(x._constants,nil,'unrelated extractor is untouched')
end
local Import=require('src.import.RomImporter')
for _,version in ipairs{'firered','leafgreen'}do
  T.check(Import.cacheContract(version).marker:find('frlg-bag-registration-v1:',1,true))
end
for _,version in ipairs{'ruby','sapphire','emerald','gold'}do
  T.eq(Import.cacheContract(version).marker:find('frlg-bag-registration-v1:',1,true),nil)
end
Image.blank,Fs.read,Fs.exists,love.filesystem.load=blank,read,exists,loadFile
T.finish('FRLG own SELECT bitmap, exact native RGBA, anchors, readiness and edition isolation')
