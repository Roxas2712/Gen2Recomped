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
  local x=X.new(raw,info,J.decode(read(root..'/'..info.manifest)))
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
  art.sha1=info.sha1;result.editions[edition]=art
  print('NATIVE_BALL_ART_EDITION',edition,art.width,art.height,#art.visiblePixels,art.rgbaSha256)
 end
 local file=assert(io.open(assert(os.getenv('NATIVE_TEXT_RESULT')),'wb'));file:write(J.encode(result));file:close()
 print('NATIVE_BALL_ART_OK');love.event.quit(0)
end
