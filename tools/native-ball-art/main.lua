-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
io.stdout:setvbuf('no')
local root=assert(os.getenv('NATIVE_TEXT_ENGINE'))
package.path=root..'/?.lua;'..root..'/?/init.lua;'..package.path
function love.errorhandler(err)print(debug.traceback(tostring(err),2));return function()return 1 end end
local function read(path)local f=assert(io.open(path,'rb'));local s=f:read('*a');f:close();return s end
function love.load()
 assert(love.graphics==nil,'ball art import must not initialize graphics')
 local J=require('src.link.Json');local V=require('src.core.GameVersion')
 local X=require('src.import.RomExtractorGen3')
 local inputs=J.decode(read(assert(os.getenv('NATIVE_TEXT_INPUTS'))))
 local result={editions={},pass=true,gpu=false,playerProfilesUsed=false,visualAcceptance=false}
 for _,edition in ipairs{'firered','leafgreen','emerald','ruby','sapphire'}do
  V.set(edition);require('src.import.CacheFs').prefix=edition..'/'
  local raw=read(assert(inputs[edition]));local info=V.info()
  assert(require('src.import.RomVerification').sha1(raw)==info.sha1,'exact native cartridge required')
  local manifest=J.decode(read(root..'/'..info.manifest))
  local x=X.new(raw,info,manifest)
  local art
  function x:saveImage(image,path)
   if path=='battle/balls.png'then
    assert(image:getWidth()==48 and image:getHeight()==192)
    local cells={}
    for ball=0,11 do for frame=0,2 do
     local visible=0
     for y=ball*16,ball*16+15 do for px=frame*16,frame*16+15 do
      local _,_,_,a=image:getPixel(px,y);if a>0 then visible=visible+1 end
     end end
     assert(visible>0,'empty original ball cell');cells[#cells+1]=visible
    end end
    art={width=image:getWidth(),height=image:getHeight(),visiblePixels=cells,
     rgbaSha256=love.data.encode('string','hex',love.data.hash('sha256',image:getString()))}
   end
   image:release()
  end
  local task=coroutine.create(function()x:extractBallAnims()end)
  repeat local ok,why=coroutine.resume(task);assert(ok,why)until coroutine.status(task)=='dead'
  local r=assert(x._constants and x._constants.gen3BallAnim,'native ball tables unavailable: '..edition)
  assert(r.size==16 and r.frames==3 and r.count==12 and #r.balls==12)
  assert(r.images.balls=='assets/generated/battle/balls.png'and art,'native ball art was not composed')
  if edition=='ruby'or edition=='sapphire'then
   for name,proof in pairs(assert(manifest.rsBallAnimationEvidence).functions)do
    local bytes=raw:sub(proof.address+1,proof.address+proof.size)
    assert(love.data.encode('string','hex',love.data.hash('sha256',bytes))==proof.sha256,name..' differs from original native metadata')
   end
   local send=assert(r.timing.sendOut,'verified native RS send-out unavailable')
   assert(send.frames==25 and send.from.x==24 and send.from.y==68 and send.arc==-30 and send.riseStep==-288)
   assert(send.foeWait==16 and send.fadeFrames==14 and send.targetOffsetY==24 and send.foeOffsetY==24)
   assert(r.sounds.caught==371 and r.sounds.click==nil,'RS sound identity was lost')
   local Ball=require('src.battle.Gen3BallAnim');art.nativeSendOutFrames={}
   for _,side in ipairs{'player','opponent'}do
    local ball=Ball.new({constants={gen3BallAnim=r}},{sendOut=side,to={x=176,y=40}})
    local frames=ball:estimate();assert(frames==(side=='player'and 39 or 30))
    for i=1,frames do ball:update();assert(ball.frame==i)end
    assert(ball:isDone()and ball.monScale==1 and not ball.monHidden)
    art.nativeSendOutFrames[side]=frames
   end
  end
  art.sha1=info.sha1;result.editions[edition]=art
  print('NATIVE_BALL_ART_EDITION',edition,art.width,art.height,#art.visiblePixels,art.rgbaSha256)
 end
 local file=assert(io.open(assert(os.getenv('NATIVE_TEXT_RESULT')),'wb'));file:write(J.encode(result));file:close()
 print('NATIVE_BALL_ART_OK');love.event.quit(0)
end
