-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Original Emerald pocket timing; the host retains inventory and callbacks.
local M={}
local sessions=setmetatable({},{__mode='k'})
function M.remember(owner)
 if owner.scriptRows or owner.pcList or owner.noInput then return end
 local positions=sessions[owner.game.save]or{};sessions[owner.game.save]=positions
 positions[owner.pocket]={index=owner.index,top=owner.top}
end
function M.restore(owner)
 if owner.scriptRows or owner.pcList or owner.noInput then return end
 local positions=sessions[owner.game.save]
 local old=positions and positions[owner.pocket]
 if not old then return end
 owner.index=math.max(1,math.min(#owner.rows,old.index))
 owner.top=math.max(1,math.min(old.top,math.max(1,#owner.rows-7),owner.index))
 if owner.index>owner.top+7 then owner.top=owner.index-7 end
end
function M.start(owner,dir)
 local from=owner.pocket
 M.remember(owner)
 owner:movePocket(dir)
 M.restore(owner)
 owner.emeraldSwitch={from=from,dir=dir,age=0}
 require('src.core.Sound').play(owner.game.data,'Press_AB')
end
function M.update(owner)
 local state=owner.emeraldSwitch
 if not state then return false end
 state.age=state.age+1
 if state.age>=17 then owner.emeraldSwitch=nil end
 return true
end
return M
