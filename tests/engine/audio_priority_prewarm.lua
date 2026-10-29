package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local Sound=require('src.core.Sound');local Chip=require('src.core.ChipAudio')
local P=require('src.core.Performance')
local requests,replies,plays,builds={}, {},0,0
local oldRequest,oldPoll,oldCancel=Chip.requestEffect,Chip.pollEffect,Chip.cancelEffects
local oldPrioritize=Chip.prioritizeEffects
local promotions,priorityFlags={},{}
Chip.prioritizeEffects=function(id)promotions[#promotions+1]=id or 'new'end
Chip.requestEffect=function(spec,priority)requests[#requests+1]=spec;priorityFlags[#requests]=priority;return #requests end
Chip.pollEffect=function()return table.remove(replies,1)end
Chip.cancelEffects=function()replies={}end
local oldAudio=love.audio
love.audio={newSource=function(sd)
  builds=builds+1
  return{sd=sd,setVolume=function()end,stop=function()end,play=function()plays=plays+1 end,
    release=function()end,isPlaying=function()return false end}
end}
local data={audio={sfx={AMBIENT={address=10},Press_AB={address=11},HIT={address=12}},
 cries={LEAD={header={address=21},pitch=4,length=128}}},
 moves={TACKLE={anim={sound='HIT',pitch=3,tempo=120}}}}
Sound.invalidate()
T.eq(Sound.prewarmCry(data,'LEAD'),true)
T.eq(Sound.prewarmCry(data,'LEAD'),false,'duplicate hints share one job')
Sound.update(data)
T.eq(requests[1].header.address,21,'imminent cry precedes the entire SFX registry')
T.eq(priorityFlags[1],true,'priority metadata reaches the worker transport')
T.eq(plays,0);T.eq(builds,0,'queueing and dispatch create no Sources')
T.eq(Sound.prewarmCry(data,'LEAD'),false,'in-flight hints cannot queue a duplicate')
replies[1]={id=1,sd={getSize=function()return 128 end}}
Sound.update(data)
T.eq(builds,1);T.eq(plays,0,'acceptance is silent')
local built=builds
Sound.playCry(data,'LEAD')
T.eq(builds,built,'real cry playback consumes the normal warmed cache')
T.eq(plays,1,'only actual playback plays a Source')
Sound.invalidate();requests={}
T.eq(Sound.prewarmMove(data,data.moves.TACKLE.anim),true)
data.audio.sfx.HIT.address=99
Sound.update(data)
T.eq(requests[1].header.address,99,'hints resolve a definition edited before dispatch')
T.eq(requests[1].options.frequencyOffset,3,'native move pitch is preserved')
T.eq(requests[1].options.frameTicks,248,'native move tempo is preserved')
Sound.update(data)
for _=1,100 do Sound.update(data)end
T.eq(#requests,2,'pending worker work remains bounded')
Sound.invalidate();requests={}
local mon={species='LEAD',moves={{id='TACKLE'}}}
local battle={data=data,player={mon=mon},enemy={mon=mon},enemyParty={mon},playerPartyView=function()return{mon}end}
Sound.prewarmBattle(battle);Sound.update(data)
T.eq(requests[1].header.address,21,'native battle planning prioritizes active cries')
Sound.invalidate();requests={}
P.audioPriorityPrewarm=false
T.eq(Sound.prewarmCry(data,'LEAD'),false,'rollback refuses hints')
Sound.update(data)
T.check(requests[1].header.address~=21,'rollback retains the original SFX-first scan')
P.audioPriorityPrewarm=true
Sound.suspend();requests={}
T.eq(Sound.prewarmCry(data,'LEAD'),false,'suspension rejects new work')
Sound.update(data);T.eq(#requests,0,'suspension cannot send jobs')
Sound.resume();Sound.invalidate()
local other={audio={sfx={},cries={OTHER={header={address=45},length=128}}}}
Sound.prewarmCry(data,'LEAD');Sound.prewarmCry(other,'OTHER');requests={};Sound.update(other)
T.eq(requests[1].header.address,45,'dataset switch retires previous hints')
Sound.invalidate();requests={}
promotions={}
Sound.update(data)
local name
for key,def in pairs(data.audio.sfx)do if def.address==requests[1].header.address then name=key end end
T.check(name~=nil,'registry submitted a native SFX')
T.eq(Sound.prewarmSfx(data,name),false,'already pending work is promoted without duplicating it')
T.eq(promotions[1],1,'the running registry request becomes urgent by its native job ID')
T.eq(#requests,1,'promotion cannot enqueue a duplicate render')
Sound.prewarmSfx(data,name);T.eq(#promotions,1,'repeated hints retain one in-flight promotion')
replies[1]={id=1,cancelled=true};Sound.update(data)
T.eq(requests[2].header.address,requests[1].header.address,
  'a background request cancelled just before promotion retains its demand hint')
T.eq(priorityFlags[2],true,'racing cancelled promotion is retried as urgent work')
Sound.invalidate();requests={}
data.audio.sfxIndex={['7']='HIT'}
data.battle_anims={generation=2,moves={TACKLE='native'},scripts={native={code={
  {op='call',target='sub'},{op='sound',args={0,1,7}}}},sub={code={{op='jump',target='sub'}}}}}
Sound.prewarmAnimation(data,'TACKLE');Sound.update(data)
T.eq(requests[1].header.address,99,'native GSC animation IDs use the imported SFX index')
T.eq(plays,1,'animation scanning never executes its command VM')
Sound.invalidate();Chip.requestEffect,Chip.pollEffect,Chip.cancelEffects=oldRequest,oldPoll,oldCancel
Chip.prioritizeEffects=oldPrioritize
love.audio=oldAudio
T.finish('Prioritized native audio: ordering, keys, silence, bounds and retirement')
