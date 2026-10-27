package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.harness')
love={filesystem={load=loadfile},timer={getTime=function()return 12.345 end}}
local Loader=require('compat.gen1-frlg.Loader')
local function setup(edition)
  local events={};local stopped=false
  local load=Loader.new({
    ['src.core.game3.display']={W=240,H=160},
    ['src.render.PixelCanvas']={},
    ['src.core.GameVersion']={get=function()return edition end},
    ['src.core.game3.song_ids']={MUS_TITLE=278},
    ['src.core.game3.audio']={
      playSong=function(id)events.song=id;stopped=false end,
      playCry=function(id)events.cry=id end,
      fadeOutBgm=function(speed)events.fade=speed;stopped=true end,
      isBgmStopped=function()return stopped end,
    },
  })
  local native=load('src.ui.game3.title_screen');local state={assets={}}
  native.enter(state)
  local function frame(key,n)
    local result
    for i=1,n or 1 do
      result=native.update(state,{wasPressed=function(_,k)return i==1 and k==key end},280896/16777216)
    end
    return result
  end
  return state,native,frame,events,load
end
local globalRng=package.loaded['src.core.game3.rng']
local s,N,f,e,load=setup('leafgreen');f(nil,3)
T.eq(e.song,278,'native title starts its own MUS_TITLE after initialization')
f(nil,2);T.eq(s.title.band,128,'initial white band begins at original scanline')
f(nil,32);T.eq(s.title.band,0,'initial band moves four pixels per hardware frame')
local elapsed=34
while N.scene(s)~=3 and elapsed<1400 do f();elapsed=elapsed+1 end
T.eq(N.scene(s),3,'unskipped native fade/gray/flash/slide reaches RUN')
T.check(elapsed>190,'title no longer shortcuts the original sequence at 190 frames')
f();local t=s.title;local start=t.vblanks
T.eq(t.slash.data[2],539,'logo slash waits native 540-frame period')
T.eq(t.pressStartHidden,false,'press start initially visible')
f(nil,60);T.eq(t.pressStartHidden,true,'press start hides after sixty task frames')
f(nil,30);T.eq(t.pressStartHidden,false,'press start returns after thirty hidden frames')
local O=load('src.core.game3.oam');local streaks,leaves=0,0
for i=0,O.MAX_SPRITES-1 do local p=O._sprites[i];if p.inUse then
 if p.dims and p.dims.w==32 then streaks=streaks+1 end
 if p.data[1]and p.data[2]and not p.objWindow then leaves=leaves+1 end
end end
T.check(leaves>0,'native LeafGreen task spawns live leaf particles')
T.eq(package.loaded['src.core.game3.rng'],globalRng,'native RNG never replaces host require cache')
local snapshot=load('src.core.game3.rng').getState();f('b');T.eq(N.scene(s),3,'B in RUN does not open main menu')
T.same(load('src.core.game3.rng').getState(),snapshot,'RUN B does not reseed presentation RNG')
f('start');T.eq(N.scene(s),5,'START enters native CRY scene')
f();T.eq(e.cry,3,'LeafGreen plays Venusaur numeric cry')
local result;for _=1,200 do result=f();if result then break end end
T.eq(result,'menu','cry/slash/white-fade completes into host menu')
T.eq(e.fade,4,'menu departure uses native four-frame m4a fade speed')
N.leave(s);T.eq(s.title,nil,'leave drops native title state')
for i=0,O.MAX_SPRITES-1 do assert(not O._sprites[i].inUse)end
T.check(true,'leave destroys all presentation sprites')
s,N,f,e,load=setup('leafgreen');f(nil,6);f('b')
T.eq(N.scene(s),3,'B skips entrance to native RUN')
f(nil,2699-s.title.vblanks);T.eq(N.scene(s),3,'attract timer keeps title until vblank 2700')
f();T.eq(N.scene(s),4,'native vblank 2700 starts attract restart')
result=nil;for _=1,400 do result=f();if result then break end end
T.eq(e.fade,10,'attract restart uses native ten-frame m4a fade speed')
T.eq(result,'restart','attract fade and twenty-frame delay return to movie')
local isolated=load('src.core.game3.rng');isolated.SeedRng(42)
local other=Loader.new({})('src.core.game3.rng');T.eq(other.getState().value,0,'new title session has isolated native RNG')
T.eq(isolated.getState().value,42,'other loader cannot mutate previous RNG')
T.finish('Native FR/LG title controller')
