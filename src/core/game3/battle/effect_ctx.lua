-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Observe real native effect callbacks. No duplicate effect executor, source
-- stack/pool implementation, manual turn clock or retained native context.
local Battle=require('src.core.game3.battle')
local Version=require('src.core.GameVersion')
local Ids=require('src.compat.gen1.BattleIds')
local M={}
local scopes={}
local unpack=table.unpack or unpack
local function pack(...)return{n=select('#',...),...}end
local function readonly(read)
 return setmetatable({},{__index=read,__newindex=function()error('native effect observations are read-only',2)end})
end
local function valid(lease)
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
 local function state()return valid(lease)and Battle.getState()or nil end
 local function actor(raw)
  local st=state();if not st then return end
  local pos=position(lease.native.battle,raw)
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
  assert(valid(lease),'native effect RNG retired')
  return lease.native.rng(...)
 end
 local opts=readonly(function(_,key)if valid(lease)and key=='phase'then return lease.phase end end)
 lease.public=readonly(function(_,key)
  if not valid(lease)then return end
  local ctx=lease.native
  if key=='adapter'then return adapterView end
  if key=='user'or key=='target'then return actor(ctx[key])end
  if key=='moveId'then return lease.ids:read('moves',ctx.move and ctx.move.id)end
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
 local lease=scopes[#scopes]
 return lease and valid(lease)and descriptor(lease)or nil
end
function M.depth()
 local count=0;for _,lease in ipairs(scopes)do if valid(lease)then count=count+1 end end;return count
end
function M._native(ctx,phase,fn,...)
 if not Version.isGen3()or Battle._screen()~=ctx.battle then return fn(ctx,...)end
 local game=ctx.battle.game
 local lease={native=ctx,phase=phase,edition=Version.get(),ids=Ids.new(ctx.battle.data),
  refs={game,game.data,game.save,game.stack,game.mods}};scopes[#scopes+1]=lease
 local result=pack(pcall(fn,ctx,...))
 assert(scopes[#scopes]==lease,'native effect scope order changed')
 scopes[#scopes]=nil;lease.native,lease.phase,lease.public,lease.refs,lease.ids=nil,nil,nil,nil,nil
 if not result[1]then error(result[2],0)end
 return unpack(result,2,result.n)
end
return M
