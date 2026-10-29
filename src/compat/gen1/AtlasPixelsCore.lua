-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- CPU-only atlas construction. No graphics objects or main-state module data.
local Pixels=require('src.compat.gen1.AtlasPixels')
local M={}
function M.run(payload)
  return Pixels._toCore(Pixels.new(payload.pair,payload.layout))
end
return M
