-- RS summary labels are pixels in the shared background tiles, not ROM text.
-- Replace only the dedicated label ranges; both move pages share these tiles.
return function(files,game)
 if game~='ruby' and game~='sapphire' then return {} end
 local K=require('src.import.gba.rse.boot_gfx')
 local W=require('src.import.LuaWriter')
 local root='data/generated/gba/rse/summary/'
 local man=assert(loadstring(assert(files[root..'manifest.lua'])))()
 assert(man.layout=='rs','Expected RS summary layout')
 local gfx=assert(files[man.gfx])
 local font={
  A={'0110','1001','1001','1111','1001','1001','1001'},
  B={'1110','1001','1001','1110','1001','1001','1110'},
  C={'0111','1000','1000','1000','1000','1000','0111'},
  D={'1110','1001','1001','1001','1001','1001','1110'},
  E={'1111','1000','1000','1110','1000','1000','1111'},
  F={'1111','1000','1000','1110','1000','1000','1000'},
  G={'0111','1000','1000','1011','1001','1001','0111'},
  H={'1001','1001','1001','1111','1001','1001','1001'},
  I={'1110','0100','0100','0100','0100','0100','1110'},
  L={'1000','1000','1000','1000','1000','1000','1111'},
  M={'1001','1111','1111','1001','1001','1001','1001'},
  O={'0110','1001','1001','1001','1001','1001','0110'},
  P={'1110','1001','1001','1110','1000','1000','1000'},
  R={'1110','1001','1001','1110','1010','1001','1001'},
  S={'0111','1000','1000','0110','0001','0001','1110'},
  T={'1111','0100','0100','0100','0100','0100','0100'},
  ['.']={'0000','0000','0000','0000','0000','0110','0110'},
  ['Ã']={'0101','1010','0110','1001','1111','1001','1001'},
  ['Ç']={'0111','1000','1000','1000','0111','0010','0100'},
  ['Ó']={'0010','0100','0110','1001','1001','1001','0110'},
 }
 local rows={{108,8,'GOLPES'},{116,4,'EFEITO'},{120,8,'DESCRIÇÃO'},
  {144,3,'EST.'},{156,4,'FITAS'},{164,5,'ATRIB.'},{176,5,'PERFIL'},
  {181,4,'HABIL.'},{185,7,'MEMÓRIA'}}
 local chars=require('src.ui.game3.frlg_font').utf8Chars
 local labels={}
 for _,row in ipairs(rows) do
  local first,count,text=row[1],row[2],row[3];local width=count*8
  assert((first+count)*32<=#gfx,'Summary label tile range')
  local pixels={};for i=1,width*8 do pixels[i]=7 end
  local ink={};local n=0
  for ch in chars(text) do
   local glyph=assert(font[ch],ch)
   for y,bits in ipairs(glyph) do for x=1,4 do
    if bits:sub(x,x)=='1' then ink[#ink+1]={n*5+x-1,y-1} end
   end end
   n=n+1
  end
  assert(n*5<=width,'Summary label too wide: '..text)
  for _,p in ipairs(ink) do pixels[(p[2]+1)*width+p[1]+2]=6 end
  for _,p in ipairs(ink) do pixels[p[2]*width+p[1]+1]=2 end
  local out={}
  for tile=0,count-1 do for y=0,7 do for x=0,7,2 do
   local at=y*width+tile*8+x+1
   out[#out+1]=string.char(pixels[at]+16*pixels[at+1])
  end end end
  gfx=gfx:sub(1,first*32)..table.concat(out)..gfx:sub((first+count)*32+1)
  labels[#labels+1]=text
 end
 files[man.gfx]=gfx
 local pal={};for i,c in ipairs(man.palettes.bg) do pal[i-1]=c end
 for key,layer in pairs(man.layers) do
  local idx,w,h=K.bakeText(gfx,assert(files[man.maps[key].path]),30,20)
  files[layer.png]=K.encodeIndexed(w,h,idx,pal,key~='common')
 end
 files[root..'manifest.lua']=W.encode(man)
 return labels
end
