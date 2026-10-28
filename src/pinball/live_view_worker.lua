-- Encoding/decoding never blocks the game worker or audio queue. By Roxas2712.
require('love.thread');require('love.timer');require('love.image');require('love.data');require('love.filesystem')
local channel=...;local Json=require('src.link.Json');local Picture=require('src.pinball.LivePicture')
local channels={}
for _,name in ipairs{'previewSource','previewReceive','previewFrames','previewEncoded','previewEvents','previewQuit'}do channels[name]=love.thread.getChannel(channel..'.'..name)end
local function publish(image,frame)
 channels.previewFrames:performAtomic(function(output)
  local old=output:pop();while old do old.image:release();old=output:pop()end
  output:push{image=image,frame=frame}
 end)
 image:release()
end
while channels.previewQuit:getCount()==0 do
 local incoming=channels.previewReceive:pop()
 if incoming then
  local ok,why=pcall(function()
   local packet=Json.decode(incoming)
   local bytes=love.data.decode('string','base64',packet.png)
   assert(Picture.validate(bytes,packet.width,packet.height),'Invalid live picture dimensions or format')
   local file=love.filesystem.newFileData(bytes,'opponent.png')
   local image=love.image.newImageData(file);file:release()
   assert(image:getWidth()==packet.width and image:getHeight()==packet.height,'Live picture dimensions changed')
   publish(image,packet.frame)
  end)
  if not ok then channels.previewEvents:clear();channels.previewEvents:push(tostring(why))end
 end
 local source=channels.previewSource:pop()
 if source then
  local ok,why=pcall(function()
   local encoded=source.image:encode('png');local bytes=encoded:getString();encoded:release()
   if #bytes<=20000 then
    local packet={frame=source.frame,width=source.image:getWidth(),height=source.image:getHeight(),png=love.data.encode('string','base64',bytes)}
    channels.previewEncoded:performAtomic(function(output)output:clear();output:push(Json.encode(packet))end)
   end
  end)
  source.image:release()
  if not ok then channels.previewEvents:clear();channels.previewEvents:push(tostring(why))end
 end
 love.timer.sleep(.004)
end
