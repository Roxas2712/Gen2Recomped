-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- RS-only specials retain distinct IDs when no Emerald name was matched.
local M={}
function M.run(ctx,id)
  local version=require('src.core.GameVersion').get()
  if version~='ruby'and version~='sapphire'then return false end
  if id==0x1119 then -- native 281, sub_80818A4
    if ctx.overworld then
      local vars=ctx.save.gen3Vars or{}
      require('src.world.Gen3ScreenFx').orb(ctx.overworld,vars[0x800D]or 0,'rs')
    end
  elseif id==0x111A then -- native 282, sub_80818FC
    if ctx.overworld then require('src.world.Gen3ScreenFx').fadeOutOrb(ctx.overworld)end
  elseif id==0x114C then -- native 332, sub_8081924
    local Music=require('src.core.Music')
    Music.nativeCommand(ctx.game.data,'fadeoutbgm',4,nil,ctx)
    if Music.current()~=nil and ctx.runner then
      ctx.runner.waitingCheck=function()return Music.current()==nil end
      ctx.runner:yield()
    end
  else return false end
  return true
end
return M
