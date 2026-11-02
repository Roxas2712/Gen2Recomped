-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Real pinned tasks, palette, scanline, OAM and affine logic. Authored empty
-- geometry replaces image decoding only; native renderer acceptance is separate.
package.path='./?.lua;./?/init.lua;'..package.path
love=require('tests.love_stub');local T=require('tests.harness')
-- Native indexed layers set nearest filtering on their image resource.
-- Keep this renderer boundary local to this synthetic-image fixture.
local originalNewImage=love.graphics.newImage
love.graphics.newImage=function(...)
 local image=originalNewImage(...)
 image.setFilter=function()end
 return image
end
local A=require('src.import.Gen3EmeraldRaySceneAssets')
local man={layers={},sprites={},palettes={},smokeCoords={}}
for i=1,10 do man.smokeCoords[i]={i-5,5-i}end
for _,path in ipairs(A.resources())do
 local key=path:match('/([^/]+)_idx%.png$')
 if key then
  local size=key=='ca_ring'and 128 or 256
  man.layers[key]={index=path,w=size,h=size,bpp=(key=='tf_rayquaza'or key=='ca_ring')and 8 or 4}
 else
  key=path:match('/([^/]+)%.png$')
  if key then
   local anims={};for i=1,9 do anims[i]={{op='frame',frame=0,duration=32},{op='jump',target=0}}end
   man.sprites[key]={png=path,w=8,h=8,frames=1,anims=anims,paletteTag=30505,
    affineMode=key=='tf_smoke'and 1 or 0,
    affineAnims={{{op='frame',xScale=256,yScale=256,duration=0},{op='end'}}}}
  end
 end
end
for key,count in pairs{duo_clouds=32,duo_groudon=16,duo_kyogre=16,tf_rayquaza=32,tf_smoke=16,
 de_bg=32,ch_bg=64,ca_bg=48,ca_groudon=16,ca_kyogre=16,ca_rayquaza=16,ca_splash=16}do
 man.palettes[key]={};for i=1,count do man.palettes[key][i]=i end
end
local originalLoad=love.filesystem.load
love.filesystem.load=function(path)
 if path==A.ROOT..'manifest.lua'then return function()return man end end
 return loadfile(path)
end
local function scenario(part)
 local effects,songs,cries,random={}, {},0,0
 local ids=setmetatable({},{__index=function(t,key)local id=#effects+100;rawset(t,key,id);return id end})
 local load=require('compat.gen1-rs.Loader').new('emerald',{
  ['src.core.GameVersion']={get=function()return'emerald'end},
  ['src.core.game3.constants']={of=function()return{require=function(_,family)
   return family=='species'and 406 or 401
  end}end},
  ['src.core.game3.se_ids']=ids,
  ['src.core.game3.audio']={playSong=function(id)songs[#songs+1]=id end,
   playSe=function(id)effects[#effects+1]=id end,playCry=function(id)T.eq(id,406);cries=cries+1 end},
  ['src.core.game3.indexed_png']={indexImage=function()return{
   getWidth=function()return 8 end,getHeight=function()return 8 end}end},
 })
 local Native=load('src.ui.game3.rse.rayquaza_scene')
 local finished=0;local scene=Native.new({animId=part,endEarly=part==0,
  random=function()random=random+1;return 12345 end,onDone=function()finished=finished+1 end})
 local held={isDown=function()return true end,wasPressed=function()return true end}
 local visited={}
 for _=1,12000 do
  visited[scene.animId]=true;scene:frame(held)
  if scene.done then break end
 end
 T.eq(scene.done,true,'original tasks reach their end under held buttons')
 T.eq(finished,1,'one native completion')
 T.check(scene.frames>328,'original cinematic cannot end at the old150-frame hold')
 for _=1,10 do scene:frame(held)end
 T.eq(finished,1,'finished native tasks never callback twice')
 if part==0 then
  T.eq(cries,0,'prelude does not play Rayquaza finale')
  T.eq(visited[1],nil,'prelude exits after its first screen')
 else
  for id=1,6 do T.eq(visited[id],true,'full film reaches original phase'..id)end
  T.eq(cries,1,'finale uses Rayquaza species cry once')
  T.check(random>0,'shake uses update-owned random source')
  T.check(scene.frames>1500,'full sequence retains its extended native timings')
  local stopped,started=false,false
  for _,id in ipairs(songs)do if id==0 then stopped=true elseif id==401 then started=true end end
  T.eq(stopped,true);T.eq(started,true,'Rayquaza music belongs to the full sequence')
 end
 T.check(#effects>0,'native weather and cinematic sound requests are retained')
 return scene.frames
end
local pre,full=scenario(0),scenario(1)
T.check(full>pre,'both halves retain their different original scope')
love.filesystem.load=originalLoad
love.graphics.newImage=originalNewImage
T.finish('Pinned Emerald cinematic native task sequence and unskippable completion')
