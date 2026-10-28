-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
local Modal=require('src.compat.gen1.NativeModalObservation')
local M={}
function M.isOpen()return Modal.find({'src.ui.Gen3Pokedex','src.ui.Gen3PokedexFRLG'})~=nil end
return M
