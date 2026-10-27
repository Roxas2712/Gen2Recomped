-- Adapted from Uni-Language Ascendant by Roxas2712 (2026), GPL-3.0.
-- Respect the cartridge profile's entry layout, including expanded PT-BR FRLG.
local D={}
function D.read(F,pointer,name,decode)
 local out={}
 if not F.POKEDEX_ENTRIES then return out end
 local description=F.POKEDEX_TEXT_OFFSET or F.POKEDEX_DESCRIPTION_OFFSET or 16
 for index=1,386 do
  local at=F.POKEDEX_ENTRIES+index*F.POKEDEX_ENTRY_SIZE
  local first=pointer(at+description)
  local second=F.POKEDEX_ENTRY_SIZE>=36 and pointer(at+description+4)
  out[index]={category=name(at,F.POKEDEX_NAME_LENGTH or 12),
   text=first and decode(first,false,4096)or nil,
   text2=second and decode(second,false,4096)or nil}
 end
 return out
end
return D
