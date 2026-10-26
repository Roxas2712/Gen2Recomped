-- Compile localized pixel labels into native tile data once, before caching.
-- Tiles are copied, never edited in place: unrelated maps retain their art.
return function(files,game)
 if game~='ruby' and game~='sapphire' then return {} end
 local K=require('src.import.gba.rse.boot_gfx')
 local W=require('src.import.LuaWriter')
 local root='data/generated/gba/rse/pokedex/'
 local man=assert(loadstring(assert(files[root..'manifest.lua'])))()
 local gfx=assert(files[man.gfx.menu.path])
 local map=assert(files[man.maps.info.path])
 local original,w,h=K.bakeText(gfx,map,32,20)
 assert(w==256 and h==160 and #gfx%32==0)
 local pixels={};for i,v in ipairs(original) do pixels[i]=v end
 -- Small pixel alphabet for the native Pokédex chrome, authored for this mod.
 local font={
  A={'0110','1001','1001','1111','1001','1001','1001'},
  L={'1000','1000','1000','1000','1000','1000','1111'},
  T={'1111','0110','0110','0110','0110','0110','0110'},
  P={'1110','1001','1001','1110','1000','1000','1000'},
  E={'1111','1000','1000','1110','1000','1000','1111'},
  S={'0111','1000','1000','0110','0001','0001','1110'},
  O={'0110','1001','1001','1001','1001','1001','0110'},
  G={'0110','1001','1000','1011','1001','1001','0110'},
  ['.']={'0000','0000','0000','0000','0000','0100','0100'},
 }
 local changed={}
 local function set(x,y,c)
  local i=y*w+x+1
  pixels[i]=math.floor(original[i]/16)*16+c
  changed[math.floor(y/8)*32+math.floor(x/8)]=true
 end
 local function clear(x,y,width,height,c)
  for py=y,y+height-1 do for px=x,x+width-1 do set(px,py,c) end end
 end
 local function label(text,x,y,step,fg,shadow)
  for n=1,#text do
   local rows=assert(font[text:sub(n,n)])
   if shadow then
    for py,row in ipairs(rows) do for px=1,#row do
     if row:sub(px,px)=='1' then set(x+(n-1)*step+px,y+py,shadow) end
    end end
   end
   for py,row in ipairs(rows) do for px=1,#row do
    if row:sub(px,px)=='1' then set(x+(n-1)*step+px-1,y+py-1,fg) end
   end end
  end
 end
 clear(104,60,24,10,1);label('ALT.',104,61,5,15,3)
 clear(104,76,24,10,1);label('PESO',104,77,5,15,3)
 clear(20,94,22,9,1);label('PAG.',20,95,6,5)
 set(28,94,5);set(29,93,5) -- acute accent on Á
 local chunks={gfx};local count=#gfx/32
 local entries={};for i=0,#map/2-1 do entries[i]=map:byte(i*2+1)+map:byte(i*2+2)*256 end
 local function tileData(index,variant)
  local tx,ty=index%32,math.floor(index/32)
  local source=entries[index]
  local out={}
  for y=0,7 do for x=0,7,2 do
   local function pixel(px)
    local screen=(ty*8+y)*w+tx*8+px+1
    if variant and pixels[screen]==original[screen] then
     local sx=math.floor(source/1024)%2==1 and 7-px or px
     local sy=math.floor(source/2048)%2==1 and 7-y or y
     local b=gfx:byte((source%1024+1)*32+sy*4+math.floor(sx/2)+1)
     return math.floor(b/2^(4*(sx%2)))%16
    end
    return pixels[screen]%16
   end
   out[#out+1]=string.char(pixel(x)+16*pixel(x+1))
  end end
  return table.concat(out)
 end
 local indices={};for i in pairs(changed) do indices[#indices+1]=i end;table.sort(indices)
 for _,i in ipairs(indices) do
  local flip=i==0x165 or i==0x185
  assert(count+(flip and 1 or 0)<1024,'Localized Pokédex tile limit')
  chunks[#chunks+1]=tileData(i,false)
  if flip then chunks[#chunks+1]=tileData(i,true) end
  entries[i]=math.floor(entries[i]/4096)*4096+count
  count=count+(flip and 2 or 1)
 end
 local out={};for i=0,#map/2-1 do out[#out+1]=string.char(entries[i]%256,math.floor(entries[i]/256)) end
 gfx,map=table.concat(chunks),table.concat(out)
 files[man.gfx.menu.path],files[man.maps.info.path]=gfx,map
 man.gfx.menu.bytes=#gfx
 local idx=K.bakeText(gfx,map,32,20)
 for variant,path in pairs(man.layers.info.variants) do
  local pal={};for i,c in ipairs(man.palettes[variant]) do pal[i-1]=c end
  files[path]=K.encodeIndexed(w,h,idx,pal,true)
 end
 files[root..'manifest.lua']=W.encode(man)
 return {'pokedex.height:ALT.','pokedex.weight:PESO','pokedex.page:PÁG.'}
end
