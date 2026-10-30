-- Gen 3 cry modes and DirectSound reconstruction. Contributions by Roxas2712.
-- Existing project licences and LICENSE-ROXAS2712.md apply by provenance.
-- Parameters follow the edition's sound.c; gains follow TrkVolPitSet,
-- ChnVolSetAsm and SoundMain, with the same masterVolume=12 as music.
local V={frameRate=16777216/280896}
local modes={
 [0]={140,0,15360,0,false},[1]={20,225,15360,0,false},
 [2]={140,225,15600,20,false,90},[3]={50,200,15800,20,false,90},
 [4]={25,100,15600,192,true,90},[5]={140,200,14440,0,false},
 [6]={140,220,15555,192,false,90},[7]={10,100,14848,0,false},
 [8]={60,225,15616,0,false},[9]={15,125,15200,0,true},
 [10]={100,225,15200,0,false},[11]={140,0,15000,0,false},[12]={20,225,15000,0,false}}
local rs={ [2]={30,225,15600,20,false,80},[3]={50,200,14800,0,false},
 [4]={20,220,15800,0,false},[5]={140,200,14500,0,false} }
function V.params(edition,options)
 options=options or {};local m=tonumber(options.mode)or 0
 local old=edition=='ruby'or edition=='sapphire'
 if m%1~=0 or not modes[m]or(old and m>5)then m=0 end
 local row=old and rs[m]or modes[m]
 local volume=row[6]or tonumber(options.cryVolume)or(old and 125 or 120)
 if edition=='emerald'and m==6 then volume=70 end
 return {mode=m,length=row[1],release=row[2],pitch=row[3],chorus=row[4],reverse=row[5],volume=volume}
end
function V.gains(volume,pan,env)
 local x=(volume%128)*2;local y=math.max(-128,math.min(127,2*(tonumber(pan)or 0)))
 local ml=math.floor((127-y)*x/256)%256;local mr=math.floor((128+y)*x/256)%256
 local l=math.min(255,math.floor(127*127*ml/16384));local r=math.min(255,math.floor(128*127*mr/16384))
 local e=math.floor(13*env/16)
 return math.floor(l*e/256)/256,math.floor(r*e/256)/256
end
local function sample(pcm,pos)
 local i=math.floor(pos);if i<0 or i>=#pcm then return 0 end
 local a=pcm:byte(i+1);local b=i+1<#pcm and pcm:byte(i+2)or a
 if a>=128 then a=a-256 end;if b>=128 then b=b-256 end
 return (a+(b-a)*(pos-i))/128
end
function V.render(pcm,rate,params,options,cancelled)
 options=options or {};local outRate=options.outRate or 44100
 if cancelled and cancelled()then return nil end
 local b=(params.pitch+128)%65536;if b>=32768 then b=b-65536 end
 local key=math.floor(b/256)%128;local tune=math.floor(b/2)%128
 local tunes={tune};if params.chorus%256~=0 then
  local chorus=params.chorus%256;if chorus>=128 then chorus=chorus-256 end
  tunes[2]=(tune+chorus)%128
 end
 local tail={};local env=255
 repeat env=math.floor(env*params.release/256);if env>0 then tail[#tail+1]=env end until env==0
 local endFrame=params.length+#tail;local cap=math.ceil(endFrame*outRate/V.frameRate)
 local voices={};local count=0
 for _,t in ipairs(tunes)do
  local step=rate*2^(((key-60)*64+t-64)/(64*12))/outRate
  local size=math.min(math.ceil(#pcm/step),cap)
  voices[#voices+1]={step=step,n=size};count=math.max(count,size)
 end
 if options.seconds then count=math.min(count,math.max(1,math.floor(outRate*math.min(5,options.seconds))))end
 local channels=options.mono and 1 or 2
 local sd=love.sound.newSoundData(math.max(1,count),outRate,16,channels)
 local reverse=params.reverse or options.reverse;local peak=0
 for i=0,count-1 do
  if cancelled and i%1024==0 and cancelled()then
   if sd.release then sd:release()end
   return nil
  end
  local frame=math.floor(i*V.frameRate/outRate)
  local e=frame<params.length and 255 or(tail[frame-params.length+1]or 0)
  local l,r=V.gains(params.volume,options.pan,e);local sum=0
  for _,v in ipairs(voices)do if i<v.n then
   local pos=i*v.step;if reverse then pos=#pcm-1-pos end
   sum=sum+sample(pcm,pos)
  end end
  local a,b=sum*l*(options.volume or 1),sum*r*(options.volume or 1)
  peak=math.max(peak,math.abs(a),math.abs(b))
  a,b=math.max(-1,math.min(1,a)),math.max(-1,math.min(1,b))
  if channels==2 then sd:setSample(i,1,a);sd:setSample(i,2,b)else sd:setSample(i,(a+b)/2)end
  if options.checkpoint and i%128==127 then options.checkpoint()end
 end
 return sd,{rate=rate,sourceSamples=#pcm,outputSamples=count,voices=#voices,mode=params.mode,
  compressed=true,reverse=not not reverse,peak=peak}
end
return V
