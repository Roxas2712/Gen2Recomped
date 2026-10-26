-- Localize the shared Hoenn shop sign in the native metatile atlas. The
-- geometry/collision IDs, palettes and all pixels outside the sign are kept.
return function(files,game,specOnly)
 if game~='ruby' and game~='sapphire' and game~='emerald' then return 0 end
 local expected={
  '1d1d1bdb1ddb1ddd','1ddd1d1d1d1d11d1','1d1d1d1d1d1d11d1',
  '2e2e2eee2eeb22e2','2e2e2e2e2e2e22e2','2222222222222222',
  '22ee2e2ee2e2ee22','2222222222222222',
 }
 local letters={
  {'100','100','100','100','111'}, -- L
  {'111','101','101','101','111'}, -- O
  {'111','001','001','101','111'}, -- J
  {'010','101','111','101','101'}, -- A
 }
 if specOnly then return {expected=expected,letters=letters}end
 local N=require('src.import.gba.native_pack')
 local base=require('src.core.game3.dataset').cache()
 local root='data/generated/gba/native/'
 local man=assert(loadstring(assert(base:read(root..'manifest.lua'))))()
 local patches={};local count=0
 for pair in pairs(man.pairs) do
  if pair:match('^general__') then
   local path=root..pair..'/mids.idx'
   local atlas=assert(N.decodeIdx(assert(files[path] or base:read(path))))
   local slots={}
   for i,id in ipairs(atlas.midIds) do if id==66 or id==67 then slots[id]=(i-1)*256 end end
   if slots[66] and slots[67] then
    local function index(x,y) return slots[x<8 and 66 or 67]+y*16+(x<8 and x+8 or x-8)+1 end
    for y=0,7 do for x=0,15 do
     assert(atlas.pixels[index(x,y)]==16+tonumber(expected[y+1]:sub(x+1,x+1),16),
      'Shop sign layout changed: '..game..'/'..pair..'/'..x..','..y)
    end end
    for y=0,7 do for x=0,15 do atlas.pixels[index(x,y)]=16+(y<3 and 1 or 2) end end
    for n,rows in ipairs(letters) do for y,row in ipairs(rows) do for x=1,3 do
     if row:sub(x,x)=='1' then atlas.pixels[index((n-1)*4+x,y-1)]=16+(y<=3 and 13 or 14) end
    end end end
    patches[path]=N.encodeIdx(atlas);count=count+1
   end
  end
 end
 assert(count>0,'No Hoenn shop sign atlases found')
 for path,bytes in pairs(patches) do files[path]=bytes end
 return count
end
