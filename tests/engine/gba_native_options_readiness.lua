-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit');local Assets=require('src.import.Gen3NativeOptionsAssets')
local Fs=require('src.import.CacheFs');local Writer=require('src.import.LuaWriter')
local V=require('src.core.GameVersion');local old=V.get();local read,exists=Fs.read,Fs.exists
for _,version in ipairs{'emerald','firered','leafgreen'}do
 V.set(version)
 local spec={format=2,version=version,textIR={},resources=Assets.resources(version),frameCount=version=='emerald'and 20 or 10}
 for _,name in ipairs(Assets.labels(version))do spec.textIR[name]={{t='text',s='OWNED '..name}}end
 if version=='emerald'then spec.manifest=Assets.MANIFEST;spec.arrow={png='data/generated/gba/native_options/arrows.png',w=16,h=16}end
 local manifest={format=1,game=version,option={textPalette={},bgColor=0,windows={
  {left=2,top=1,width=26,height=2},{left=2,top=5,width=26,height=14}}}}
 for i=1,16 do manifest.option.textPalette[i]=i end
 local c={gen3NativeOptions=spec};local game={data={constants=c}}
 Fs.read=function(path)return Writer.encode(path==Assets.MANIFEST and manifest or c)end
 Fs.exists=function()return true end
 T.eq(Assets.valid(spec,version),true,'own complete option vocabulary admitted: '..version)
 T.eq(#Assets.missing(version),0,'complete cache is ready')
 for _,path in ipairs(Assets.resources(version))do
  Fs.exists=function(p)return p~=path end
  T.eq(Assets.missing(version)[1],path,'native keypad/small-font resource is required: '..path)
 end
 Fs.exists=function()return true end
 spec.format=1;T.eq(Assets.valid(spec,version),false,'old word-fallback cache is rejected');spec.format=2
 T.eq(require('src.ui.Gen3NativeOptions').record(game),spec,'host selects own native options')
 for _,key in ipairs(Assets.labels(version))do
  local value=spec.textIR[key];spec.textIR[key]=nil
  T.eq(Assets.valid(spec,version),false,'missing native label rejected: '..key);spec.textIR[key]=value
 end
 for _,other in ipairs{'ruby','sapphire','gold','diamond',version=='emerald'and'firered'or'emerald'}do
  T.eq(Assets.valid(spec,other),false,'cross-edition resources rejected: '..other)
 end
 spec.frameCount=99;T.eq(Assets.valid(spec,version),false,'frame count must match own cartridge');spec.frameCount=version=='emerald'and 20 or 10
 if version=='emerald'then
  Fs.exists=function()return false end;T.eq(#Assets.missing(version),1,'missing native scroll glyph rejected');Fs.exists=function()return true end
  manifest.game='ruby';T.eq(#Assets.missing(version),1,'RS geometry cannot substitute Emerald');manifest.game=version
  manifest.option.windows[2].height=nil;T.eq(#Assets.missing(version),1,'missing actual window bounds rejected')
 end
end
Fs.read,Fs.exists=read,exists;V.set(old)
-- The original menu decoder reads both window u16 fields and pointer tables.
-- Exercise its reader interface before a full cartridge/graphics import.
local Loader=require('compat.gen1-rs.Loader');local oldNew=Loader.new
local x={version='emerald',_constants={},beginStage=function()end,
 rom={data=string.rep('\255',16),size=16,u8=function()return 255 end,
  u16=function(_,at)T.eq(at,2);return 0x1234 end,u32=function(_,at)T.eq(at,4);return 0x12345678 end}}
Loader.new=function()return function(name)
 if name=='src.import.gba.syms'then return{of=function()return{off=function()return 0 end,size=function()return 2048 end,count=function()return 512 end}end}end
 if name=='src.core.game3.scripting.text_ir'then return{decode=function()return{{t='text',s='OWNED'}}end}end
 if name=='src.import.gba.rse.menus_extract'then return{run=function(rom)
  T.eq(rom:get(0),255);T.eq(rom:u16(2),0x1234);T.eq(rom:u32(4),0x12345678)
  T.eq(rom:readString(0,3),string.rep('\255',3));return true
 end}end
 if name=='src.import.gba.rse.text_chrome_extract'then return{
  extractLatin=function(_,face)T.eq(face,'small');return{width=256,height=512,fgRgba='',shRgba='',widths={}}end,
  extractKeypadIcons=function()return{width=128,height=32,rgba=''}end}end
 if name=='src.import.gba.rse.boot_gfx'then return{context=function()return{
  lz=function()end,pal=function()end,strip=function()return{png='data/generated/gba/native_options/arrows.png',w=16,h=16}end}
 end}end
 error('Unexpected extractor dependency '..name)
end end
local write=Fs.write;Fs.write=function()return true end
local ok,why=pcall(Assets.extract,x);Loader.new=oldNew;Fs.write=write
T.eq(ok,true,why or'original decoder reader interface is complete')
T.eq(Assets.valid(x._constants.gen3NativeOptions,'emerald'),true,'extracted own-edition record passes admission')
-- Load the actual relocated FRLG dependency graph, not a mocked loader.
-- Its versions_game module needs the host's explicitly isolated GameVersion.
local fsLoad=love.filesystem.load;love.filesystem.load=function(path)return loadfile(path)end
for _,version in ipairs{'firered','leafgreen'}do
 local bytes;Fs.write=function(path,raw)if path==Assets.KEYPAD then bytes=raw end;return true end
 local cart={version=version,_constants={},beginStage=function()end,rom={u8=function()return 255 end}}
 local good,problem=pcall(Assets.extract,cart)
 T.eq(good,true,problem or'own FRLG keypad extractor dependency graph loads')
 T.eq(type(bytes)=='string'and#bytes,128*32*4,'own native keypad sheet reaches cache writer')
end
Fs.write=write;love.filesystem.load=fsLoad
local Rows=require('src.ui.Gen3OptionRows');local host={};local step,activate=0,0;local page
local owner={game=host,rows={{label='OWN STEP',engine={step=function(g,d)T.eq(g,host);step=step+d;return true end}},
 {label='OWN ACTION',engine={activate=function(g)T.eq(g,host);activate=activate+1 end}}},valueText=function()return'VALUE'end}
local native={};for _,key in ipairs(require('src.core.Gen3RsOptionValues').keys)do native[key]={id=key}end
local rows=Rows.withCart(owner,native,function(_,members)page=members end)
T.eq(#rows,7,'six cartridge rows and one host category')
rows[7].activate();T.eq(#page,2,'all host rows retained');T.eq(page[1].value(),'VALUE','host value formatter retained')
page[1].step(nil,-1);page[2].activate();T.eq(step,-1,'host step once');T.eq(activate,1,'host action once')
T.finish('own-edition native option resources, window readiness and common host callback preservation')
