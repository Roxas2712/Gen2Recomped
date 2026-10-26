-- Real Sound owner: options must reach PCM before native caching/playback.
local built,ducked=0,0;local last;local native=false
package.loaded['src.render.Assets']={register=function()end}
package.loaded['src.core.Logger']={debug=function()end,warn=function()end}
package.loaded['src.mods.Runtime']={wants=function()return false end}
package.loaded['src.core.GameVersion']={get=function()return'emerald'end,isYellow=function()return false end,isGen3=function()return native end}
package.loaded['src.core.Music']={duckForCry=function(_,_,noDuck)if not noDuck then ducked=ducked+1 end end}
package.loaded['src.core.M4ASynth']={crySupports=function(_,i)return i~=99 end}
local function source()
 local s={};function s:stop()self.playing=false end;function s:play()self.playing=true end
 function s:setVolume(v)self.volume=v end;function s:clone()return source()end
 return s
end
package.loaded['src.core.ChipAudio']={newCry=function(data,species,def,options)built=built+1;last=options;return source()end}
love={audio={newSource=source}}
local S=require('src.core.Sound')
local data={audio={gen3={file='test'},cries={A={m4a=0},RAW={m4a=99}}},constants={gen3Cry={volume=120,scale=256}}}
for mode=0,12 do
 local src=assert(S.playCry(data,'A',{mode=mode,pan=-25}));assert(last.mode==mode and last.pan==-25 and last.edition=='emerald')
 assert(src.volume==.8);local n=built;assert(S.playCry(data,'A',{mode=mode,pan=-25})==src and built==n)
end
local n=ducked;S.playCry(data,'A',{noDuck=true});S.playCry(data,'A',{mode=1});assert(ducked==n)
assert(S.playCry(data,'RAW').volume==.8*120/256,'Custom cry trim changed')
S.setVolumeLevel(0);assert(S.playCry(data,'A').volume==0)
n=built;S.suspend();assert(S.playCry(data,'A')==nil and built==n);S.resume();S.setVolumeLevel(7)
assert(S.playCry(data,'A').volume==.8 and built==n+1)
-- The same custom-table definitions also pass through the real native cry
-- owner in Gen3. They retain the existing override/duck ownership policy.
native=true
local before=ducked
local override=assert(S.playCry(data,'A',{mode=4,pan=12,volume=95}))
assert(last.mode==4 and last.pan==12 and last.cryVolume==95 and override.volume==.8)
assert(ducked==before,'Native override duck ownership changed')
local builtBefore=built
assert(S.playCry(data,'A',{mode=4,pan=12,volume=95})==override and built==builtBefore)
print('PASS_GEN3_CRY_OWNER modes/pan/cache/volume/ducking/session; custom fallback preserved')
