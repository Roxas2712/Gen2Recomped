-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Constructor-bound native modal observations. Weak owner slots avoid a
-- weak-key/value/stack cycle keeping a retired world alive under LuaJIT.
local Native=require('src.compat.gen1.NativeSession')
local Version=require('src.core.GameVersion')
local M={}
local records=setmetatable({},{__mode='k'})
function M.capture(state,game)
 if Version.isGen3()and Native.game()==game and game.stack then
  records[state]={edition=Version.get(),hasMods=game.mods~=nil,
   refs=setmetatable({game,game.data,game.save,game.stack,game.mods},{__mode='v'})}
 end
 return state
end
function M.find(classes)
 local game=Native.game();if not(game and game.stack)then return end
 for i=#game.stack.states,1,-1 do
  local state=game.stack.states[i];local class=getmetatable(state)
  local matching=false
  for _,name in ipairs(classes)do
   local nested=type(name)=='table'
   local module=package.loaded[nested and name[1]or name]
   local candidate=module
   if nested then candidate=module and module[name[2]]end
   if candidate~=nil and class==candidate then matching=true;break end
  end
  if matching then
   local row=records[state];local r=row and row.refs
   if r and state.game==game and row.edition==Version.get()and r[1]==game
    and r[2]~=nil and r[2]==game.data and r[3]~=nil and r[3]==game.save
    and r[4]==game.stack and r[5]==game.mods and row.hasMods==(game.mods~=nil)then return state end
  end
 end
end
return M
