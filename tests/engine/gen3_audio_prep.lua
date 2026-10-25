local path=arg[1]or'src/core/Gen3AudioPrep.lua'
local P=assert(loadfile(path))();local time,engines,plays=0,0,0
love={timer={getTime=function()return time end},sound={newSoundData=function(n,rate,bits,ch)
 local sd={n=n,ch=ch,values={}};function sd:getSampleCount()return self.n end;function sd:getChannelCount()return self.ch end
 function sd:setSample(i,c,v)time=time+.0000001;self.values[i*2+c]=v end;return sd
end}}
local M={invalidate=function()return'invalidated'end,newEngine=function(data,def,opts)
 assert(opts.allowLoops==false);engines=engines+1;local i=0
 return {sampleStereo=function()i=i+1;time=time+.000001;return i%17/32,-(i%19)/32 end,
 finished=function()return i>=def.n end}
end}
local native=M.renderEffect;assert(P.install(M)==P and P.install(M)==P)
local song={n=4096};local data={audio={gen3={file='audio',base=0},songs={SONG_084=song},sfx={HIT={m4a=0x84}}},moves={TACKLE={anim={sound='HIT'}}}}
P.plan(data,{{{moves={'TACKLE'}}}});P.plan(data,{{{moves={'TACKLE'}}}})
assert(P.status().pending==1 and engines==0,'Plan synthesized eagerly or queued duplicates')
local steps=0;while P.status().pending>0 do P.step(.0005);steps=steps+1 end
assert(steps>5 and P.stats.maxSlice<.0007,'Preparation failed bounded checkpoints')
local warm=M.renderEffect(data,song);assert(engines==1 and warm==M.renderEffect(data,song))
P.reset();local cold=M.renderEffect(data,song);assert(engines==2)
for i,v in ipairs(cold.values)do assert(v==warm.values[i],'Warm changed actual PCM')end
local other={n=3000};assert(P.enqueue(data,other));P.step(.00001);assert(P.status().pending==1)
local copy={audio={gen3={file='audio',base=0},songs=data.audio.songs,sfx=data.audio.sfx}}
M.renderEffect(copy,song);assert(P.status().pending==0,'Dataset identity leaked pending PCM')
assert(P.enqueue(data,other));M.invalidate();assert(P.status().pending==0 and P.status().entries==0)
P.suspend();assert(not P.enqueue(data,song));P.step();assert(P.status().entries==0)
P.resume();assert(P.enqueue(data,song));P.step(.0001)
data.audio.programPrefix='changed/';P.step(.001);assert(P.status().pending==0 and P.status().entries==0)
for i=1,70 do M.renderEffect(data,{n=64})end
assert(P.status().entries==48 and P.status().bytes<=P.maxBytes,'Unbounded PCM cache')
assert(P.enqueue(data,song));P.plan({audio={}},{});assert(P.status().pending==0 and P.status().entries==0)
print('PASS_AUDIO_PREP exact cold/warm PCM; bounded synthesis/upload; no Source/play; 48-entry cap; dataset/prefix/invalidate/session cancellation')
