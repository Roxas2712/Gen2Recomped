-- Native RS tutorial labels/back pic and the ball tables used by the host timeline.
local M={}
local LABELS={'BattleText_Wally','BattleText_WallyMenu','BattleText_WallyBall',
  'BattleText_ComeBackSingle1','BattleText_ComeBackSingle2','BattleText_ComeBackSingle3',
  'BattleText_ComeBackSingle4','BattleText_TutorialUsed','BattleText_BallCaught2'}
function M.extract(x,load,rom,cache,songs)
  x:beginStage('Ruby/Sapphire Wally and ball resources')
  local A=load('src.import.gba.rs.assets');local K=load('src.import.gba.rse.boot_gfx')
  local c=A.context(rom,cache,{},'wally');local S=c.S
  local IR=load('src.core.game3.scripting.text_ir');local words={}
  for _,key in ipairs(LABELS)do
    local bytes={};local off=S.off(key)
    for i=0,2047 do local b=rom:get(off+i);bytes[#bytes+1]=b;if b==255 then break end end
    assert(bytes[#bytes]==255,'Unterminated RS tutorial label '..key)
    words[key]=IR.decode(bytes,{dialect='rs',battle=true})
  end
  local gfx=c:lz('gTrainerBackPic_Wally');local pal=c:palFrom(c:lz('gTrainerPalette_Wally'))
  assert(#gfx==8192,'Wally needs four 64x64 frames')
  assert(rom:ptrOffset(rom:u32(S.off('gTrainerBackPicTable')+2*8))==S.off('gTrainerBackPic_Wally'))
  local native=assert(x._constants.gen3TrainerBack)
  local anim=assert(native.anims[2]);assert(anim.rest==3 and #anim.throw==5)
  local strip={};local frames={}
  for f=0,3 do
    frames[f]=K.bakeSprite(gfx,64,64,f*64)
    for y=0,63 do for xx=0,63 do strip[y*256+f*64+xx+1]=frames[f][y*64+xx+1]end end
  end
  local images={idle=c:png('idle.png',64,64,frames[anim.rest],pal,true),
    strip=c:png('strip.png',256,64,strip,pal,true)}

  -- The shared extractor already validates every sheet, tag and open-frame
  -- splice. Its atlas has balls across X; the host renderer expects rows.
  local Fs=require('src.import.CacheFs');local root='data/generated/gba/pokemon/battle/ball_open/'
  local rgba=assert(Fs.read(root..'balls.rgba'));assert(#rgba==192*48*4)
  local function png(name,w,h,bytes)
    local img=love.image.newImageData(w,h,'rgba8',bytes)
    local encoded=img:encode('png'):getString();img:release();return c:write(name,encoded)
  end
  local rows={}
  for ball=0,11 do for y=0,15 do
    for f=0,2 do local off=((f*16+y)*192+ball*16)*4;rows[#rows+1]=rgba:sub(off+1,off+64)end
  end end
  local balls=png('balls.png',48,192,table.concat(rows))
  local particles=assert(Fs.read(root..'particles.rgba'));assert(#particles==64*8*4)
  local particlePic=png('particles.png',64,8,particles)

  -- RS has different tables and Thumb sites from Emerald. Fail on a changed
  -- instruction instead of silently inheriting Emerald's send-out numbers.
  local B={};local extractor=require('src.import.RomExtractorGen3')
  for key,value in pairs(extractor.BALL_ANIM)do B[key]=value end
  B.SHEETS=S.off('pokeball.o:sBallSpriteSheets');B.PALETTES=S.off('pokeball.o:sBallSpritePalettes')
  B.OPEN_FRAME=S.off('gUnknown_08D030D0');B.COLOURS=S.off('gUnknown_0840B4D4')
  B.PARTICLES=assert(rom:ptrOffset(rom:u32(S.off('gBallOpenParticleSpritesheets'))))
  B.PARTICLE_PALETTE=assert(rom:ptrOffset(rom:u32(S.off('gBallOpenParticlePalettes'))))
  B.PARTICLE_ANIM=S.off('gBallOpenParticleAnimNums')
  B.SEND={AT_HAND_X=0x46530,AT_HAND_Y=0x46534,AT_FRAMES=0x47078,AT_TARGET_DY=0x4709e,
    AT_ARC=0x470a2,AT_FOE_DY=0x46576,AT_FOE_WAIT=0x47262,AT_FADE=0x46cc4,AT_RISE=0x46f08,
    MOV_R0=0x2000,MOV_R2=0x2200,ADD_R0=0x3000,CMP_R0=0x2800}
  B.SOUNDS={throw=assert(songs.SE_BALL_THROW),open=assert(songs.SE_BALL_OPEN),
    absorb=assert(songs.SE_BALL_TRADE),shake=assert(songs.SE_BALL),click=false,caught=assert(songs.MUS_EVOLVED)}
  x:extractBallAnims(B,'ROM:native RS ball tables; RS send-out Thumb sites 046530/047074/046C78/046E9C; host ball timeline')
  local record=assert(x._constants.gen3BallAnim)
  local send=assert(record.timing.sendOut,'RS send-out instructions did not validate')
  assert(send.from.x==24 and send.from.y==68 and send.frames==25 and send.arc==-30
    and send.targetOffsetY==24 and send.foeWait==16 and send.fadeFrames==14 and send.riseStep==-288)
  record.images={balls=balls,particles=particlePic};record.rsFormat=1;record.version=x.version
  for _,row in ipairs(record.balls)do for i,v in ipairs(row.colour)do
    -- Legacy palette decoding floors; the native extractor rounds 5-bit RGB.
    local five=math.floor(v*31/255+0.5);row.colour[i]=math.floor(five*255/31+0.5)
  end end
  assert(A.finish(c,{screen='wally',images=images,balls=record.images}))
  x._constants.gen3RsWally={format=1,version=x.version,textIR=words,images=images,anim=anim,
    resources={'data/generated/gba/wally/manifest.lua',images.idle,images.strip,balls,particlePic},
    source='ROM:Wally back index 2, all four native frames, native RS battle labels; script special 301 -> host 303'}
end
function M.missing(version)
  local Fs=require('src.import.CacheFs');local function read(path)
    local raw=Fs.read(path);local f=raw and loadstring(raw);if not f then return end;setfenv(f,{})
    local ok,t=pcall(f);return ok and type(t)=='table'and t or nil
  end
  local constants=read('data/generated/constants.lua')or {};local s=constants.gen3RsWally
  local b=constants.gen3BallAnim
  if type(s)~='table'or s.format~=1 or s.version~=version or type(s.textIR)~='table'
    or type(s.resources)~='table'or #s.resources~=5 or type(s.images)~='table'or type(s.anim)~='table'
    or type(b)~='table'or b.rsFormat~=1 or b.version~=version or not(b.timing and b.timing.sendOut)then
    return {'<rs:native-wally-and-balls>'}
  end
  local absent={}
  local man=read('data/generated/gba/wally/manifest.lua')
  if not man or man.layout~='rs'or man.game~=version or type(man.files)~='table'or #man.files~=4 then
    absent[#absent+1]='<rs:wally-manifest>'
  end
  for _,key in ipairs(LABELS)do if type(s.textIR[key])~='table'or #s.textIR[key]==0 then absent[#absent+1]='<rs:wally-text:'..key..'>'end end
  for _,path in ipairs(s.resources)do if type(path)~='string'or not Fs.exists(path)then absent[#absent+1]=tostring(path)end end
  return absent
end
return M
