-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit');local Assets=require('src.import.Gen3NativeOptionsAssets')
local Fs=require('src.import.CacheFs');local Writer=require('src.import.LuaWriter')
local V=require('src.core.GameVersion');local old=V.get();local read,exists=Fs.read,Fs.exists
for _,version in ipairs{'emerald','firered','leafgreen'}do
 V.set(version)
 local spec={format=1,version=version,textIR={},frameCount=version=='emerald'and 20 or 10}
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
local Rows=require('src.ui.Gen3OptionRows');local host={};local step,activate=0,0;local page
local owner={game=host,rows={{label='OWN STEP',engine={step=function(g,d)T.eq(g,host);step=step+d;return true end}},
 {label='OWN ACTION',engine={activate=function(g)T.eq(g,host);activate=activate+1 end}}},valueText=function()return'VALUE'end}
local native={};for _,key in ipairs(require('src.core.Gen3RsOptionValues').keys)do native[key]={id=key}end
local rows=Rows.withCart(owner,native,function(_,members)page=members end)
T.eq(#rows,7,'six cartridge rows and one host category')
rows[7].activate();T.eq(#page,2,'all host rows retained');T.eq(page[1].value(),'VALUE','host value formatter retained')
page[1].step(nil,-1);page[2].activate();T.eq(step,-1,'host step once');T.eq(activate,1,'host action once')
T.finish('own-edition native option resources, window readiness and common host callback preservation')
