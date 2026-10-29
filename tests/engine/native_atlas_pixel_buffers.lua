-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
love=require('tests.love_stub')
local H=require('tests.harness')
local F=require('tools.native-atlas.fixture')
local M=require('src.compat.gen1.AtlasPixels')
local B=require('src.compat.gen1.AtlasPixelBuffers')
local Tiles=require('src.render.Gen3Tiles')
local function equal(a,b,label)
 H.eq(b:blob(false),a:blob(false),label..' indexed under')
 H.eq(b:blob(true),a:blob(true),label..' indexed over')
 H.eq(b:rgba(false),a:rgba(false),label..' RGBA under')
 H.eq(b:rgba(true),a:rgba(true),label..' RGBA over')
 H.same(b.slotPalettes,a.slotPalettes,label..' palette reverse index')
 H.same(b.paletteUsers,a.paletteUsers,label..' palette users')
 H.eq(b.indexRevision,a.indexRevision);H.eq(b.revision,a.revision)
end
for _,edition in ipairs{'firered','leafgreen','emerald','ruby','sapphire'}do
 local f=F.new(edition)
 f.pair.primary.animations={{tile=0,count=2,step=3,frames={string.rep('\17',64),string.rep('\34',64),string.rep('\51',64)}}}
 local a,b=M.new(f.pair,f.layout),M.new(f.pair,f.layout);b.packedProjection=true
 for tick=1,42 do
  local au,ao=a:update(tick);local bu,bo=b:update(tick)
  H.same(bu,au);H.same(bo,ao);equal(a,b,edition..' '..tick)
 end
 H.check((b.packedProjectionCells or 0)>0,'packed projection actually ran')
 local words={};for i=1,16 do words[i]=(i*137)%32768 end
 a:setPalette(0,words);b:setPalette(0,words);equal(a,b,'override')
 a:setPalette(0,nil);b:setPalette(0,nil);equal(a,b,'override reset')
 f.pair.primary.palettes[2][3][1]=73;a:update(43);b:update(43);equal(a,b,'in-place RGB')
 -- Foreign instance methods retain their callback and original pixel path.
 local before=b.packedProjectionCells
 local function foreign(self,mid)local entries=Tiles.entries(self,mid);entries[1].flipX=not entries[1].flipX;return entries end
 a.decoder.entries,b.decoder.entries=foreign,foreign
 a:update(45);b:update(45);equal(a,b,'foreign entries')
 H.eq(b.packedProjectionCells,before,'foreign decoder disabled native packing')
 a.decoder.entries,b.decoder.entries=nil,nil
 local pixels={};for i=1,64 do pixels[i]=(i%8)+.5 end
 a.decoder.tileCache[0],b.decoder.tileCache[0]=pixels,pixels
 a.paletteKey,b.paletteKey=nil,nil
 a:update(46);b:update(46);equal(a,b,'fractional public tile cache')
 local old=B.rgba;B.rgba=function()error('foreign packer must retain fallback')end
 before=b.packedProjectionCells
 H.eq(M._workerCompatible(),false,'foreign packed helper retains worker fallback')
 a:update(48);b:update(48);equal(a,b,'foreign packed helper')
 H.eq(b.packedProjectionCells,before)
 B.rgba=old
end
do
 local p=assert(B.new());local lut={}
 for i=0,255 do lut[i]=string.char(i,255-i,i%7,255)end
 H.eq(p:palette(lut),true)
 local indices={};for i=0,255 do indices[i+1]=string.char(i)end;indices=table.concat(indices)
 local under,over=p:rgba(indices,false),p:rgba(indices,true)
 for i=0,255 do
  H.eq(under:sub(i*4+1,i*4+4),lut[i]);H.eq(over:sub(i*4+1,i*4+4),i==0 and'\0\0\0\0'or lut[i])
 end
 local held=under;p:rgba(string.rep('\7',256),false);H.eq(under,held,'scratch reuse keeps returned strings immutable')
 H.eq(p:rgba('short',false),nil,'short indices never reach native pointer reads')
 H.eq(p:used(indices,'short'),nil,'short palette census never reaches native pointer reads')
 H.eq(p:palette(setmetatable({},{__index=lut})),false,'foreign palette lookup falls back')
 lut[1]='bad';H.eq(p:palette(lut),false,'malformed palette falls back')
 local f=F.new('firered');local d=Tiles.new(f.pair,f.layout)
 H.eq(B.compatible(d,Tiles),true);d.tileCache=setmetatable({},{})
 H.eq(B.compatible(d,Tiles),false,'foreign tile cache falls back')
 local chunk=assert(loadfile('src/compat/gen1/AtlasPixelBuffers.lua'))
 setfenv(chunk,setmetatable({require=function(name)if name=='ffi'then error('no FFI fixture')end;return require(name)end},{__index=_G}))
 local portable=chunk();H.eq(portable.new(),nil);H.eq(portable.compatible(d,Tiles),false)
end
-- Representative animation burst: 180 metatiles sharing animated tiles.
-- Operation-only ABBA timings; no FPS assertion or collector/JIT tuning.
do
 local f=F.new('firered');local base=f.pair.primary
 base.metatiles=string.rep(base.metatiles:sub(1,16),180);base.metatileCount=180
 base.attributes=string.rep(base.attributes:sub(1,2),180)
 base.animations={{tile=0,count=1,step=1,frames={string.rep('\17',32),string.rep('\34',32)}}}
 local a,b=M.new(f.pair,f.layout),M.new(f.pair,f.layout);b.packedProjection=true
 for _,row in ipairs{{a,false},{b,true},{b,true},{a,false}}do
  local model,packed=row[1],row[2]
  for tick=1,4 do model:update(tick)end
  local before=os.clock();for tick=5,20 do model:update(tick)end
  print(('PIXEL_BURST packed=%s cpu_ms=%.3f'):format(tostring(packed),(os.clock()-before)*1000))
 end
 a:update(21);b:update(21);equal(a,b,'representative burst')
end
H.finish('native atlas fixed CPU buffers, five editions, foreign fallbacks and immutable bytes')
