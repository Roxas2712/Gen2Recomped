-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Source capture seam over the shared native checkpoint owner. The source
-- signature includes a progress record; native graph capture reads the live
-- party relationships and uses the same caller-supplied plain-data copier.
-- Validation/reconstruction stay with src.core.Checkpoint; no second format
-- or restore controller is exposed here.
local Native=require('src.core.CheckpointBattle')
local M={}
function M.capture(game,battle,progress,copy)
  if copy==nil and type(progress)=='function'then copy=progress end
  return Native.capture(game,battle,assert(copy,'checkpoint copier is required'))
end
return M
