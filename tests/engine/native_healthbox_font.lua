package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local M=require('src.import.Gen3NativeHealthboxAssets')
local Image=require('src.import.ImageWriter')
local old=Image.blank
Image.blank=function(w,h)
  local pixels={}
  return{w=w,h=h,pixels=pixels,setPixel=function(_,x,y,r,g,b,a)
    pixels[x..','..y]={r,g,b,a}
  end}
end
for _,version in ipairs({'firered','leafgreen','emerald'})do
  local across=version=='emerald'and 2 or 1
  local stride=across*32
  local face={role='small',bits=2,count=512,cellWidth=8,glyphs=1000,widths=100000,
    glyphBytes=stride,tilesAcross=across,inkTop=version=='emerald'and 2 or 0}
  local reads={};local x={version=version,manifest={font={faces={face}}},rom={}}
  function x.rom:u8(at)return at==100000+0x105 and 8 or 5 end
  function x.rom:u16(at)
    reads[at]=true
    -- Independent packed word: glyph LV_2 has an ink pixel in original
    -- row 2 and a shadow pixel in row 9, exercising both tile rows.
    if at==1000+0x105*stride+2*2 then return 1*2^14 end
    if at==1000+0x105*stride+across*16+1*2 then return 2*2^12 end
    return 0
  end
  local images={}
  function x:saveImage(image,path)images[path]=image end
  function x:hudImage(raw,from,w,h,pal)
    T.eq(#raw,80*32);T.eq(from,1);T.eq(w,40);T.eq(h,2)
    T.eq(raw[66*32],7);T.eq(raw[66*32+1],0,'padding must not read neighbouring ROM data')
    return{palette=pal}
  end
  local elements={};for i=1,66*32 do elements[i]=7 end
  local s=M.extract(x,elements,{'box'},{'bar'})
  T.check(M.valid(s,version));T.check(not M.valid(s,version=='emerald'and'firered'or'emerald'))
  T.eq(s.widths[0x105],8,'native LV_2 has its own advance')
  local px=0x105%16*16;local py=math.floor(0x105/16)*16
  T.check(images['battle/hud/small_fg.png'].pixels[px..','..(py+2)]~=nil,
    'keep original leading rows instead of generic inkTop crop')
  T.check(images['battle/hud/small_shadow.png'].pixels[(px+1)..','..(py+9)]~=nil,
    'small glyph lower half uses the cartridge-specific tile stride')
  T.eq(images['battle/hud/elements.png'].palette[1],'bar')
  T.eq(images['battle/hud/elements_exp.png'].palette[1],'box')
  s.widths[0x105]=nil;T.check(not M.valid(s,version),'missing native level glyph invalidates cache')
end
T.eq(M.extract({version='ruby'}),nil,'RS keeps its separate native text compositor')
Image.blank=old
local Fs=require('src.import.CacheFs');local read=Fs.read
Fs.read=function()return'return {}'end
T.eq(M.missing('firered')[1],'<gba:native-healthbox-font>')
T.eq(#M.missing('ruby'),0)
Fs.read=read
-- These two retail editions place the 20-row table at different addresses.
local Json=require('src.link.Json')
for version,expected in pairs({firered=0x24EE34,leafgreen=0x24EE10})do
  local f=assert(io.open('tools/rom_manifest_'..version..'.json','rb'))
  local manifest=Json.decode(f:read('*a'));f:close()
  T.eq(manifest.symbols.sBattleTerrainTable,expected)
end
T.finish('Native GBA healthbox untrimmed font rows, LV_2 and cache identity')
