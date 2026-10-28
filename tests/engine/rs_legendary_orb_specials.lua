-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local V=require('src.core.GameVersion');local M=require('src.script.Gen3RsOrbSpecials')
local Fx=require('src.world.Gen3ScreenFx');local Music=require('src.core.Music')
local C=require('src.script.Commands');require('src.script.Gen3Commands')
local W=require('src.import.LuaWriter')
for _,edition in ipairs{'ruby','sapphire'}do
  V.set(edition)
  for result=0,3 do
    local ow={};local save={gen3Vars={[0x800D]=result}}
    local before=W.encode(save);local parked,resumed=false,0
    local runner={yield=function()parked=true end,resume=function()parked=false;resumed=resumed+1 end}
    local ctx={save=save,overworld=ow,runner=runner}
    C.g3_special(ctx,0x1119)
    T.eq(ctx.g3UnhandledSpecials,nil,'original RS command is served')
    T.eq(ow.g3Orb.cx,result<2 and 104 or 120);T.eq(ow.g3Orb.blue,result%2==1)
    C.g3_wait_state(ctx);T.eq(parked,true)
    for i=1,159 do Fx.tick(ow);T.eq(parked,true,'growing window holds the script')end
    Fx.tick(ow);T.eq(parked,false);T.eq(resumed,1);T.eq(ow.g3Orb.radius,161)
    local pans={};for i=1,8 do Fx.tick(ow);pans[i]=ow.g3Orb.pan end
    T.eq(pans[4],4);T.eq(pans[8],-4)
    C.g3_special(ctx,0x111A);C.g3_wait_state(ctx);T.eq(parked,true)
    for i=1,183 do Fx.tick(ow);T.eq(parked,true,'blend fade holds the script')end
    Fx.tick(ow);T.eq(parked,false);T.eq(resumed,2);T.eq(ow.g3Orb,nil);T.eq(Fx.pan(ow),nil)
    T.eq(W.encode(save),before,'screen effect does not edit story flags or variables')
  end
  local oldFade,oldCurrent=Music.fadeOutM4a,Music.current
  local song='MAP_SONG';local speed,parked=nil,false
  Music.fadeOutM4a=function(s)speed=s end;Music.current=function()return song end
  local runner={yield=function()parked=true end};local ctx={save={},runner=runner}
  T.eq(M.run(ctx,0x114C),true);T.eq(speed,4);T.eq(parked,true)
  T.eq(runner.waitingCheck(),false);song=nil;T.eq(runner.waitingCheck(),true)
  parked=false;runner.waitingCheck=nil;T.eq(M.run(ctx,0x114C),true);T.eq(parked,false)
  Music.fadeOutM4a,Music.current=oldFade,oldCurrent
end
for _,edition in ipairs{'emerald','firered','leafgreen','gold'}do
  V.set(edition)
  for _,id in ipairs{0x1119,0x111A,0x114C}do T.eq(M.run({},id),false,'other cartridges keep their special dispatch')end
end
local ow={};Fx.orb(ow,1);T.eq(ow.g3Orb.cx,136,'existing Emerald blue centre remains unchanged')
T.eq(M.run({},0x1118),false,'unrelated special is not claimed')
T.finish('RS orb special dispatch, native centres, waitstate, frame cadence, music wait and save isolation')
