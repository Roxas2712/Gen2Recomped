-- Adapted from Uni-Language Ascendant by Roxas2712 (2026), GPL-3.0.
-- Host integration; language profiles and cartridge inputs stay in the mod.
-- Materialize complete glyphs for the fork's native variable-height pages.
-- The original recipes store Hangul halves as adjacent 8x8 tiles, and kana
-- voicing marks as a second tile. Neither is a standalone printable glyph.
local F={}
function F.materialize(files,pages,charmap)
 local out={pages={},charmap={}};local codes={}
 local function source(path)
  local bytes=assert(files[path],'Missing native Asian font page: '..path)
  return love.image.newImageData(love.data.newByteData(bytes))
 end
 local function tile(src,index,dst,x,y)
  local sx=(index%16)*8;local sy=math.floor(index/16)*8
  assert(sx+8<=src:getWidth()and sy+8<=src:getHeight(),('Asian font tile %s outside %sx%s source'):format(index,src:getWidth(),src:getHeight()))
  for yy=0,7 do for xx=0,7 do
   local r,g,b,a=src:getPixel(sx+xx,sy+yy)
   if a>0 then dst:setPixel(x+xx,y+yy,r,g,b,a)end
  end end
 end
 local function save(id,base,count,draw)
  local dst=love.image.newImageData(128,math.max(64,math.ceil(count/16)*16),'rgba8')
  for i=0,count-1 do draw(i,dst,(i%16)*8,math.floor(i/16)*16)end
  local path='assets/fork_fonts/'..id..'.png';files[path]=dst:encode('png'):getString();dst:release()
  out.pages[id]={path=path,base=base,glyphsPerRow=16,glyphWidth=8,glyphHeight=16,advance=8}
 end
 for id,page in pairs(pages.pages or{})do
  local src=source(page.path);assert(src:getWidth()==128 and src:getHeight()==256,'Hangul page geometry changed')
  local base=0x10000+assert(tonumber(id))*256
  save('hangul-'..id,base,256,function(i,dst,x,y)tile(src,i*2,dst,x,y);tile(src,i*2+1,dst,x,y+8);codes[page.base+i*2]=base+i end)
  src:release()
 end
 local sources={}
 for id,page in pairs(pages.singlePages or{})do
  local src=source(page.path);assert(src:getWidth()==128 and src:getHeight()%8==0,'Kana page geometry changed')
  sources[#sources+1]={page=page,image=src,count=src:getWidth()/8*src:getHeight()/8}
  local count=src:getWidth()/8*src:getHeight()/8
  save('kana-'..id,page.base,count,function(i,dst,x,y)tile(src,i,dst,x,y+8);codes[page.base+i]=page.base+i end)
 end
 if next(pages.composite or{})then
  local first,last=math.huge,0
  for code in pairs(pages.composite)do first=math.min(first,code);last=math.max(last,code)end
  local function native(code,dst,x,y)
   for _,s in ipairs(sources)do if code>=s.page.base and code<s.page.base+s.count then return tile(s.image,code-s.page.base,dst,x,y)end end
   error('Missing kana component '..tostring(code))
  end
  save('kana-voiced',first,last-first+1,function(i,dst,x,y)
   local code=first+i;local c=pages.composite[code]
   if c then native(c.base,dst,x,y+8);native(c.mark,dst,x,y);codes[code]=code end
  end)
 end
 for _,s in ipairs(sources)do s.image:release()end
 for seq,code in pairs(charmap or{})do out.charmap[seq]=codes[code]or code end
 assert(next(out.pages),'No native Asian glyph pages')
 return out
end
return F
