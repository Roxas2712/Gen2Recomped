-- CPU-only GB atlas preparation. Recolour rules are adapted from native
-- TileRenderer.lua (Cedric / UNDERdecoded); see LICENSE.md and NOTICE.md.
local M={}
local function dimensions(header)
  if type(header)~='string'or #header<24 or header:sub(1,8)~='\137PNG\13\10\26\10'then return end
  local function u32(i)local a,b,c,d=header:byte(i,i+3);return((a*256+b)*256+c)*256+d end
  local w,h=u32(17),u32(21)
  if w<1 or h<1 or w*h*4>4*1024*1024 then return end
  return w,h
end
M.dimensions=dimensions
function M.run(payload)
  local raw=payload.bytes
  if not raw then
    local info=love.filesystem.getInfo(payload.path,'file')
    assert(info and info.size<=4*1024*1024,'Oversize or missing speculative PNG')
    local head=love.filesystem.read(payload.path,24)
    assert(dimensions(head),'Unsupported speculative PNG')
    raw=assert(love.filesystem.read(payload.path))
  end
  local w,h=dimensions(raw);assert(w and w==payload.width and h==payload.height,'Changed speculative PNG')
  local src=love.image.newImageData(love.filesystem.newFileData(raw,'prefetch.png'))
  if payload.kind=='decode'then return src end
  local out=love.image.newImageData(w,h,'rgba8')
  local R=require('src.render.ShadeRecolour')
  local function region(sx,sy,dx,dy,colors)
    if R.region(src,out,sx,sy,8,8,dx,dy,colors,'tile')then return end
    for y=0,7 do for x=0,7 do
      local r,g,b,a=src:getPixel(sx+x,sy+y)
      if colors and a>0 then
        local c=colors[r>0.83 and 1 or r>0.5 and 2 or r>0.17 and 3 or 4]
        r,g,b=c[1]/255,c[2]/255,c[3]/255
      end
      out:setPixel(dx+x,dy+y,r,g,b,a)
    end end
  end
  for tile=0,w*h/64-1 do
    local x,y=tile%payload.perRow*8,math.floor(tile/payload.perRow)*8
    local colors=payload.palettes and payload.palettes[payload.tilePalettes[tile+1]]
      or payload.colors and payload.colors[tile+1]
    region(x,y,x,y,colors)
  end
  for _,a in ipairs(payload.aliases or {})do
    region(a.tile%payload.perRow*8,math.floor(a.tile/payload.perRow)*8,
      a.alias%payload.perRow*8,math.floor(a.alias/payload.perRow)*8,
      payload.palettes and payload.palettes[a.palette]or a.colors)
  end
  if src.release then src:release()end
  return out
end
return M
