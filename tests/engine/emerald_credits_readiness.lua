-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit');local M=require('src.import.Gen3EmeraldCreditsAssets')
local UI=require('src.ui.Gen3EmeraldCredits');local Fs,Writer=require('src.import.CacheFs'),require('src.import.LuaWriter')
local V=require('src.core.GameVersion');local old=V.get();V.set('emerald')
local read,exists=Fs.read,Fs.exists;local root='data/generated/gba/credits_rse/'
local resources={};for _,name in ipairs{'manifest.lua','the_end.rgba','the_end_blank.rgba','grass.rgba',
  'fonts/latin_normal_fg.rgba','fonts/latin_normal_shadow.rgba','fonts/latin_widths.lua','fonts/metrics.lua','fonts/palette.lua'}do resources[#resources+1]=root..name end
local spec={format=1,version='emerald',resources=resources,pageCount=57,numMonSlides=71,fonts=root..'fonts/'}
local man={game='emerald',assetLayout='emerald',format_version=1,pageCount=57,entriesPerPage=5,numMonSlides=71,
  palette={},animsPlayer={{}},animsRival={{}},monSpritePos={{0,0}},theEnd='the_end.rgba',theEndBlank='the_end_blank.rgba',grass='grass.rgba',pages={}}
for i=1,32 do man.palette[i]=0 end
for i=1,57 do man.pages[i]={};for j=1,5 do man.pages[i][j]={text='OWNED CREDIT ROW',isTitle=j==1}end end
local constants={gen3EmeraldCredits=spec};local files,bodies={},{}
for _,path in ipairs(resources)do files[path]=true end
local widths={[0]=5,[511]=8};local metrics={[1]={name='FONT_NORMAL',maxLetterHeight=16}}
local palette={[1]={0,0,0},[15]={255,255,255}}
local function write()
  bodies['data/generated/constants.lua']=Writer.encode(constants)
  bodies[root..'manifest.lua']=Writer.encode(man)
  bodies[root..'fonts/latin_widths.lua']=Writer.encode(widths)
  bodies[root..'fonts/metrics.lua']=Writer.encode(metrics)
  bodies[root..'fonts/palette.lua']=Writer.encode(palette)
end
Fs.read=function(path)return bodies[path]end;Fs.exists=function(path)return files[path]or false end;write()
T.eq(M.valid(spec,'emerald'),true,'only Emerald accepts its own metadata')
T.eq(UI.available({data={constants=constants}}),true,'native Emerald credits selected')
T.eq(#M.missing(),0,'all 57 pages, 71 slides, resources and native normal font are ready')
for _,path in ipairs(resources)do
  files[path]=nil;T.check(#M.missing()>0,'lost resource invalidates cache: '..path);files[path]=true
end
for _,field in ipairs{'game','assetLayout','format_version','pageCount','entriesPerPage','numMonSlides',
  'palette','animsPlayer','animsRival','monSpritePos','theEnd','theEndBlank','grass','pages'}do
  local value=man[field];man[field]=nil;write();T.check(#M.missing()>0,'missing original manifest contract: '..field);man[field]=value
end
for _,field in ipairs{'text','isTitle'}do
  local value=man.pages[57][5][field];man.pages[57][5][field]=nil;write()
  T.check(#M.missing()>0,'every final-page row is required: '..field);man.pages[57][5][field]=value
end
local width=widths[511];widths[511]=nil;write();T.check(#M.missing()>0,'last native glyph width required');widths[511]=width
metrics[1].name='FONT_SMALL';write();T.check(#M.missing()>0,'a small font cannot substitute for original normal credits font');metrics[1].name='FONT_NORMAL'
palette[15]=nil;write();T.check(#M.missing()>0,'native font palette required');palette[15]={255,255,255}
write();bodies[root..'manifest.lua']='return invalid lua';T.check(#M.missing()>0,'corrupt manifest reported safely')
constants.gen3EmeraldCredits=nil;write();T.check(#M.missing()>0,'old text-on-black credits cache rejected')
for _,version in ipairs{'ruby','sapphire','firered','leafgreen','red','gold'}do
  V.set(version);T.eq(UI.available({data={constants={gen3EmeraldCredits=spec}}}),false,'other edition keeps its own movie: '..version)
end
Fs.read,Fs.exists=read,exists;V.set(old)
T.finish('native Emerald 57-page credits, 71-slide program, full font resources and edition isolation')
