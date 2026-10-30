-- Fixed full-table framing, including original-view overlays. By Roxas2712.
local M={}
function M.fit(width,height,slot,available,guest,full,portrait,integer)
 portrait=full or portrait or height>(guest=='gbc'and 144 or 160)
 local logicalWidth,logicalHeight=width,height
 if portrait then logicalWidth=guest=='gbc'and 192 or 256;logicalHeight=guest=='gbc'and 285 or 388 end
 local scale=math.min(slot/logicalWidth,available/logicalHeight)
 if integer and scale>=1 then scale=math.floor(scale)end
 return scale,(slot-width*scale)/2,(available-height*scale)/2,portrait
end
return M
