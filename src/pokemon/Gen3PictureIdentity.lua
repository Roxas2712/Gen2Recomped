-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Cartridge picture slots are distinct from logical species records.
-- pokefirered ce6406d8: constants/species.h and LoadSpecialPokePic.
local M={UNOWN=201,FIRST_VARIANT=413,VARIANTS=27}
function M.letter(personality)
 local p=tonumber(personality)or 0
 if p~=p or math.abs(p)==math.huge or p%1~=0 then return nil,'invalid personality' end
 p=p%4294967296
 local packed=p%4+4*(math.floor(p/256)%4)+16*(math.floor(p/65536)%4)+64*(math.floor(p/16777216)%4)
 return packed%28
end
function M.slot(species,personality)
 if species~=M.UNOWN then return species end
 local form,why=M.letter(personality);if form==nil then return nil,why end
 return form==0 and species or M.FIRST_VARIANT+form-1
end
function M.base(slot)
 if slot==M.UNOWN then return slot,0 end
 if type(slot)=='number'and slot%1==0 and slot>=M.FIRST_VARIANT and slot<M.FIRST_VARIANT+M.VARIANTS then
  return M.UNOWN,slot-M.FIRST_VARIANT+1
 end
 return slot,nil
end
return M
