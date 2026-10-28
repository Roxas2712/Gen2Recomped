-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Numeric interface facts only, not cartridge bytes or program code.
-- pret/pokeemerald 731ad5bfd6e6f265508d0efcca0ba42f9dcf5881
-- pret/pokeruby 5784633ce4ef7ade1a7f2d2d0c288e3d5e6cdd7f
-- Both: include/constants/metatile_labels.h, Building TV Off/On definitions.
local M={}
function M.metatileLabels(edition)
 if edition=='emerald'or edition=='ruby'or edition=='sapphire'then
  return{METATILE_Building_TV_Off=0x002,METATILE_Building_TV_On=0x003}
 end
end
return M
