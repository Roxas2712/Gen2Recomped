-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Bounded native presentation facts. Rules/action/theme capabilities are not
-- inferred from this view; the admitted native battle remains authoritative.
local Battle=require('src.core.game3.battle')
local Native=require('src.compat.gen1.NativeSession')
local Text=require('src.battle.Gen3SafariText')
local Version=require('src.core.GameVersion')
local M={}
function M.of(state)
 local b=state~=nil and Battle._screen(state)or nil
 local game=Native.game();local edition=Version.get()
 if not(b and game and b.game==game and b.gen3Safari and Text.spec(game.data,edition))then
  return nil,'no admitted native Safari presentation profile'
 end
 local refs=setmetatable({state,b,game.data,b.gen3Safari},{__mode='v'})
 local function valid()
  local view,screen=refs[1],refs[2];local g=Native.game()
  return view~=nil and screen~=nil and Battle._screen(view)==screen
   and g~=nil and screen.game==g and g.data==refs[3]and screen.gen3Safari==refs[4]
   and Version.get()==edition and Text.spec(g.data,edition)~=nil
 end
 local strings=setmetatable({},{__index=function(_,key)
  if valid()and key=='safariPrompt'then return Text.PREFIX..'prompt'end
 end,__newindex=function()error('native battle profile is read-only',2)end})
 return setmetatable({},{__index=function(_,key)
  if key=='open'then return valid()end
  if not valid()then return end
  if key=='strings'then return strings end
  if key=='id'then return edition end
  if key=='family'then return Version.layout(edition)end
 end,__newindex=function()error('native battle profile is read-only',2)end})
end
return M
