-- Keep all native RS bicycle images, including the Acro Bike's wheelie
-- pictures. The ordinary nine-frame walker export discards these poses.
local M={}
local DIRS={down=1,up=2,left=3,right=4}
function M.read(version,rom)
  local c=require('src.import.Gen3RsBike').new(version,rom);local S=c.S
  local avatars=c:data('sPlayerAvatarGfxIds',16)
  local spec={format=1,version=version,avatars={},resources={},
    source='ROM: native RS avatar graphics IDs, complete picture arrays and authored frame/duration/flip commands'}
  local roles={stand='gFaceDirectionAnimNums',moving='gMoveDirectionAnimNums',
    wheelie='gAcroWheelieDirectionAnimNums',pedal='gAcroWheeliePedalDirectionAnimNums',
    lowering='gAcroEndWheelieDirectionAnimNums'}
  local function named(at,prefix)
    for _,name in ipairs(S.namesAt(at))do if name:sub(1,#prefix)==prefix then return name end end
    error('Missing sized native RS bicycle table at '..tostring(at))
  end
  for gender,index in pairs({boy=0,girl=1})do
    spec.avatars[gender]={}
    for kind,state in pairs({mach=1,acro=2})do
      local gid=rom:u8(avatars+state*2+index)
      local info=assert(rom:pointer(S.off('gObjectEventGraphicsInfoPointers')+gid*4))
      local pictures=assert(rom:pointer(info+28));local animations=assert(rom:pointer(info+24))
      local name=named(pictures,'gObjectEventPicTable_');local count=S.count(name,8)
      assert(count==(kind=='acro'and 27 or 9),'Unsupported native RS bicycle picture count')
      local bytes=rom:u16(pictures+4);local width=rom:u16(info+8)
      assert(width==32 and bytes==512,'Native RS bicycle must use 32-square frames')
      local animName=named(animations,'gObjectEventImageAnimTable_')
      local animCount=S.count(animName,4)
      assert(animCount>=20 and animCount<=40,'Unsupported native RS bicycle animation table')
      local row={graphicsId=gid,info=info,pictures=pictures,frameCount=count,
        frameBytes=bytes,width=width,height=32,paletteTag=rom:u16(info+2),
        subsprites=rom:pointer(info+20),animations={},roles={},
        image='assets/generated/overworld/rs_bikes/'..gender..'_'..kind..'.png'}
      for frame=0,count-1 do
        assert(rom:pointer(pictures+frame*8)and rom:u16(pictures+frame*8+4)==bytes,
          'Incomplete native RS bicycle image')
      end
      for slot=0,animCount-1 do
        local at=assert(rom:pointer(animations+slot*4));local sequence={};local ended=false
        for i=0,31 do
          local word=rom:u32(at+i*4);local frame=word%65536
          if frame==0xFFFF then sequence.loop=false;ended=true;break end
          if frame==0xFFFE then
            assert(math.floor(word/65536)==0,'Unsupported bicycle animation jump target')
            sequence.loop=true;ended=true;break
          end
          local ticks=math.floor(word/65536)%64
          assert(frame<count and ticks>0 and word<0x800000,'Unsupported native bicycle frame command')
          sequence[#sequence+1]={frame=frame,ticks=ticks,flip=math.floor(word/0x400000)%2==1}
        end
        assert(ended and #sequence>0,'Unterminated native bicycle animation')
        row.animations[slot+1]=sequence
      end
      for role,label in pairs(roles)do
        if kind=='acro'or role=='stand'or role=='moving'then
          local at=c:data(label,9);row.roles[role]={}
          for dir,d in pairs(DIRS)do
            local slot=rom:u8(at+d);assert(row.animations[slot+1],'Missing native bicycle role animation')
            row.roles[role][dir]=slot+1
          end
        end
      end
      row.reflectionImage=row.image:gsub('%.png$','_reflect.png')
      spec.avatars[gender][kind]=row;spec.resources[#spec.resources+1]=row.image
      spec.resources[#spec.resources+1]=row.reflectionImage
    end
  end
  table.sort(spec.resources);return spec
end
function M.frame(row,role,dir,clock)
  local slot=assert(row.roles[role]and row.roles[role][dir],'Unknown native bicycle pose')
  local seq=assert(row.animations[slot]);local total=0
  for _,entry in ipairs(seq)do total=total+entry.ticks end
  local t=math.max(0,math.floor(clock or 0))
  t=seq.loop and t%total or math.min(t,total-1)
  for _,entry in ipairs(seq)do
    if t<entry.ticks then return entry.frame,entry.flip end
    t=t-entry.ticks
  end
end
function M.extract(x)
  x:beginStage('Ruby/Sapphire complete bicycle sprites')
  local spec=M.read(x.version,x.rom)
  local palettes=x:objectGfxPalettes(assert(x:symbol('sObjectEventSpritePalettes')),
    x:layoutValue('objectEventPaletteCount',0))
  for _,kinds in pairs(spec.avatars)do for _,row in pairs(kinds)do
    local colors=assert(palettes[row.paletteTag]);local image=x:objectGfxSheet(32,32*row.frameCount)
    local reflectColors=palettes[x:reflectionPaletteFor(row.info)]or colors
    local reflected=x:objectGfxSheet(32,32*row.frameCount)
    for frame=0,row.frameCount-1 do
      local raw=x.rom:bytes(assert(x.rom:pointer(row.pictures+frame*8)),row.frameBytes)
      local pixels=x:overworldFramePixels(raw,32,32,row.subsprites)
      for y=1,32 do for col=1,32 do
        local index=pixels[y][col];local rgb=assert(colors[index+1])
        image:setPixel(col-1,frame*32+y-1,rgb[1]/255,rgb[2]/255,rgb[3]/255,index==0 and 0 or 1)
        local reflection=assert(reflectColors[index+1])
        reflected:setPixel(col-1,frame*32+y-1,reflection[1]/255,reflection[2]/255,reflection[3]/255,index==0 and 0 or 1)
      end end
    end
    x:saveImage(image,row.image:sub(#'assets/generated/'+1))
    x:saveImage(reflected,row.reflectionImage:sub(#'assets/generated/'+1))
  end end
  x._constants.gen3RsBikeSprites=spec
end
function M.valid(spec,version)
  if type(spec)~='table'or spec.format~=1 or spec.version~=version
    or (version~='ruby'and version~='sapphire')or type(spec.avatars)~='table'
    or type(spec.resources)~='table'or #spec.resources~=8 then return false end
  for _,gender in ipairs({'boy','girl'})do
    local kinds=spec.avatars[gender];if type(kinds)~='table'then return false end
    for _,kind in ipairs({'mach','acro'})do
      local row=kinds[kind]
      if type(row)~='table'or row.frameCount~=(kind=='acro'and 27 or 9)
        or type(row.roles)~='table'or type(row.animations)~='table'
        or row.image~='assets/generated/overworld/rs_bikes/'..gender..'_'..kind..'.png'then return false end
      for _,role in ipairs(kind=='acro'and {'stand','moving','wheelie','pedal','lowering'}or {'stand','moving'})do
        for dir in pairs(DIRS)do
          local slot=row.roles[role]and row.roles[role][dir]
          if not slot or type(row.animations[slot])~='table'or #row.animations[slot]==0 then return false end
        end
      end
    end
  end
  return true
end
return M
