-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- A deferred start of the actual native arrival, under its existing cover.
-- The Transition keeps the body; weak service slots cannot retain an old world.
local Native=require('src.compat.gen1.NativeSession')
local Version=require('src.core.GameVersion')
local Source=require('src.compat.gen1.SourceCall')
local M={}
local current
local unpack=table.unpack or unpack
local function pack(...)return{n=select('#',...),...}end
local function nativeValid(c)
 local r=c and c.refs;if not(r and r.game and r.world and r.state)then return false end
 local class=package.loaded['src.render.Transition'];if not class then return false end
 local game,world,player=Native.resolve()
 if c.sourceCaptured then
  local G=package.loaded['src.core.Game3']
  if not(G and r.view and G.native(r.view)==game)then return false end
 end
 if game~=r.game or world~=r.world or player~=r.player or world.map~=r.map
  or game.data~=r.data or game.save~=r.save or game.mods~=r.loader or game.stack~=r.stack
  or world.transitioning~=true or world.warpArrivalKind~='fly'
  or Version.get()~=c.edition or r.state.game~=game or r.state.phase~='in'
  or getmetatable(r.state)~=class then return false end
 for _,state in ipairs(game.stack.states or{})do if state==r.state then return true end end
 return false
end
local function ownerValid(c)
 local r=c.refs;local loader=r and r.loader
 local mod=loader and loader.mods and loader.mods[c.who]
 local effects=package.loaded['src.core.game3.field_effects']
 return c.who~=nil and mod~=nil and mod==r.mod and mod.enabled~=false and not mod.failed
  and effects and effects.startFlyIn==r.wrapper
end
local function clear(c)
 local state=c.refs and c.refs.state
 if state and state.nativeFlyArrivalHold==c then state.nativeFlyArrivalHold=nil;state.nativeFlyArrivalBody=nil end
 c.refs=nil
 if current==c then current=nil end
end
local function complete(c)
 if c.failure then error(c.failure,0)end
 if c.done then return unpack(c.result,1,c.result.n)end
 local state=assert(c.refs.state)
 local body=assert(state.nativeFlyArrivalBody,'native arrival body retired')
 -- Consume before calling: even a caught native exception cannot retry it.
 c.done=true;state.nativeFlyArrivalHold=nil;state.nativeFlyArrivalBody=nil
 local result=pack(pcall(body))
 if not result[1]then c.failure=result[2];error(c.failure,0)end
 c.result={n=result.n-1};for i=2,result.n do c.result[i-1]=result[i]end
 return unpack(c.result,1,c.result.n)
end
function M.resume()
 local c=current
 if not nativeValid(c)then if c then clear(c)end;return nil,'no pending native fly arrival'end
 local G=package.loaded['src.core.Game3'];local host=package.loaded['src.mods.Runtime']
 local who=host and host.currentMod or G and G._callbackOwner()
 if not c.dispatching and(not ownerValid(c)or who~=c.who)then return nil,'native fly arrival belongs to its source owner'end
 return complete(c)
end
function M.landing()
 local c=current
 return c~=nil and not c.done and nativeValid(c)and(c.dispatching or ownerValid(c))or false
end
function M.begin(game,world,state,effects,body)
 local c={edition=Version.get(),who=Source.owner(effects,'startFlyIn'),dispatching=true,
  refs=setmetatable({game=game,world=world,player=world.player,map=world.map,data=game.data,
   save=game.save,loader=game.mods,stack=game.stack,state=state,wrapper=effects.startFlyIn},{__mode='v'})}
 if not nativeValid(c)then return body()end
 c.refs.view=require('src.core.Game3').forNative(game);c.sourceCaptured=true
 M.poll()
 assert(not current or current.done,'native fly arrival already pending')
 if current then clear(current)end
 local loader=game.mods;c.refs.mod=c.who and loader and loader.mods and loader.mods[c.who]
 current=c;state.nativeFlyArrivalHold=c;state.nativeFlyArrivalBody=body
 local result=pack(pcall(Source.call,effects,'startFlyIn'))
 c.dispatching=false
 if c.failure then error(c.failure,0)end
 if not result[1]then clear(c);error(result[2],0)end
 if current~=c or not nativeValid(c)then
  if current==c then clear(c)end
  return unpack(result,2,result.n)
 end
 -- Anonymous/retired decorators may observe a start, but cannot hold one.
 if not c.done and not ownerValid(c)then return complete(c)end
 return unpack(result,2,result.n)
end
function M.poll()
 local c=current;if not c then return end
 if not nativeValid(c)then return clear(c)end
 if c.done then return clear(c)end
 if not ownerValid(c)and not c.dispatching then return complete(c)end
end
function M.retireState(state)
 if current and current.refs and current.refs.state==state then clear(current)end
end
function M.release()if current then clear(current)end end
function M.releaseOwner(_,who)
 local c=current
 if c and c.who==who then
  if not c.done and nativeValid(c)then complete(c)end
  clear(c)
 end
end
M.update=M.poll
require('src.core.game3.asset_stream').register(M)
return M
