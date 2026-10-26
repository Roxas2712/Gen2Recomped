-- ROM-free cartridge-mode and integer channel-gain contracts.
local V=require('src.core.Gen3CryVoice')
for volume=0,255 do for _,pan in ipairs{-64,-25,0,25,63}do for _,env in ipairs{255,225,200,100,1,0}do
 local x=bit.rshift(bit.band(volume,127)*64,5);local y=math.max(-128,math.min(127,2*pan))
 local ml=bit.band(bit.rshift((127-y)*x,8),255);local mr=bit.band(bit.rshift((128+y)*x,8),255)
 local l=math.min(255,bit.rshift(127*127*ml,14));local r=math.min(255,bit.rshift(128*127*mr,14));local e=bit.rshift(13*env,4)
 local a,b=V.gains(volume,pan,env);assert(a==bit.rshift(l*e,8)/256 and b==bit.rshift(r*e,8)/256)
end end end
love={sound={newSoundData=function(n,rate,bits,ch)
 local sd={n=n,ch=ch,first={}};function sd:setSample(i,c,v)
  if self.ch==1 then v,c=c,1 end;assert(v>=-1 and v<=1);if i==0 then self.first[c]=v end
 end;return sd
end}}
local pcm=string.rep(string.char(127),66000)
local rows=0
for _,edition in ipairs{'firered','leafgreen','emerald','ruby','sapphire'}do
 local rs=edition=='ruby'or edition=='sapphire'
 for mode=0,(rs and 5 or 12)do
  local p=V.params(edition,{mode=mode})
  local sd,info=V.render(pcm,44100,p,{})
  assert(info.outputSamples==sd.n and info.mode==mode)
  if mode==0 then
   local a,b=V.gains(rs and 125 or 120,0,255)
   assert(sd.first[1]==127/128*a and sd.first[2]==127/128*b)
  end
  if rs then
   assert(p.reverse==false and(p.chorus==0 or mode==2))
   if mode==2 then assert(p.length==30 and p.volume==80)end
   if mode==4 then assert(p.pitch==15800 and p.length==20)end
   if mode==5 then assert(p.pitch==14500)end
  elseif mode==4 or mode==9 then assert(p.reverse)end
  if mode==6 then assert(p.volume==(edition=='emerald'and 70 or 90))end
  rows=rows+1
 end
 assert(V.params(edition,{mode=99}).mode==0)
 if rs then assert(V.params(edition,{mode=6}).mode==0)end
end
assert(V.params('firered',{cryVolume=0}).volume==0)
print('PASS_GEN3_AUDIO_MODES',rows,'edition modes, reverse/chorus/profile differences, 7680 integer gains and final output bounds')
