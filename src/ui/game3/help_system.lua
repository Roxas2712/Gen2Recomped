-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Observe and borrow the actual native Help modal, including covered draws.
local Native=require('src.compat.gen1.NativeSession')
local Boundary=require('src.compat.gen1.ScriptBoundary')
local Call=require('src.compat.gen1.SourceCall')
local M={}
local states=setmetatable({},{__mode='k'})
local function current()
 local game=Native.game();if not(game and game.stack)then return end
 for i=#game.stack.states,1,-1 do
  local state=game.stack.states[i]
  if states[state]and state:valid()then return state end
 end
end
function M.isOpen()return current()~=nil end
function M.show(game,context)
 local owner,why=Native.game(game);if not owner then return false,why end
 if owner~=Native.game()then return false,'foreign native Help session'end
 if current()then return false,'native Help is already open'end
 local who=Call.owner(M,'show')
 local state;state,why=require('src.ui.Gen3HelpMenu').new(owner,context,who)
 if not state then return false,why end
 states[state]=true;owner.stack:push(state);return true
end
function M.close()local state=current();if not state then return false end;state:close();return true end
function M.draw()return Boundary.invoke('help.draw')end
function M._nativeDraw(state,paint)
 if not state:valid()then return false,'native Help retired'end
 local ok,result=require('src.render.GraphicsScope').call(function()
  return Boundary.dispatch('help.draw',function()
   if not state:valid()then return false,'native Help admission changed'end
   return require('src.core.Game3')._withCallbackOwner(nil,paint)
  end,function()return Call.call(M,'draw')end)
 end)
 if not ok then error(result,0)end;return result
end
local service={}
function service:release()for state in pairs(states)do state:close();states[state]=nil end end
function service:releaseOwner(owner)
 for state in pairs(states)do if state.owner==owner then state:close();states[state]=nil end end
end
function service:poll()
 for state in pairs(states)do if not state:valid()then state:close();states[state]=nil end end
end
require('src.core.game3.asset_stream').register(service);M._service=service
return M
