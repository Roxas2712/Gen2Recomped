package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.harness')
love=require('tests.love_stub')
local M=require('src.core.M4ASynth')
local original,sound=M.newEngine,love.sound
love.sound={newSoundData=function(n,rate)
 local result={length=n,rate=rate,values={}}
 function result:setSample(i,channel,value)self.values[i*2+channel]=value end
 return result
end}
local made,sampled=0,0
M.newEngine=function()
 made=made+1
 local n=0
 return {sampleStereo=function()n=n+1;sampled=sampled+1;return (n%17)/32,-(n%13)/32 end,
   finished=function()return n>=4096 end}
end
T.eq(M.renderEffect({}, {}, nil, function()return true end),nil,'preempt before engine allocation')
T.eq(made,0,'cancelled job never starts synthesis')
local calls=0
local cancelled=M.renderEffect({}, {}, nil, function()calls=calls+1;return calls>=3 end)
T.eq(cancelled,nil,'busy synthesis stops cooperatively')
T.eq(sampled,1024,'preemption latency is bounded by 1024 samples')
local first=M.renderEffect({}, {})
local unchanged=M.renderEffect({}, {}, nil, function()return false end)
T.eq(first.length,unchanged.length,'uncancelled timing is identical')
T.same(first.values,unchanged.values,'uncancelled stereo PCM is identical')
T.eq(first.rate,unchanged.rate,'uncancelled output rate is identical')
M.newEngine,love.sound=original,sound
local C=require('src.core.Gen3CryPCM')
local block=string.char(127,0xF1)..string.rep(string.char(0x12),31)
local checkpoints=0
local pcm,why=C.decode(string.rep(block,64),0,4096,function()checkpoints=checkpoints+1;return checkpoints==2 end)
T.eq(pcm,nil,'compressed cry decode cooperates')
T.eq(why,'cancelled','decoder distinguishes cancellation')
T.eq(checkpoints,2,'decoder checks every 1024 input samples')
local V=require('src.core.Gen3CryVoice')
local allocations,releases,writes=0,0,0
local priorSound=love.sound
love.sound={newSoundData=function()
 allocations=allocations+1
 return {setSample=function()writes=writes+1 end,release=function()releases=releases+1 end}
end}
local params=V.params('emerald',{})
T.eq(V.render(string.rep('\127',4096),44100,params,{},function()return true end),nil,'cry preempts before SoundData')
T.eq(allocations,0,'preempted cry allocates no output')
calls=0
T.eq(V.render(string.rep('\127',4096),44100,params,{},function()calls=calls+1;return calls>=3 end),nil,'cry mixing preempts')
T.eq(writes,2048,'stereo cry mixing stops after 1024 frames')
T.eq(releases,1,'discarded SoundData is released immediately')
love.sound=priorSound
T.finish('M4A cooperative effect and compressed cry cancellation')
