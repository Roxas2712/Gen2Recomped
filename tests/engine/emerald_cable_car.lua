-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit');local V=require('src.core.GameVersion')
local A=require('src.import.Gen3EmeraldCableCarAssets');local W=require('src.import.LuaWriter')
local actors={{100,'OBJ_EVENT_GFX_RIVAL_BRENDAN_NORMAL'},{105,'OBJ_EVENT_GFX_RIVAL_MAY_NORMAL'},
 {55,'OBJ_EVENT_GFX_HIKER'},{31,'OBJ_EVENT_GFX_CAMPER'},{32,'OBJ_EVENT_GFX_PICNICKER'},{98,'OBJ_EVENT_GFX_ZIGZAGOON_1'}}
local function fixture()
 local spec={format=1,version='emerald',resources=A.resources(),actors={},graphics={}}
 for _,entry in ipairs(actors)do
  local id,name=entry[1],entry[2];local palette={};for i=1,16 do palette[i]=i end
  spec.graphics[name]=id;spec.actors[id]={w=16,h=id==98 and 16 or 32,frames=9,palette=palette,paletteTag=id,
   png='data/generated/gba/cable_car/actors/actor_'..id..'.png'}
 end
 return spec
end
local spec=fixture();T.eq(A.valid(spec,'emerald'),true,'Emerald owns all original ride resources and actors')
for _,edition in ipairs{'ruby','sapphire','firered','leafgreen','crystal'}do
 T.eq(A.valid(spec,edition),false,'A different edition cannot consume Emerald ride data')
 T.eq(pcall(A.extract,{version=edition}),false,'Other-edition extraction fails before reading or writing resources')
end
for _,change in ipairs{'old-version','missing-resource','wrong-resource','wrong-actor','short-frames','short-palette','wrong-picture','wrong-size'}do
 local s=fixture()
 if change=='old-version'then s.version='ruby'
 elseif change=='missing-resource'then table.remove(s.resources)
 elseif change=='wrong-resource'then s.resources[1]='data/generated/gba/title/manifest.lua'
 elseif change=='wrong-actor'then s.graphics.OBJ_EVENT_GFX_RIVAL_MAY_NORMAL=100
 elseif change=='short-frames'then s.actors[98].frames=8
 elseif change=='short-palette'then table.remove(s.actors[105].palette)
 elseif change=='wrong-picture'then s.actors[105].png=s.actors[100].png
 elseif change=='wrong-size'then s.actors[98].h=64 end
 T.eq(A.valid(s,'emerald'),false,change..' cannot be advertised as a ready native ride')
end
local resources=A.resources();resources[1]='changed';T.eq(A.resources()[1],'data/generated/gba/cable_car/manifest.lua')
local previousFs=package.loaded['src.import.CacheFs'];local absent
local art={format=1,game='emerald',assetLayout='emerald',build='emerald',tilemaps={},sprites={},palettes={}}
package.loaded['src.import.CacheFs']={read=function(path)
 if path=='data/generated/constants.lua'then return W.encode({gen3EmeraldCableCar=spec})end
 if path=='data/generated/gba/cable_car/manifest.lua'then return W.encode(art)end
end,exists=function(path)return path~=absent end}
T.eq(#A.missing(),0,'Complete native cache is ready')
absent=spec.resources[8];T.eq(A.missing()[1],absent,'A missing actor picture requires repair')
absent=nil;art.assetLayout='rs';T.eq(A.missing()[1],spec.resources[1],'A foreign manifest requires a native Emerald re-import')
package.loaded['src.import.CacheFs']=previousFs

local Commands=require('src.script.Gen3Commands');local previousVersion=V.get()
local oldE=package.loaded['src.ui.Gen3EmeraldCableCar'];local oldRs=package.loaded['src.ui.Gen3RsCableCar']
local oldTransition=package.loaded['src.render.Transition']
package.loaded['src.render.Transition']={new=function(_,callback)return{begin=callback}end}
for _,edition in ipairs{'emerald','ruby','sapphire'}do for _,down in ipairs{false,true}do
 V.set(edition);local stack={states={}};function stack:push(s)self.states[#self.states+1]=s end
 local chosen,scene,options,arrival,warps,resumes,yields,releases=nil,nil,nil,nil,0,0,0,0
 local function provider(label)return{available=function()return true end,new=function(_,opts)
  chosen=label;options=opts;scene={};return scene
 end}end
 package.loaded['src.ui.Gen3EmeraldCableCar']=provider('emerald')
 package.loaded['src.ui.Gen3RsCableCar']=provider('rs')
 local world={startWarpTo=function(_,map,x,y,facing,callback,opts)
  warps=warps+1;T.eq(map,'MAP_G19_N01');T.eq(x,6);T.eq(y,5);T.eq(facing,'down')
  T.eq(opts.fade,false,'The finished black scene owns the warp boundary');arrival=callback
 end}
 local runner={yield=function()yields=yields+1 end,resume=function()resumes=resumes+1 end}
 local save={gen3Vars={[0x8004]=down and 1 or 0},gen3PendingWarp={map='MAP_G19_N01',group=19,number=1,x=6,y=5}}
 Commands.SPECIALS[155]({game={stack=stack},save=save,overworld=world,runner=runner})
 T.eq(chosen,edition=='emerald'and'emerald'or'rs','The ride selects its own edition provider')
 T.eq(yields,1);T.eq(warps,0,'Travel cannot precede the original ride')
 T.eq(options.goingDown,down);stack.states[1].begin();T.eq(stack.states[2],scene)
 options.onDone(function()releases=releases+1 end)
 T.eq(warps,1);T.eq(releases,0);T.eq(resumes,0,'The station script remains suspended during arrival')
 arrival();T.eq(releases,1);T.eq(resumes,1,'Release and resume follow the completed arrival')
end end
package.loaded['src.ui.Gen3EmeraldCableCar']=oldE;package.loaded['src.ui.Gen3RsCableCar']=oldRs
package.loaded['src.render.Transition']=oldTransition;V.set(previousVersion)
T.finish('Emerald cable-car cache ownership, repair and deferred native ride/arrival across Hoenn')
