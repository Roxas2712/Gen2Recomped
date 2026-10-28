-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Read the same imported PP palette as Gen3SummaryLayout. The native summary
-- controller keeps its art and navigation; this is a detached colour query.
local M={}
function M.manifest()
 local game=require('src.compat.gen1.NativeSession').game()
 local summary=game and game.data and game.data.constants and game.data.constants.gen3Summary
 local parts=summary and summary.parts
 if not(parts and parts.palette and parts.textColors)then
  return nil,'native summary palette is not present in this cartridge cache'
 end
 local rows={}
 for index=9,12 do
  local a,b=parts.textColors[index*3+2],parts.textColors[index*3+3]
  local ink=type(a)=='number'and parts.palette[128+a]
  local shadow=type(b)=='number'and parts.palette[128+b]
  if ink and shadow then
   rows[index]={fg={ink[1]*255,ink[2]*255,ink[3]*255},
    shadow={shadow[1]*255,shadow[2]*255,shadow[3]*255}}
  end
 end
 return{moveTextColors=rows,native=true}
end
return M
