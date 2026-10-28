-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local M=require('src.import.Gen3RsCreditsAssets')
local UI=require('src.ui.Gen3RsCredits')
local Fs,Writer=require('src.import.CacheFs'),require('src.import.LuaWriter')
local V=require('src.core.GameVersion');local old=V.get()
local read,exists=Fs.read,Fs.exists
local root='data/generated/gba/credits_rse/'
for _,edition in ipairs{'ruby','sapphire'}do
  V.set(edition)
  local resources={}
  for _,name in ipairs{'manifest.lua','the_end.rgba','the_end_blank.rgba','grass.rgba',
    'brendan_credits.png','may_credits.png','ampersand.4bpp'}do resources[#resources+1]=root..name end
  local spec={format=1,version=edition,resources=resources,pageCount=52,numMonSlides=68}
  local man={game=edition,assetLayout='rs',creditsVersion=2,pageCount=52,entriesPerPage=5,
    numMonSlides=68,pages={},pageTransitions={},credits={brendan_credits={},may_credits={}}}
  for i=1,52 do
    man.pages[i]={}
    for j=1,5 do man.pages[i][j]={text=j==1 and'PROGRAMMERS'or'FIXTURE NAME',isTitle=j==1,palette=j==1 and 9 or 8}end
  end
  local files={};for _,p in ipairs(resources)do files[p]=true end
  local constants={gen3RsCredits=spec};local bodies={}
  local function write()
    bodies['data/generated/constants.lua']=Writer.encode(constants)
    bodies[root..'manifest.lua']=Writer.encode(man)
  end
  Fs.read=function(p)return bodies[p]end;Fs.exists=function(p)return files[p]or false end
  write()
  T.eq(M.valid(spec,edition),true,'own-edition credits metadata is accepted')
  T.eq(UI.available({data={constants=constants}}),true,'own edition selects native credits')
  T.eq(#M.missing(edition),0,'complete 52-page cache is ready')
  T.eq(M.valid(spec,edition=='ruby'and'sapphire'or'ruby'),false,'other cartridge metadata is rejected')
  T.check(#M.missing(edition=='ruby'and'sapphire'or'ruby')>0,'another edition cannot satisfy readiness')
  for _,path in ipairs(resources)do
    files[path]=nil
    T.check(#M.missing(edition)>0,'lost native resource invalidates cache: '..path)
    files[path]=true
  end
  for _,field in ipairs{'game','assetLayout','creditsVersion','pageCount','entriesPerPage','numMonSlides','pages','credits'}do
    local value=man[field];man[field]=nil;write()
    T.check(#M.missing(edition)>0,'missing manifest contract invalidates cache: '..field)
    man[field]=value
  end
  for _,field in ipairs{'text','isTitle','palette'}do
    local value=man.pages[52][5][field];man.pages[52][5][field]=nil;write()
    T.check(#M.missing(edition)>0,'every final-page row is validated: '..field)
    man.pages[52][5][field]=value
  end
  man.pages[52][5]=nil;write();T.check(#M.missing(edition)>0,'incomplete final page cannot pass readiness')
  bodies[root..'manifest.lua']='return this is invalid'
  T.check(#M.missing(edition)>0,'corrupt manifest is reported safely')
  constants.gen3RsCredits=nil;write()
  T.check(#M.missing(edition)>0,'old approximate credits cache requires re-import')
  for _,other in ipairs{'red','gold','emerald','firered','leafgreen'}do
    V.set(other)
    T.eq(UI.available({data={constants={gen3RsCredits=spec}}}),false,'other game keeps its own credits: '..other)
  end
end
Fs.read,Fs.exists=read,exists;V.set(old)
T.finish('native RS credits readiness, all pages, missing resources and edition isolation')
