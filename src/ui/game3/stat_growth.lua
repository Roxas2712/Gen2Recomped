-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
local Modal=require('src.compat.gen1.NativeModalObservation')
local M={}
function M.isOpen()return Modal.find({{'src.battle.BattleState','StatBox'}})~=nil end
return M
