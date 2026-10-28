love=require('tests.love_stub');love.filesystem.load=loadfile
local R=require('src.import.RomGba');local M=require('src.import.Gen3RsBikeSprites')
local n=0;local function check(v,why)n=n+1;assert(v,why)end
for _,version in ipairs({'ruby','sapphire'})do
 local f=assert(io.open(os.getenv('RS_BIKE_'..version:upper()..'_ROM'),'rb'));local bytes=f:read('*a');f:close()
 local rom=R.new(bytes);local spec=M.read(version,rom)
 check(M.valid(spec,version),'Accept native bicycle metadata')
 check(not M.valid(spec,version=='ruby'and 'sapphire'or 'ruby'),'Reject another edition')
 check(#spec.resources==8,'Body and reflection sheets for both bikes and genders')
 for _,gender in ipairs({'boy','girl'})do
  local a=spec.avatars[gender].acro;local m=spec.avatars[gender].mach
  check(a.graphicsId~=m.graphicsId,'Acro and Mach must use different graphics')
  check(a.frameCount==27 and m.frameCount==9,'Preserve the complete native image arrays')
  for _,row in ipairs({a,m})do
   for role,dirs in pairs(row.roles)do for dir,slot in pairs(dirs)do
    local seq=row.animations[slot];local ticks=0
    for _,entry in ipairs(seq)do
     local frame,flip=M.frame(row,role,dir,ticks)
     check(frame==entry.frame and flip==entry.flip,'Native duration/flip at segment boundary')
     ticks=ticks+entry.ticks
    end
    local frame=M.frame(row,role,dir,ticks)
    check(frame==(seq.loop and seq[1].frame or seq[#seq].frame),'Native loop/end policy')
   end end
  end
  for dir,frames in pairs({down={9,10},up={13,14},left={17,18},right={17,18}})do
   local first,flip=M.frame(a,'wheelie',dir,0);local last=M.frame(a,'wheelie',dir,100)
   check(first==frames[1]and last==frames[2],'Actual RS wheelie images')
   check(flip==(dir=='right'),'Actual mirrored east command')
   local down=M.frame(a,'lowering',dir,100);check(down==({down=0,up=1,left=2,right=2})[dir],'Native wheelie lowering reaches normal')
  end
 end
 local source=spec.avatars.boy.acro;local bad=source.pictures+4
 local raw=bytes:sub(1,bad)..string.char(0,0)..bytes:sub(bad+3)
 check(not pcall(M.read,version,R.new(raw)),'Reject missing image size')
 spec.format=99;check(not M.valid(spec,version),'Reject an unknown cache format')
end
print('RS_BIKE_SPRITE_CHECKS',n)
