-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- PokedexNestIconGFX is one raw 2bpp tile, separate from the compressed
-- Pokegear sprite sheet. Its transparent index is the same as source Gen1.
local Writer=require('src.import.ImageWriter')
local M={REVISION=1}
function M.nest(e)
 local sym=e:symbol('PokedexNestIconGFX')
 if not(sym and e.rom)then return nil end
 local ok,raw=pcall(e.rom.bytes,e.rom,sym.bank,sym.address,16)
 if not ok or type(raw)~='table' or #raw~=16 then return nil end
 local image=Writer.decode2bpp(raw,8,8,true)
 e:saveImage(image,'ui/town_map_nest.png')
 return {path='assets/generated/ui/town_map_nest.png'}
end
return M
