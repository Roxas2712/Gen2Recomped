-- Authored title lettering, baked once into the native indexed sprite sheets.
-- Animation, backgrounds, palettes and copyright frames remain ROM-derived.
return function(files,game)
 local editions={ruby='RUBI',sapphire='SAFIRA',emerald='ESMERALDA'}
 if not editions[game] then return {} end
 local K=require('src.import.gba.rse.boot_gfx')
 local PNG=require('src.core.game3.indexed_png')
 local base=require('src.core.game3.dataset').cache()
 local root='data/generated/gba/title/'
 local man=assert(loadstring(assert(files[root..'manifest.lua'] or base:read(root..'manifest.lua'))))()
 local font={
  A={'01110','11011','11011','11111','11011','11011','11011'},
  B={'11110','11011','11011','11110','11011','11011','11110'},
  D={'11110','11011','11011','11011','11011','11011','11110'},
  E={'11111','11000','11000','11110','11000','11000','11111'},
  F={'11111','11000','11000','11110','11000','11000','11000'},
  I={'11111','01110','01110','01110','01110','01110','11111'},
  L={'11000','11000','11000','11000','11000','11000','11111'},
  M={'10001','11011','11111','10101','10101','10001','10001'},
  O={'01110','11011','11011','11011','11011','11011','01110'},
  P={'11110','11011','11011','11110','11000','11000','11000'},
  R={'11110','11011','11011','11110','11100','11010','11011'},
  S={'01111','11000','11000','01110','00011','00011','11110'},
  T={'11111','01110','01110','01110','01110','01110','01110'},
  U={'11011','11011','11011','11011','11011','11011','01110'},
  V={'11011','11011','11011','11011','11011','01110','00100'},
 }
 local function palette(list)
  local out={};for i,c in ipairs(list) do out[i-1]=c end;return out
 end
 local function nearest(pal,level)
  local best,distance
  for i,c in pairs(pal) do if i>0 then
   local r,g,b=K.rgb8(c);local d=(r-level)^2+(g-level)^2+(b-level)^2
   if not distance or d<distance then best,distance=i,d end
  end end
  return assert(best)
 end
 local function lettering(pixels,w,h,text,cx,y,scale,pal,accent)
  local white,gray,black=nearest(pal,255),nearest(pal,175),nearest(pal,0)
  local origin=math.floor(cx-(#text*6-1)*scale/2)
  local ink={}
  local function point(x,py) assert(x>=1 and x<w-1 and py>=1 and py<h-1,'Title label cropped');ink[#ink+1]={x,py} end
  for n=1,#text do
   local ch=text:sub(n,n)
   if ch~=' ' then for row,bits in ipairs(assert(font[ch],ch)) do for col=1,5 do
    if bits:sub(col,col)=='1' then for sy=0,scale-1 do for sx=0,scale-1 do
     point(origin+(n-1)*6*scale+(col-1)*scale+sx,y+(row-1)*scale+sy)
    end end end
   end end end
  end
  if accent then
   local ax=origin+(accent-1)*6*scale
   for _,p in ipairs({{1,0},{2,-1},{3,0},{4,-1}}) do point(ax+p[1],y-2+p[2]) end
  end
  for _,p in ipairs(ink) do for dy=-1,1 do for dx=-1,1 do pixels[(p[2]+dy)*w+p[1]+dx+1]=black end end end
  for _,p in ipairs(ink) do pixels[p[2]*w+p[1]+1]=p[2]<y+4*scale and white or gray end
 end
 local vp=palette(man.palettes.version)
 local banner={};for i=1,128*32 do banner[i]=0 end
 lettering(banner,128,32,'VERSAO',54,5,1,vp,5)
 lettering(banner,128,32,editions[game],54,16,2,vp)
 for i,key in ipairs({'version_banner_left','version_banner_right'}) do
  local sprite=assert(man.sprites[key]);assert(sprite.w==64 and sprite.h==32 and sprite.frames==1)
  files[sprite.png]=K.encodeIndexed(64,32,K.crop(banner,128,(i-1)*64,0,64,32),vp,true)
 end
 local sprite=assert(man.sprites.press_start)
 local sheet=PNG.decode(assert(files[sprite.png] or base:read(sprite.png)),PNG.loveInflate)
 local count=game=='emerald' and 5 or 3
 local frames=game=='emerald' and 10 or 8
 assert(sprite.w==32 and sprite.h==8 and sprite.frames==frames and sheet.w==32 and sheet.h==8*frames)
 local pp=palette(man.palettes.pressStart)
 local width=count*32
 local prompt={};for i=1,width*10 do prompt[i]=0 end
 -- Build with a one-pixel guard, then crop to the sprite's eight rows.
 lettering(prompt,width,10,'APERTE START',width/2,1,1,pp)
 for frame=0,count-1 do for y=0,7 do for x=0,31 do
  sheet.index[(frame*8+y)*32+x+1]=prompt[y*width+frame*32+x+1]
 end end end
 files[sprite.png]=K.encodeIndexed(sheet.w,sheet.h,sheet.index,pp,true)
 return {'title:'..editions[game],'title:VERSÃO','title:APERTE START'}
end
