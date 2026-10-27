-- Actual cross-thread retained Data lifetime; no stubs/cartridge. By Roxas2712.
require('love.thread');require('love.image');require('love.sound')
local prefix='pinball-lifetime'
local worker=love.thread.newThread([[
require('love.thread');require('love.image');require('love.sound')
local prefix=...
local frames=love.thread.getChannel(prefix..'.frames');local ready=love.thread.getChannel(prefix..'.ready')
for n=1,100 do
 local image=love.image.newImageData(240,160);image:setPixel(0,0,n/255,.5,.25,1)
 local sound=love.sound.newSoundData(16,32768,16,1);sound:setSample(0,.25)
 frames:push{image=image,sound=sound};image:release();sound:release();ready:push(n)
end
local bounded=love.thread.getChannel(prefix..'.bounded')
for n=1,10 do
 local image=love.image.newImageData(16,16);image:setPixel(0,0,n/255,0,0,1)
 bounded:performAtomic(function(channel)
  while channel:getCount()>=3 do channel:pop().image:release()end
  channel:push{image=image,n=n}
 end)
 image:release()
end
ready:push('done')
]])
worker:start(prefix)
local frames=love.thread.getChannel(prefix..'.frames');local ready=love.thread.getChannel(prefix..'.ready')
for n=1,100 do
 assert(ready:demand(5)==n,'worker lifetime acknowledgement')
 local frame=assert(frames:demand(5));local r=frame.image:getPixel(0,0)
 assert(math.abs(r-n/255)<1/255,'image survived producer release unchanged')
 assert(math.abs(frame.sound:getSample(0)-.25)<.001,'sound survived producer release unchanged')
 frame.image:release();frame.sound:release()
end
assert(ready:demand(5)=='done');worker:wait();assert(not worker:getError(),worker:getError())
local bounded=love.thread.getChannel(prefix..'.bounded');assert(bounded:getCount()==3)
for n=8,10 do
 local value=assert(bounded:pop());assert(value.n==n)
 local r=value.image:getPixel(0,0);assert(math.abs(r-n/255)<1/255);value.image:release()
end
assert(not bounded:pop()and not frames:pop())
worker:release()
print('Actual LÖVE channel lifetime: 100 image/audio handoffs and bounded FIFO retention passed')
