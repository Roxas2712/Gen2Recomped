-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local Arrival=require('src.world.Gen3FlyArrival')
local Effects=require('src.core.game3.field_effects');local Field=require('src.core.game3.field')
local Fade=require('src.ui.game3.fade');local Transition=require('src.render.Transition')
local OW=require('src.world.OverworldController');local G=require('src.core.Game3')
local Seams=require('src.mods.ModSeams');local Host=require('src.mods.Runtime')
local Stream=require('src.core.game3.asset_stream');local Sound=require('src.core.Sound')
local savedGame=package.loaded['src.core.Game'];local play=Sound.play;local base=Effects.startFlyIn
local count,fail=0,false
Sound.play=function(_,name)T.eq(name,'Fly');count=count+1;if fail then error('native arrival sound failed')end end
local function fixture(edition,wrapper)
 Arrival.release();G.release();Host.currentMod=nil
 local f=require('tools.native-field.warp-fixture').new(edition);local game,world=f.game,f.ow
 package.loaded['src.core.Game']=game;game.mods=f.loader
 local restore
 for i=1,100 do
  local key,value=debug.getupvalue(OW.startWarpTo,i);if not key then break end
  if key=='Game'then debug.setupvalue(OW.startWarpTo,i,game);restore=function()debug.setupvalue(OW.startWarpTo,i,value)end;break end
 end
 assert(restore)
 setmetatable(game.stack,{__index=require('src.core.StateStack')})
 world.startWarpTo=OW.startWarpTo
 function world:frlgBehaviours()return false end
 function world:noteGen2Spawn()end
 function world:setMap(id,x,y,facing)f.destination={id,x,y,facing};f:arrive()end
 game.data.transitions={warp_fade={frames=1,framesIn=0}}
 Effects.startFlyIn=base
 if wrapper then Seams.run('warp',function()Effects.startFlyIn=wrapper end)end
 local done=0;world.arriveWarp='fly';world:startWarpTo(f.dest,1,2,'down',function()done=done+1 end)
 local state=game.stack:top();T.eq(getmetatable(state),Transition)
 f.state=state;f.done=function()return done end
 function f:closeCase()
  Arrival.release();Effects.startFlyIn=base;restore();self:close();G.release();Host.currentMod=nil
 end
 return f
end
for _,edition in ipairs{'firered','leafgreen','emerald','ruby','sapphire'}do
 local f=fixture(edition);local before=count
 f.state:update(1/60)
 T.eq(count,before+1);T.eq(f.done(),1);T.eq(f.game.stack:top(),f.ow,'unwrapped zero-frame arrival still finishes in its native tick')
 T.eq(Field._flyLanding,false);f:closeCase()
 local callbacks=0
 f=fixture(edition,function(...)callbacks=callbacks+1;base(...);base(...)end);before=count
 f.state:update(1/60);T.eq(callbacks,1);T.eq(count,before+1);T.eq(f.done(),1)
 T.eq(f.game.stack:top(),f.ow,'synchronous source base preserves default native timing');f:closeCase()
 -- A real loader-attributed wrapper retains only this actual arrival start.
 f=fixture(edition,function()callbacks=callbacks+1 end);before=count
 f.state:update(1/60)
 T.eq(f.game.stack:top(),f.state);T.eq(f.state.phase,'in');T.eq(f.state.t,0)
 T.eq(Field._flyLanding,true);T.eq(f.state:alpha(),1);T.eq(Fade.t,16,'held native cover stays opaque')
 T.eq(f.ow.transitioning,true);T.eq(f.done(),0);T.eq(count,before)
 local save=require('src.link.Json').encode(f.game.save)
 for i=1,12 do f.state:update(1/60);T.eq(f.state.t,0,'no second arrival/fade clock while deferred')end
 T.eq(count,before);T.eq(require('src.link.Json').encode(f.game.save),save)
 T.eq(base(),nil,'outside caller cannot acquire the deferred source phase');T.eq(count,before)
 G._withCallbackOwner('peer',base);T.eq(count,before,'another owner cannot start the landing')
 G._withCallbackOwner('warp',base);G._withCallbackOwner('warp',base)
 T.eq(count,before+1);T.eq(Field._flyLanding,false);T.eq(f.state.nativeFlyArrivalHold,nil)
 f.state:update(1/60);T.eq(f.done(),1);T.eq(f.ow.transitioning,false);T.eq(f.game.stack:top(),f.ow)
 T.eq(base(),nil,'retired native phase cannot start another effect');f:closeCase()
 -- Owner removal releases this native cover through its original body once.
 f=fixture(edition,function()end);before=count;f.state:update(1/60)
 Arrival:releaseOwner('peer');T.eq(count,before);T.eq(Field._flyLanding,true)
 Arrival:releaseOwner('warp');T.eq(count,before+1);T.eq(Field._flyLanding,false)
 f.state:update(1/60);T.eq(f.done(),1);f:closeCase()
 f=fixture(edition,function()end);before=count;f.state:update(1/60)
 f.loader.mods.warp.enabled=false
 T.eq(Field._flyLanding,false);T.eq(count,before,'a landing observation cannot play a native effect')
 f.state:update(1/60);T.eq(count,before+1);T.eq(f.done(),1,'native update falls back after owner retirement');f:closeCase()
 for _,key in ipairs{'data','save','mods','stack'}do
  f=fixture(edition,function()end);before=count;f.state:update(1/60)
  local old=f.game[key];f.game[key]={}
  T.eq(Field._flyLanding,false);Arrival.poll();T.eq(f.state.nativeFlyArrivalHold,nil)
  f.game[key]=old;G._withCallbackOwner('warp',base);T.eq(count,before,key..' replacement cannot execute stale arrival')
  f:closeCase()
 end
 f=fixture(edition,function()end);before=count;f.state:update(1/60)
 G.release();T.eq(Field._flyLanding,false);Arrival.poll();T.eq(f.state.nativeFlyArrivalHold,nil)
 T.eq(count,before,'retired source facade cannot start an effect');f:closeCase()
 f=fixture(edition,function()end);before=count;f.state:update(1/60)
 f.game.stack:pop();T.eq(Field._flyLanding,false);T.eq(f.state.nativeFlyArrivalHold,nil)
 G._withCallbackOwner('warp',base);T.eq(count,before,'actual stack cancellation drops its body');f:closeCase()
 f=fixture(edition,function()Stream.shutdown()end);before=count;f.state:update(1/60)
 T.eq(count,before);T.eq(f.done(),1,'reentrant service reset cannot retain or revive the arrival')
 T.eq(f.state.nativeFlyArrivalHold,nil);f:closeCase()
 f=fixture(edition,function()G.release()end);before=count;f.state:update(1/60)
 T.eq(count,before);T.eq(f.done(),1,'source facade reset during a start cancels its old body');f:closeCase()
 f=fixture(edition,function()pcall(base);pcall(base)end);before=count;fail=true
 T.raises(function()f.state:update(1/60)end,'native arrival sound failed')
 fail=false;T.eq(count,before+1,'caught native error is never retried');T.eq(f.state.nativeFlyArrivalHold,nil)
 f:closeCase()
end
-- Anonymous callbacks cannot leave a native phase held after their call.
local f=fixture('emerald');local before=count
Effects.startFlyIn=function()end
f.state:update(1/60);T.eq(count,before+1);T.eq(f.done(),1);f:closeCase()
-- An ordinary Gen2 flight never invokes the source-facing arrival API.
f=fixture('crystal');before=count
Effects.startFlyIn=function()error('foreign arrival callback')end
f.state:update(1/60);T.eq(count,before+1);T.eq(f.done(),1);f:closeCase()
Effects.startFlyIn=base;Sound.play=play;package.loaded['src.core.Game']=savedGame
T.finish('native fly arrival deferral, opaque cover, once-only body and cohort retirement')
