-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local M=require('src.import.Gen3RsHallAssets');local UI=require('src.ui.Gen3RsHallOfFame')
local Fs,Writer=require('src.import.CacheFs'),require('src.import.LuaWriter')
local V=require('src.core.GameVersion');local old=V.get()
local read,exists,load=Fs.read,Fs.exists,love.filesystem.load;love.filesystem.load=loadfile
local root='data/generated/gba/hall_of_fame/'
for _,edition in ipairs{'ruby','sapphire'}do
  V.set(edition)
  local pics={boy='data/generated/gba/birch/brendan.png',girl='data/generated/gba/birch/may.png'}
  local resources={root..'manifest.lua',root..'bands.rgba',root..'stripes.rgba',root..'confetti.rgba',pics.boy,pics.girl}
  local words={};local aliases=require('compat.gen1-rs.Loader').new(edition)('src.ui.game3.rs.hall_of_fame_policy').aliases
  for key in pairs(aliases)do words[key]={{t='text',s='OWNED LABEL'}}end
  for _,key in ipairs{'gOtherText_IDNumber2','gText_EggNickname'}do words[key]={{t='text',s='OWNED LABEL'}}end
  local spec={format=1,version=edition,resources=resources,textIR=words,trainerPics=pics}
  local constants={gen3RsHall=spec};local man={game=edition,assetLayout='rs',hofVersion=1,
    width=240,height=160,confetti={w=8,h=8,frames=17}}
  local bodies,files={},{};for _,path in ipairs(resources)do files[path]=true end
  local function write()
    bodies['data/generated/constants.lua']=Writer.encode(constants);bodies[root..'manifest.lua']=Writer.encode(man)
  end
  Fs.read=function(p)return bodies[p]end;Fs.exists=function(p)return files[p]or false end
  write()
  T.eq(M.valid(spec,edition),true,'own native ceremony metadata is accepted')
  T.eq(UI.available({data={constants=constants}}),true,'own edition selects native ceremony')
  T.eq(#M.missing(edition),0,'complete exact-edition ceremony is ready')
  T.check(#M.missing(edition=='ruby'and'sapphire'or'ruby')>0,'another edition cannot satisfy ceremony readiness')
  for _,path in ipairs(resources)do
    files[path]=nil;T.check(#M.missing(edition)>0,'every art resource is required: '..path);files[path]=true
  end
  local keys={};for key in pairs(words)do keys[#keys+1]=key end;table.sort(keys)
  for _,key in ipairs(keys)do local value=words[key]
    words[key]=nil;write();T.check(#M.missing(edition)>0,'every original label is required: '..key);words[key]=value
  end
  for _,key in ipairs{'game','assetLayout','hofVersion','width','height','confetti'}do
    local value=man[key];man[key]=nil;write();T.check(#M.missing(edition)>0,'manifest contract is required: '..key);man[key]=value
  end
  for _,key in ipairs{'w','h','frames'}do
    local value=man.confetti[key];man.confetti[key]=0;write()
    T.check(#M.missing(edition)>0,'native confetti dimensions/count are required: '..key);man.confetti[key]=value
  end
  bodies[root..'manifest.lua']='return invalid syntax'
  T.check(#M.missing(edition)>0,'corrupt art manifest is reported without execution')
  constants.gen3RsHall=nil;write();T.check(#M.missing(edition)>0,'old approximate ceremony cache is rejected')
  for _,other in ipairs{'red','gold','emerald','firered','leafgreen'}do
    V.set(other);T.eq(UI.available({data={constants={gen3RsHall=spec}}}),false,'other edition keeps its own ceremony: '..other)
  end
end
Fs.read,Fs.exists,love.filesystem.load=read,exists,load;V.set(old)
T.finish('native RS ceremony resources, all original labels and edition isolation')
