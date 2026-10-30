-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Emerald's bag palette fades; callbacks run only after the exit is black.
local M={}
function M.open(owner)
 if not owner.noInput then owner.emeraldFade={kind='open',age=0}end
end
function M.close(owner,done)
 if owner.noInput then return false end
 if owner.emeraldClosed or(owner.emeraldFade and owner.emeraldFade.kind=='close')then return true end
 owner.emeraldSwitch=nil
 owner.emeraldFade={kind='close',age=0,done=done}
 return true
end
function M.update(owner)
 local state=owner.emeraldFade
 if not state then return false end
 state.age=state.age+1
 if state.kind=='open'then
  if state.age<23 then return true end
  owner.emeraldFade=nil
  return false
 end
 if state.age>=15 then
  owner.emeraldFade=nil;owner.emeraldClosed=true
  if state.done then state.done()end
 end
 return true
end
function M.opacity(owner)
 local state=owner.emeraldFade
 if not state then return 0 end
 local step=math.floor(state.age/2)
 return state.kind=='open'and math.max(0,16-2*step)/16 or math.min(16,4*step)/16
end
function M.draw(owner)
 local alpha=M.opacity(owner)
 if alpha>0 then
  local g=love.graphics
  g.setColor(0,0,0,alpha);g.rectangle('fill',0,0,240,160);g.setColor(1,1,1,1)
 end
end
return M
