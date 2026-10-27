package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.harness');love=require('tests.love_stub')
local last
local Source={};Source.__index=Source
function Source:play()self.playing=true end
function Source:stop()self.playing=false end
function Source:pause()self.playing=false end
function Source:isPlaying()return self.playing end
function Source:setLooping()end
function Source:setVolume(v)self.volume=v end
function Source:setFilter()end
love.audio={newSource=function()last=setmetatable({},Source);return last end}
local M=require('src.core.Music');local data={audio={songs={TEST={file='test.ogg'}}}}
for _,speed in ipairs({4,10})do
 M.play(data,'TEST');local initial=last.volume;M.fadeOutM4a(speed)
 for _=1,speed-1 do M.update(data)end
 T.eq(last.volume,initial,'m4a holds first volume step for native speed '..speed)
 M.update(data);T.eq(last.volume,initial*15/16,'m4a first decrement uses sixteen-step scale '..speed)
 for _=1,15*speed-1 do M.update(data)end
 T.eq(M.current(),'TEST','m4a still owns song one frame before fade end '..speed)
 M.update(data);T.eq(M.current(),nil,'m4a stops after exactly sixteen native steps '..speed)
 T.eq(last.playing,false,'m4a fade stops actual source '..speed)
end
M.play(data,'TEST');M.fadeOut(3)
for _=1,20 do M.update(data)end
T.eq(M.current(),'TEST','legacy seven-step fade retains original timing')
M.update(data);T.eq(M.current(),nil,'legacy fade still stops at seven times control')
T.finish('GBA m4a fade duration and legacy fade policy')
