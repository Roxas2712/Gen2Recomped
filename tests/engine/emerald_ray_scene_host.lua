-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
love=require('tests.love_stub');local T=require('tests.harness')
local S=require('src.core.SaveSerializer');local V=require('src.core.GameVersion')
local A=require('src.import.Gen3EmeraldRaySceneAssets')
local saved,changed={},{};local function replace(key,value)
 saved[key]=package.loaded[key];changed[#changed+1]=key;package.loaded[key]=value
end
local frames,draws,clears,releases,resumed,pops,restored,stopped=0,0,0,0,0,0,0,0
local options,bindings,drawFailure,privateAudio
replace('src.core.Music',{current=function()return nil end,stop=function()stopped=stopped+1 end,
 playMap=function()restored=restored+1 end})
replace('src.ui.Gen3EmeraldSceneContext',{new=function(_,opts)
 bindings=opts.bindings;privateAudio={playSong=function(id)return id end}
 return{canvas={release=function()releases=releases+1 end},load=function(key)
  if key=='src.core.game3.audio'then return privateAudio end
  if key=='src.core.game3.gba_ppu'then return{clearCache=function()clears=clears+1 end}end
  if key=='src.ui.game3.rse.rayquaza_scene'then return{new=function(opts)
   options=opts
   return{done=false,frame=function(self)frames=frames+1;if frames==3 then self.done=true end end,
    draw=function()draws=draws+1;if drawFailure then error('authored native draw failure')end end}
  end}end
  if key=='src.ui.game3.rse.scene_kit'then return{stepper=function()return{
   collect=function()end,run=function(_,_,fn)return fn({})end}end}end
  error('Unexpected private scene dependency '..key)
 end}
end})
local M=require('src.ui.Gen3EmeraldRayScene')
local game={data={constants={gen3EmeraldRayScene={format=1,version='emerald',manifest=A.ROOT..'manifest.lua',
 resources=A.resources(),descendsTopByteOffset=0x200,song=401,rayquaza=406}}},save={party={{hp=83}},flags={KEEP=true}},input={},
 overworld={map={id='MAP_G00_N07'},player={}}}
local top;game.stack={top=function()return top end,pop=function()
 pops=pops+1;local old=top;top=nil;old:exit()
end}
for _,edition in ipairs{'ruby','sapphire','firered','leafgreen'}do V.set(edition);T.eq(M.available(game),false)end
V.set('emerald');T.eq(M.available(game),true)
local before=S.encode(game.save)
local screen=M.new(game,{part=1,onDone=function()T.eq(top,nil,'pop precedes script resume');resumed=resumed+1 end});top=screen
T.eq(options.animId,1);T.eq(options.endEarly,false)
local constants=bindings['src.core.game3.constants'].of('emerald')
T.eq(constants:require('songs','MUS_RAYQUAZA_APPEARS'),401)
T.eq(constants:require('species','SPECIES_RAYQUAZA'),406)
T.eq(privateAudio.playSong(0),nil);T.eq(stopped,1,'native song0 stops instead of playing a fake song')
T.eq(privateAudio.playSong(401),401,'native music ID is forwarded unchanged')
local g=love.graphics;local old={}
local graphicsKeys={'getCanvas','setCanvas','getScissor','setScissor','push','pop','getStackDepth','origin','setShader','clear','setColor','draw'}
for _,key in ipairs(graphicsKeys)do old[key]=g[key]end
local caller={};local canvas=caller;local depth=0
g.getCanvas=function()return canvas end;g.setCanvas=function(value)canvas=value end
g.getScissor=function()return 1,2,3,4 end;g.setScissor=function()end
g.getStackDepth=function()return depth end;g.push=function()depth=depth+1 end;g.pop=function()depth=depth-1 end
for _,key in ipairs{'origin','setShader','clear','setColor','draw'}do g[key]=function()end end
screen:draw();T.eq(canvas,caller,'native draw restores caller canvas');T.eq(depth,0)
drawFailure=true;T.eq(pcall(screen.draw,screen),false,'native rendering error remains visible')
T.eq(canvas,caller,'failed native draw still restores caller canvas');T.eq(depth,0)
for _,key in ipairs(graphicsKeys)do g[key]=old[key]end
for _=1,3 do screen:update(1/60)end
T.eq(frames,3);T.eq(draws,2);T.eq(resumed,1);T.eq(pops,1)
T.eq(releases,1);T.eq(clears,1);T.eq(restored,1,'native return resumes map audio')
screen:update(1/60);screen:finish();T.eq(resumed,1,'completed host owner cannot resume twice')
T.eq(S.encode(game.save),before,'native view lifecycle leaves gameplay SAVE unchanged')
local pre=M.new(game,{part=0});T.eq(options.animId,0);T.eq(options.endEarly,true);pre:exit()
T.eq(resumed,1,'closing an unstarted view cannot resume a different script owner')
for _,key in ipairs(changed)do package.loaded[key]=saved[key]end
T.finish('Emerald native cinematic ownership, audio IDs, graphics error cleanup and one-shot script return')
