-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local V=require('src.core.GameVersion')
local Warp=require('src.world.Warp')
local Copy=require('src.mods.Merge').deepCopy
local Serialize=require('src.core.SaveSerializer')
local OW=require('src.world.OverworldController')
for _,version in ipairs{'ruby','sapphire','emerald','firered','leafgreen'}do
 V.set(version)
 local entrance={x=28,y=16,destMap='CAR',destWarp=2}
 local other={x=1,y=2,destMap='ROOM',destWarp=1}
 local source={warps={other,other,other,entrance}}
 local back={x=2,y=5,destMap='MAP_G127_N127',destWarp=128}
 local data={maps={MAP_G01_N43=source,CAR={warps={other,back}},ROOM={warps={other}}}}
 local save={party={{species='PROBE',hp=23}},inventory={LIFT_KEY=1},flags={story=true},
             gen3DynamicWarp={map='OLD',warp=255,x=99,y=99}}
 local ordinary=Serialize.encode({save.party,save.inventory,save.flags})
 local game={data=data,save=save}
 local restore
 for i=1,100 do
  local key,previous=debug.getupvalue(OW.takeWarp,i);if not key then break end
  if key=='Game'then debug.setupvalue(OW.takeWarp,i,game);restore=function()debug.setupvalue(OW.takeWarp,i,previous)end;break end
 end
 assert(restore,'native takeWarp Game upvalue')
 local destination
 local world={map={id='MAP_G01_N43',def=source},player={cellX=28,cellY=17,facing='up'},
              rememberDigWarp=function()end,startWarpTo=function(_,...)destination={...}end}
 T.eq(OW.takeWarp(world,entrance),true,'actual native admission records the lift entrance')
 restore()
 T.eq(destination[1],'CAR');T.eq(destination[2],2);T.eq(destination[3],5)
 T.eq(save.gen3DynamicWarp.map,'MAP_G01_N43');T.eq(save.gen3DynamicWarp.warp,3,'source event is zero based')
 T.eq(save.gen3DynamicWarp.x,28);T.eq(save.gen3DynamicWarp.y,17,'retain actual departure coordinate')
 T.eq(Serialize.encode({save.party,save.inventory,save.flags}),ordinary,'entrance does not change party, bag or story flags')
 local map,x,y=Warp.destination(data,back,nil,nil,save)
 T.eq(map,'MAP_G01_N43');T.eq(x,28);T.eq(y,16,'immediate cancel returns through the original event, not stale coordinates')
 -- Leaving the car after its script selects a floor must not overwrite it.
 save.gen3DynamicWarp={map='SELECTED',warp=255,x=4,y=6}
 local selected=Serialize.encode(save)
 T.eq(Warp.noteGen3Entrance(data,save,back,'MAP_G01_N43','CAR',2,5),false)
 T.eq(Serialize.encode(save),selected,'dynamic exit preserves the selected floor')
 for _,dest in ipairs{'ROOM','MISSING'}do
  T.eq(Warp.noteGen3Entrance(data,save,entrance,dest,'MAP_G01_N43',28,17),false)
  T.eq(Serialize.encode(save),selected,'ordinary and unresolved warps are no-ops')
 end
 local clone=Copy(entrance)
 T.eq(Warp.noteGen3Entrance(data,save,clone,'CAR','MAP_G01_N43',28,17),false,'unknown source event is not guessed')
 T.eq(Serialize.encode(save),selected)
 T.eq(Warp.noteGen3Entrance(data,save,clone,'CAR','MAP_G01_N43',28,17,{warps={other,clone}}),true,
      'the actual live map definition owns a modified source event')
 T.eq(save.gen3DynamicWarp.warp,1)
 if version=='firered'or version=='leafgreen'then
  local C={SPECIALS={},VAR_RESULT=0x800D,
   getVar=function(s,id)return(s.gen3Vars or{})[id]or 0 end,
   setVar=function(s,id,value)s.gen3Vars=s.gen3Vars or{};s.gen3Vars[id]=value end}
  require('src.script.Gen3SpecialsFRLG')(C)
  local context={save=save,game={data={constants={gen3FRLGSpecialTexts={nowOn='Now on:',floors={[3]='B2F'}}}}},overworld={}}
  C.SPECIALS[0x1000+216](context)
  T.eq(save.gen3Vars[0x403A],2,'native floor special reads the entered B2F')
  save.gen3Vars[0x8005]=save.gen3Vars[0x403A]
  C.SPECIALS[0x1000+306](context)
  T.eq(context.overworld.frlgFloorWindow.floor,'B2F','native current-floor window gets its actual label')
  T.eq(C.SPECIALS[0x1000+440](context),1,'native floor picker opens on B2F')
 end
end
T.finish('GBA native warp admission remembers lift entrances and preserves ordinary returns')
