-- The pinned summary compositor selects frames without applying OAM flips.
-- Bake those animation flags into private frames; keep cartridge/cache bytes intact.
local M={}
function M.expand(entry,source)
  local frames,variants,seen=entry.frames,{},{}
  local out={};for k,v in pairs(entry)do out[k]=v end;out.anims={}
  for i,anim in ipairs(entry.anims)do
    out.anims[i]={}
    for j,command in ipairs(anim)do
      local c={};for k,v in pairs(command)do c[k]=v end
      if c.op=='frame'and(c.hFlip or c.vFlip)then
        local key=c.frame..':'..tostring(c.hFlip)..':'..tostring(c.vFlip)
        if not seen[key]then
          seen[key]=frames;variants[#variants+1]={frame=c.frame,h=c.hFlip,v=c.vFlip,index=frames}
          frames=frames+1
        end
        c.frame=seen[key];c.hFlip,c.vFlip=nil,nil
      end
      out.anims[i][j]=c
    end
  end
  if #variants==0 then return entry,source,false end
  assert(source:getWidth()==entry.w and source:getHeight()==entry.h*entry.frames,'Native cursor frame strip mismatch')
  local pixels=love.image.newImageData(entry.w,entry.h*frames)
  pixels:paste(source,0,0,0,0,source:getDimensions())
  for _,v in ipairs(variants)do for y=0,entry.h-1 do for x=0,entry.w-1 do
    pixels:setPixel(x,v.index*entry.h+y,source:getPixel(v.h and entry.w-1-x or x,
      v.frame*entry.h+(v.v and entry.h-1-y or y)))
  end end end
  out.frames=frames
  return out,pixels,true
end
return M
