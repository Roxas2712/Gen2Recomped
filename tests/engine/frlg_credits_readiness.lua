-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit');local M=require('src.import.Gen3FrlgCreditsAssets')
local UI=require('src.ui.Gen3FrlgCredits');local Hall=require('src.import.Gen3FrlgHallAssets')
local V=require('src.core.GameVersion');local F,W=require('src.import.CacheFs'),require('src.import.LuaWriter')
local old,read,exists=V.get(),F.read,F.exists
local function records()
 local p={format_version=1,title='ORIGINAL STAFF',script={},texts={},scenes={},spriteParams={},mons={}}
 for i=1,66 do p.script[i]={cmd=0,param=0,duration=120}end
 for i=0,42 do p.texts[i]={title='ORIGINAL HEADER',names='ORIGINAL NAME'}end
 for i=0,12 do p.scenes[i]={{op='loadmap',mapGroup=3,mapNum=i,x=11,y=6}}end
 for i=0,4 do p.spriteParams[i]={character=0,ground=0,motion=0}end
 local man={format_version=1,screen={w=240,h=160},circle={w=64,h=64},sheets={},mons={}}
 for i,n in ipairs{6,3,9,25}do
  p.mons[i-1]={species=n,windows={{},{},{}}};man.mons[i-1]={frame1={w=64,h=64},frame2={w=64,h=64}}
 end
 for _,key in ipairs{'player_male','player_female','rival','ground_grass','ground_dirt','ground_city'}do
  local g=key:sub(1,7)=='ground_';man.sheets[key]={w=64,h=g and 32 or 64,frames=g and 8 or 6}
 end
 return p,man
end
for _,version in ipairs{'firered','leafgreen'}do
 V.set(version);local pack,man=records();local spec={format=1,version=version,resources=M.resources()}
 local text={};for _,key in ipairs(Hall.LABELS)do text[key]={{t='text',s='OWNED'}}end
 local hall={format=1,version=version,resources=Hall.resources(),textIR=text,
  trainerPics={boy='BOY',girl='GIRL'},songIds={MUS_HALL_OF_FAME=286,SE_APPLAUSE=98}}
 local constants={gen3FrlgCredits=spec,gen3FrlgHall=hall};local files,bodies={},{}
 for _,path in ipairs(spec.resources)do files[path]=true end
 local function write()
  bodies['data/generated/constants.lua']=W.encode(constants);bodies[M.ROOT..'pack.lua']=W.encode(pack);bodies[M.ROOT..'manifest.lua']=W.encode(man)
 end
 F.read=function(path)return bodies[path]end;F.exists=function(path)return files[path]or false end;write()
 T.eq(UI.available({data={constants=constants}}),true,'own edition selects original credits')
 T.eq(#M.missing(version),0,'complete script/art resources accepted')
 for _,path in ipairs(spec.resources)do files[path]=nil;T.check(#M.missing(version)>0,'every original credit resource required: '..path);files[path]=true end
 local first=spec.resources[1];spec.resources[1]=spec.resources[2];T.eq(M.valid(spec,version),false,'duplicate does not replace manifest');spec.resources[1]=first
 pack.script[66]=nil;write();T.check(#M.missing(version)>0,'incomplete cartridge script rejected');pack.script[66]={cmd=5,param=0,duration=600}
 pack.texts[42]=nil;write();T.check(#M.missing(version)>0,'missing staff row rejected');pack.texts[42]={title='OWNED',names='OWNED'}
 pack.scenes[12]=nil;write();T.check(#M.missing(version)>0,'missing last native pan rejected');pack.scenes[12]={{op='loadmap',mapGroup=3,mapNum=39,x=8,y=20}}
 man.sheets.player_female.frames=5;write();T.check(#M.missing(version)>0,'incomplete female sheet rejected');man.sheets.player_female.frames=6
 man.mons[3].frame2.w=0;write();T.check(#M.missing(version)>0,'empty final native Pokemon window rejected');man.mons[3].frame2.w=64
 write();bodies[M.ROOT..'pack.lua']='return malformed lua';T.check(#M.missing(version)>0,'corrupt native script rejected')
 for _,other in ipairs{'ruby','sapphire','emerald','red','gold',version=='firered'and'leafgreen'or'firered'}do
  V.set(other);T.eq(UI.available({data={constants=constants}}),false,'foreign edition cannot select another cart credits: '..other)
 end
end
F.read,F.exists=read,exists;V.set(old)
T.finish('original FRLG credits script, map pans, sprites, Pokemon windows and edition readiness')
