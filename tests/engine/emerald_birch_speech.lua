-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
love=require('tests.love_stub')
love.filesystem.load=function(path)return loadfile(path)end
local T=require('tests.harness')
local A=require('src.import.Gen3EmeraldBirchAssets')
local syms=require('compat.gen1-rs.Loader').new('emerald')('src.import.gba.syms').of('emerald')
local ball=A.ballConfig(syms)
T.eq(ball.particle_sheets,0x5e5094,'own Emerald particle descriptor table')
T.eq(ball.particle_palettes,0x5e50f4,'own Emerald particle palettes')
T.eq(ball.fade_colors,0x5e5310,'own Emerald release colors')
T.eq(ball.sprite_sheets,0x32c400,'own Emerald ball picture descriptors')
T.eq(ball.sprite_palettes,0x32c460,'own Emerald ball palette descriptors')
T.eq(ball.open_ball_gfx,0xc02300,'own Emerald compressed open frame')
T.eq(syms.size('gSineTable'),640,'complete native320-entry sine table')
local Writer=require('src.import.LuaWriter')
local Fs=require('src.import.CacheFs')
local spec={format=1,version='emerald',manifest=A.ROOT..'manifest.lua',
  arrow=A.ROOT..'down_arrow.rgba',defaultNameCount=20,lotadSpecies=277,
  windows={dialogue={left=2,top=15,width=27,height=4},gender={left=3,top=5,width=6,height=4}},
  resources={},textIR={}}
for _,name in ipairs(A.LABELS)do spec.textIR[name]={{t='text',s='authored fixture'}}end
local man={format=1,game='emerald',layout='emerald',build='emerald',
  layers={bg={}},pics={},presetNames={male={},female={}},files={}}
for _,key in ipairs{'birch','brendan','may','lotad'}do
  local path=A.ROOT..key..'.png'
  man.pics[key]={w=64,h=64,frames=1,png=path};man.files[#man.files+1]=path
end
man.pics.brendan.trainerPic=91;man.pics.may.trainerPic=92;man.pics.lotad.species=277
for n=1,20 do man.presetNames.male[n]='M'..n;man.presetNames.female[n]='F'..n end
for _,path in ipairs{spec.manifest,spec.arrow,A.ROOT..'bg.png',A.ROOT..'bg_1.png',A.ROOT..'bg_2.png',A.ROOT..'bg_3.png'}do
  spec.resources[#spec.resources+1]=path
end
for _,path in ipairs(man.files)do spec.resources[#spec.resources+1]=path end
T.eq(A.validManifest(man,spec),true,'own Emerald pictures and all twenty defaults are admitted')
local oldRead,oldExists=Fs.read,Fs.exists
Fs.read=function(path)
  if path=='data/generated/constants.lua'then return Writer.encode({gen3EmeraldBirch=spec})end
  if path==spec.manifest then return Writer.encode(man)end
end
Fs.exists=function()return true end
T.eq(#A.missing(),0,'complete own professor cache is ready')
man.game='sapphire';T.eq(A.missing()[1],spec.manifest,'RS professor pack requires reimport');man.game='emerald'
man.pics.brendan.trainerPic=0;T.eq(#A.missing(),1,'RS player picture cannot satisfy Emerald');man.pics.brendan.trainerPic=91
man.pics.lotad.species=298;T.eq(#A.missing(),1,'another mascot cannot satisfy Lotad');man.pics.lotad.species=277
man.presetNames.female[20]=nil;T.eq(#A.missing(),1,'a reduced name list requires reimport');man.presetNames.female[20]='F20'
Fs.exists=function(path)return path~=spec.arrow end
T.eq(A.missing()[1],spec.arrow,'missing native arrow requires reimport')
Fs.exists=function()return true end
spec.resources[#spec.resources+1]='data/generated/gba/birch/rs.png'
T.eq(A.valid(spec),false,'another edition cannot be a declared professor resource')
table.remove(spec.resources)
Fs.read,Fs.exists=oldRead,oldExists

-- Exercise the public task interface without copying or rewriting the
-- pinned controller. Each private loader receives an independent table.
local Scene=require('src.ui.Gen3EmeraldBirchScene')
local function fixture()
  local tasks={ProcessNameYesNoMenu=function()return 'original choice policy'end}
  tasks.ReshowBirchAzurill=function(self,m)
    if not m.doneFading then return end
    self.sprites.birch.x,self.sprites.birch.y=136,64
    self.sprites.azurill.x,self.sprites.azurill.y=104,72
    m.doneFading=false
  end
  local base={TASKS=tasks}
  local kit={loadLua=function()return man end,manifest=function()return 'other pack'end,
    rgbaImage=function(...)return{...}end,
    printer=function()return{draw=function()end}end,
    yesNo=function(x,y)return{x=x,y=y}end}
  local chrome={stdFrame=function(...)return{...}end,userFrame=function(...)return{...}end,
    dialogueFrame=function()return{'own-message-box'}end}
  local cries={}
  local audio={playCry=function(id)cries[#cries+1]=id end}
  local pal={ALL=1,BLACK=0}
  base.returnFromNaming=function(self)self.gradState=0;self.main.timer=0 end
  base.event=function(self,name)self.events[#self.events+1]=name end
  base.new=function()
    local s={sprites={birch={},azurill={},brendan={},may={}},main={},events={},tasks={},
      pal={fadeActive=function()return false end},azurillSpecies=277,frameType=0}
    function s:printersActive()return false end
    function s:print(key,callback)self.printed=key;self.pauseCallback=callback end
    function s:createReleaseBall(mon,x,y,delay)self.release={mon=mon,x=x,y=y,delay=delay}end
    function s:createTask(fn,data)self.tasks[#self.tasks+1]={fn=fn,data=data,alive=true}end
    function s:presetNames()return man.presetNames.female end
    function s:enterNaming()self.namingOpened=true end
    return setmetatable(s,{__index=base})
  end
  local modules={['src.ui.game3.rse.scene_kit']=kit,['src.ui.game3.chrome']=chrome,
    ['src.core.game3.pal_fade']=pal,['src.core.game3.rng']={Random=function()return 19 end},
    ['src.core.game3.audio']=audio,['src.ui.game3.rs.birch_speech']=base}
  local context={load=function(name)return assert(modules[name],name)end}
  return Scene.new(context,spec,{}),tasks,cries,chrome,kit
end
local first,f,cries,chrome,kit=fixture()
local second,other=fixture()
T.eq(kit.rgbaImage('data/generated/gba/chrome/fonts/down_arrow.rgba',8,48)[1],spec.arrow,'dialogue printer reads the own Emerald arrow instead of a foreign chrome pack')
f.ThisIsAPokemon(first,first.main,{new={}})
T.eq(first.printed,'gBirchSpeech_ThisIsPokemon','original encoded message is selected')
T.eq(first.main.func,'MainSpeech','main printer continues independently of the release task')
T.eq(first.release,nil,'release waits for the encoded pause')
first.pauseCallback();first.pauseCallback()
T.eq(#first.tasks,1,'repeated pause callbacks create exactly one release')
T.eq(first.release.x,112,'native ball anchor')
T.eq(first.release.mon.x,100,'own Lotad horizontal anchor')
T.eq(first.release.mon.y,75,'own Lotad vertical anchor')
for _=1,31 do first.tasks[1].fn(first,first.tasks[1])end
T.eq(#cries,0,'release delay does not truncate the native cue')
first.tasks[1].fn(first,first.tasks[1])
T.eq(cries[1],277,'release cue belongs to Lotad')
T.eq(#second.tasks,0,'one scene cannot create tasks in another context')
f.StartNamingScreen(first,first.main)
T.eq(first.playerName,'F20','random default selects the twentieth native pointer')
T.eq(first.namingOpened,true,'keyboard opens directly without RS preset rows')
first:returnFromNaming()
T.eq(first.gradState,1,'return uses Emerald gradient')
T.eq(first.main.timer,5,'native dialogue return delay')
T.eq(first.showDialogue,false,'return waits before showing the dialogue frame')
first.main.doneFading=true;f.ReshowBirchAzurill(first,first.main)
T.eq(first.sprites.birch.y,60,'reshow fixes the anchor even after the fade resets its completion flag')
T.eq(first.sprites.azurill.y,75,'reshown Lotad retains the Emerald anchor')
f.CreateNameYesNo(first,first.main,{new={}})
T.same(first.yesNo,{x=2,y=1},'name confirmation uses the native Emerald window')
T.eq(other.ProcessNameYesNoMenu(),'original choice policy','ordinary yes/no behavior remains untouched')
T.same(chrome.stdFrame(3,14,24,4),{'own-message-box'},'professor dialogue uses its native message border rather than a user menu frame')
T.same(chrome.stdFrame(1,2,3,4),{1,2,3,4},'unrelated frame calls pass through')

-- Keyboard confirmation must pop its virtual stack, leave the actual
-- professor on top, and forward one result without changing the real save.
local Naming=package.loaded['src.ui.NamingScreen']
local active,proxy,exits
package.loaded['src.ui.NamingScreen']={new=function(game,opts)
  proxy=game;active=opts
  return{exit=function()exits=(exits or 0)+1 end,draw=function()end,update=function()end}
end}
local owner={};local game={save={player={name='BEFORE',gender='boy'},inventory={POTION=3}},
  stack={top=function()return owner end,pop=function()error('real professor popped')end}}
local before=Writer.encode(game.save);local results={}
local naming=require('src.ui.Gen3EmeraldBirchNaming').new(game)
naming.open({gender=1,seed='F20',onDone=function(name)results[#results+1]=name end})
T.eq(proxy.save.player.gender,'girl','keyboard icon sees the selected gender')
T.eq(active.maxLen,7,'player name retains the original bound')
proxy.stack:pop();active.onDone('MAY')
T.same(results,{'MAY'},'keyboard forwards the confirmed name')
T.eq(Writer.encode(game.save),before,'name entry leaves the authoritative save untouched')
T.eq(naming.isOpen(),true,'confirmed keyboard remains drawable through its fade')
naming.dismiss();T.eq(naming.isOpen(),false,'fade completion releases the embedded keyboard')
T.eq(exits,1,'virtual keyboard exit runs once')
package.loaded['src.ui.NamingScreen']=Naming
T.finish('Emerald professor assets, native task timing, naming return and owner isolation')
