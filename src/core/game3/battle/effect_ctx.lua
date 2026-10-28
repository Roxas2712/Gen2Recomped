-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Observe real native effect callbacks. No duplicate effect executor, source
-- stack/pool implementation, manual turn clock or retained native context.
local Battle=require('src.core.game3.battle')
local Version=require('src.core.GameVersion')
local Ids=require('src.compat.gen1.BattleIds')
local M={}
local CoroutineScopes=require('src.compat.gen1.CoroutineScopes')
local scopes=CoroutineScopes.new()
local unpack=table.unpack or unpack
local function pack(...)return{n=select('#',...),...}end
local function readonly(read)
 return setmetatable({},{__index=read,__newindex=function()error('native effect observations are read-only',2)end})
end
local function valid(lease)
 if not lease or not lease.frame or lease.frame.closed then return false end
 -- A retained descriptor/RNG closure borrows only the currently visible
 -- native effect ancestry. Suspended siblings have no authority here.
 local frame=scopes:find('effect')
 while frame and frame~=lease.frame do frame=frame.parent end
 if not frame then return false end
 local ctx=lease.native;local screen=ctx and ctx.battle
 local r=lease.refs;local game=screen and screen.game
 return game and r and r[1]==game and r[2]==game.data and r[3]==game.save
  and r[4]==game.stack and r[5]==game.mods and lease.edition==Version.get()
  and lease.ids:valid()and Battle._screen()==screen and game.stack:top()==screen
end
local function position(screen,raw)
 for pos=0,3 do
  local value
  if screen.battlerAt then value=screen:battlerAt(pos)
  elseif pos==0 then value=screen.player elseif pos==1 then value=screen.enemy end
  if value==raw then return pos end
 end
end
local function descriptor(lease)
 if lease.public then return lease.public end
 -- A public descriptor cannot root an abandoned coroutine, its effect stack
 -- or its controller. The running native invocation owns the strong lease.
 local refs=setmetatable({lease},{__mode='v'})
 local function currentLease()
  local active=refs[1];return active and valid(active)and active or nil
 end
 local function state()return currentLease()and Battle.getState()or nil end
 local function actor(raw)
  local active=currentLease();local st=active and Battle.getState();if not st then return end
  local pos=position(active.native.battle,raw)
  return pos~=nil and st.battlers[pos]or nil
 end
 local adapter={}
 function adapter:foeOf(who)
  local st=state();if not st then return nil,'native effect retired'end
  if type(who)~='table'then return nil,'foreign effect battler'end
  local pos
  for i=0,3 do if st.battlers[i]==who then pos=i;break end end
  if pos==nil then return nil,'foreign effect battler'end
  local opposite=pos%2==0 and pos+1 or pos-1
  return st.battlers[opposite]or st.battlers[pos%2==0 and 1 or 0]
 end
 local adapterView=readonly(function(_,key)
  if key=='foeOf'then return adapter.foeOf end
  if key=='state'then return state()end
 end)
 local rng=function(...)
  local active=assert(currentLease(),'native effect RNG retired')
  return active.native.rng(...)
 end
 local opts=readonly(function(_,key)
  local active=currentLease();if active and key=='phase'then return active.phase end
 end)
 lease.public=readonly(function(_,key)
  local active=currentLease();if not active then return end
  local ctx=active.native
  if key=='adapter'then return adapterView end
  if key=='user'or key=='target'then return actor(ctx[key])end
  if key=='moveId'then return active.ids:read('moves',ctx.move and ctx.move.id)end
  if key=='move'then
   -- Current registry data, detached on demand. Never lend native animation
   -- rows or callback functions as writable effect-controller state.
   local out={};for name,value in pairs(ctx.move or{})do
    if type(value)=='string'or type(value)=='number'or type(value)=='boolean'then out[name]=value end
   end
   return out
  end
  if key=='rng'then return rng end
  if key=='opts'then return opts end
 end)
 return lease.public
end
function M.current()
 local frame=scopes:find('effect');local lease=frame and frame.value
 return lease and valid(lease)and descriptor(lease)or nil
end
function M.depth()
 local count=0;local frame=scopes:find('effect')
 while frame do
  if not frame.closed and valid(frame.value)then count=count+1 end
  frame=frame.parent
 end
 return count
end
function M._native(ctx,phase,fn,...)
 if not Version.isGen3()or Battle._screen()~=ctx.battle then return fn(ctx,...)end
 local game=ctx.battle.game
 local lease={native=ctx,phase=phase,edition=Version.get(),ids=Ids.new(ctx.battle.data),
  refs={game,game.data,game.save,game.stack,game.mods}}
 local frame=scopes:push('effect',lease);lease.frame=frame
 local result=pack(pcall(fn,ctx,...))
 local retired=frame.closed or CoroutineScopes.retired()
 scopes:close(frame);lease.native,lease.phase,lease.public,lease.refs,lease.ids,lease.frame=nil,nil,nil,nil,nil,nil
 if not result[1]then error(result[2],0)end
 if retired then error('native effect phase retired while suspended',0)end
 return unpack(result,2,result.n)
end
return M
