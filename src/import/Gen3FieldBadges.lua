-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Shared import/admission facts; this module remains an extraction input.
local Badges={}
local hoenn={CUT=1,FLASH=2,ROCK_SMASH=3,STRENGTH=4,SURF=5,FLY=6,DIVE=7,WATERFALL=8}
-- FRLG CursorCB_FieldMove checks FLAG_BADGE01_GET + fieldMove, using
-- its own FIELD_MOVE_FLASH..WATERFALL enum (party_menu.h), not Hoenn's.
local kanto={FLASH=1,CUT=2,FLY=3,STRENGTH=4,SURF=5,ROCK_SMASH=6,WATERFALL=7}
function Badges.number(edition,move)
  if edition=='firered'or edition=='leafgreen'then return kanto[move]end
  return hoenn[move]
end
function Badges.flag(data,move,edition)
  local constants=data and data.constants or{}
  local entry=constants.gen3FieldMoves and constants.gen3FieldMoves[move]
  local flag=entry and entry.badgeFlag
  if flag==nil or (edition~='firered'and edition~='leafgreen')then return flag end
  local old,new=hoenn[move],kanto[move]
  local badges=constants.gen3BadgeFlags or{}
  -- Existing imports advertised the correct Kanto badge block with the
  -- Hoenn move order. Repair only that recognized legacy record in the
  -- read-only view; retain absent gates and explicitly customized flags.
  if old and new and old~=new and entry.badge==old
     and flag==(badges[old]or(0x820+old-1))then
    return badges[new]or(0x820+new-1)
  end
  return flag
end
return Badges
