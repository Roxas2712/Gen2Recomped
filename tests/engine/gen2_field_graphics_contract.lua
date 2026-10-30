-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local Version=require('src.core.GameVersion')
local Game=require('src.core.Game')
local Assets=require('src.render.Assets')
local World=require('src.world.OverworldController')
local Player=require('src.world.Player')
local Sprite=require('src.render.SpriteRenderer')
local Commands=require('src.script.Commands')
local oldImage,oldDraw,oldData,oldSave=Assets.image,love.graphics.draw,Game.data,Game.save
local calls,reads={},0
local function picture(path)
  reads=reads+1
  local width,height=16,16
  if path:find('fishing')then width,height=16,40 end
  if path:find('cutGrass')then width,height=32,8 end
  if path:find('jumpShadow')or path:find('grassRustle')then width,height=8,8 end
  return {path=path,getDimensions=function()return width,height end}
end
Assets.image=picture
love.graphics.draw=function(...)calls[#calls+1]={...}end
local Art=require('src.world.Gen2FieldGraphics')
local data=T.fixtures.fresh();data.field=data.field or {}
local entries={}
for _,key in ipairs({'shock','question','happy','sad','heart','bolt','sleep','fish',
  'grassRustle','jumpShadow','cutGrass','fishing','fishingFemale'})do
  entries[#entries+1]=key..'='..string.format('%q','mods/probe/'..key..'.png')
end
Version.set('crystal')
local run=T.sdk.loadMods({'mods/art_probe'},{data=data,fs=T.sdk.memfs({
  ['mods/art_probe/manifest.json']=[[{"id":"art_probe","name":"Art probe","version":"1.0.0","api":2,"entry":"main.lua"}]],
  ['mods/art_probe/main.lua']='local mod=...;assert(mod.contentFormat=="native");mod.content.field:patch("emotes",{'..table.concat(entries,',')..'})',
})})
T.eq(#run.errors,0,'unchanged native API2 field patch reaches the actual data consumer')
Game.data=data;Game.save={player={gender='female'}}
local gameSlot,oldWorldGame
for i=1,100 do
  local key,value=debug.getupvalue(World._worldFxEmote,i)
  if not key then break end
  if key=='Game'then gameSlot,oldWorldGame=i,value;break end
end
assert(gameSlot,'native world game owner')
debug.setupvalue(World._worldFxEmote,gameSlot,Game)
local world={player={px=16,py=32,sprite={tileH=16}}}
Art.sync(world,data)
local warmReads=reads
for _=1,100 do Art.sync(world,data)end
T.eq(reads,warmReads,'warm frames never reload image assets')
local yields=0
local ctx={overworld=world,runner={yield=function()yields=yields+1 end,resume=function()end}}
for index,key in ipairs({'shock','question','happy','sad','heart','bolt','sleep','fish'})do
  calls={};Commands.emote(ctx,'player',key,12)
  T.eq(world.emote.bubble,index,'native script retains all eight emote identities')
  World._worldFxEmote(world,{x=0,y=0})
  T.eq(calls[1][1].path,data.field.emotes[key],'actual native effect draws selected mod image')
end
T.eq(yields,8,'native script timing still owns the hold')
data.field.emotes.order={'heart','question','happy','sad','shock','bolt','sleep','fish'}
T.eq(Art.emote(world,data,1).path,data.field.emotes.heart,'custom order changes the actual lookup')
local other={};Art.sync(other,data);world.emoteImages.heart={path='local-only'}
T.eq(other.emoteImages.heart.path,data.field.emotes.heart,'legacy world image holders are not shared mutable tables')
local p=setmetatable({}, {__index=Player})
Player.refreshFishTiles(p,data)
T.eq(p.fishTiles.up,data.field.emotes.fishingFemale,'Crystal female uses her declared whole sheet')
T.same(p.fishTileCrops.up,{0,8,16,8},'upward pose selects second strip')
T.same(p.fishTileCrops.right,{0,16,16,8},'right uses mirrored side strip')
Game.save.player.gender='boy';Player.refreshFishTiles(p,data)
T.eq(p.fishTiles.down,data.field.emotes.fishing,'male keeps his own declared sheet')
-- The native loose-tile renderer consumes the crop, not the whole 16x40 sheet.
local sprite={def={trueColor=true}}
calls={};Sprite.drawTile(sprite,p.fishTiles.up,10,20,false,p.fishTileCrops.up)
T.eq(calls[1][2]:getViewport(),0,'crop starts at first column')
local _,y,w,h=calls[1][2]:getViewport()
T.same({y,w,h},{8,16,8},'actual draw submits the selected 16x8 strip')
local quad=calls[1][2]
Sprite.drawTile(sprite,p.fishTiles.up,10,20,false,p.fishTileCrops.up)
T.eq(calls[2][2],quad,'warm pose reuses its quad')
T.eq(pcall(Sprite.drawTile,sprite,p.fishTiles.up,0,0,false,{0,40,16,8}),false,'invalid crop cannot sample beyond sheet')
calls={};T.check(Art.shadow(data,{px=16,py=32,facing='right'},0,0),'jump art is drawable')
T.eq(#calls,2,'GSC shadow is an OBJ pair')
T.eq(calls[1][1].path,data.field.emotes.jumpShadow,'shadow submits declared art')
calls={};T.check(Art.grass(world,data,{moving=true,grassShake=true,progress=3,px=16,py=32},0,0),'moving entity rustles')
T.eq(calls[1][1].path,data.field.emotes.grassRustle,'grass submits declared art')
T.eq(Art.grass(world,data,{moving=false,grassShake=true},0,0),false,'standing actor does not invent a rustle')
calls={};world.dustAnim={kind='cutGrass',x=1,y=2,frames=24}
World._worldFxDust(world,{x=0,y=0})
T.eq(#calls,4,'native cut state submits four leaf pieces')
T.eq(calls[1][1].path,data.field.emotes.cutGrass,'cut draws the declared sheet')
-- File replacement at the same path must refresh consumers after invalidation.
local image=Art.emote(world,data,1)
Assets.flush()
T.check(Art.emote(world,data,1)~=image,'asset invalidation replaces held images')
data.field.emotes=nil;Art.sync(world,data)
T.eq(world.emoteImages,nil,'removing the mod art clears legacy holders')
Player.refreshFishTiles(p,data)
T.eq(p.fishTileCrops,nil,'removing mod sheet restores native form/strip path')
Version.set('red')
data.field.emotes={shock='must-not-load.png'};local before=reads
T.eq(Art.emote(world,data,1),nil,'Gen1 keeps its original field art contract')
T.eq(reads,before,'Gen1 never opens Gen2 field art')
Assets.image,love.graphics.draw,Game.data,Game.save=oldImage,oldDraw,oldData,oldSave
debug.setupvalue(World._worldFxEmote,gameSlot,oldWorldGame)
run.release()
T.finish('Gen2 source-format field graphics through native consumers')
