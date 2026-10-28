-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Query the actual native bag, including its nested TM/berry pockets.
local Modal=require('src.compat.gen1.NativeModalObservation')
local M={}
function M.isOpen()return Modal.find({'src.ui.Gen3BagMenu'})~=nil end
return M
