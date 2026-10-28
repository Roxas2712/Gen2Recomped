-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit');local M=require('src.import.Gen3FrlgHallAssets')
local UI=require('src.ui.Gen3FrlgHallOfFame');local V=require('src.core.GameVersion')
local F,W=require('src.import.CacheFs'),require('src.import.LuaWriter')
local old,read,exists=V.get(),F.read,F.exists
for _,version in ipairs{'firered','leafgreen'}do
 V.set(version)
 local text={};for _,key in ipairs(M.LABELS)do text[key]={{t='text',s='OWNED'}}end
 local spec={format=1,version=version,resources=M.resources(),textIR=text,
  trainerPics={boy='OWNED_BOY.png',girl='OWNED_GIRL.png'},songIds={MUS_HALL_OF_FAME=286,SE_APPLAUSE=98}}
 local constants={gen3FrlgHall=spec};local art={format_version=1,width=240,height=160,confetti={w=8,h=8,frames=17}}
 local files,bodies={},{};for _,p in ipairs(spec.resources)do files[p]=true end
 for _,p in pairs(spec.trainerPics)do files[p]=true end
 local function write()bodies['data/generated/constants.lua']=W.encode(constants);bodies[M.ROOT..'hall_of_fame/manifest.lua']=W.encode(art)end
 F.read=function(path)return bodies[path]end;F.exists=function(path)return files[path]or false end;write()
 T.eq(M.valid(spec,version),true,'native Hall metadata belongs to selected edition')
 T.eq(UI.available({data={constants=constants}}),true,'original controller selected')
 T.eq(#M.missing(version),0,'all Hall art/font/window resources ready')
 for _,p in ipairs(spec.resources)do files[p]=nil;T.check(#M.missing(version)>0,'every original resource required: '..p);files[p]=true end
 for _,p in pairs(spec.trainerPics)do files[p]=nil;T.check(#M.missing(version)>0,'both native portraits required');files[p]=true end
 local first=spec.resources[1];spec.resources[1]=spec.resources[2]
 T.eq(M.valid(spec,version),false,'duplicate resource cannot replace a native file');spec.resources[1]=first
 for _,key in ipairs(M.LABELS)do local value=text[key];text[key]=nil;write();T.check(#M.missing(version)>0,'original text required: '..key);text[key]=value end
 for _,key in ipairs{'w','h','frames'}do local value=art.confetti[key];art.confetti[key]=0;write();T.check(#M.missing(version)>0,'native confetti geometry required');art.confetti[key]=value end
 write();bodies[M.ROOT..'hall_of_fame/manifest.lua']='return malformed lua';T.check(#M.missing(version)>0,'corrupt art manifest rejected')
 spec.songIds.SE_APPLAUSE=99;T.eq(M.valid(spec,version),false,'wrong cartridge sound cannot pass readiness');spec.songIds.SE_APPLAUSE=98
 for _,other in ipairs{'ruby','sapphire','emerald','red','gold',version=='firered'and'leafgreen'or'firered'}do
  V.set(other);T.eq(UI.available({data={constants=constants}}),false,'foreign edition cannot borrow resources: '..other)
 end
end
F.read,F.exists=read,exists;V.set(old)
T.finish('original FRLG Hall art, fonts, text, ten frames and edition isolation')
