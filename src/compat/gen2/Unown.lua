-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
local U={}
local forms={};for n=1,26 do forms[n]=true end
function U.monLetter(mon)
  if not mon or (mon.species~='UNOWN' and mon.species~='SPECIES_201' and mon.species~=201)then return nil end
  local letter=mon.unownLetter
  if type(letter)=='string'then letter=letter:upper():byte()-64 end
  if type(letter)=='number' and letter%1==0 and letter>=1 and letter<=26 then return letter end
  -- The native form selector owns the DV encoding. Its forms table is only
  -- an availability check; all 26 forms are valid for this query.
  return require('src.pokemon.Sprites').formIndex({forms=forms},mon)
end
return U
