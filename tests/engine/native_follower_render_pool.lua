-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local Objects=require('src.core.game3.objects')
local Follower=require('src.compat.game3.Follower')
local Optional=require('src.world.OptionalFollower')
local G=require('src.core.Game3')
local Host=require('src.mods.Runtime')
local NPC=require('src.world.NPC')
for _,edition in ipairs{'firered','leafgreen','emerald','ruby','sapphire'}do
 Objects.release();G.release()
 local f=require('tools.session-runtime.fixture').new(edition);local g,w,p=f.game,f.world,f.player
 w.npcs={};w.entities={p}
 local follower=Optional._checkpointCreate(g,w)
 T.eq(follower.optionalFollower,true)
 local bystander=setmetatable({id='native_obj_1',def={index=1,graphicsId=42},
  sprite={def={id='SPRITE_G3_042',frames=9}},cellX=5,cellY=5,px=80,py=80,
  facing='down',moving=false,progress=0,animClock=0,stepFlip=false},NPC)
 w.npcs[#w.npcs+1]=bystander;w.entities[#w.entities+1]=bystander
 local view=Objects.find(250)
 T.eq(Follower.current(),view,'follower presentation retains the same native record')
 T.eq(Objects.find(1).id,bystander.id)
 local rows=Objects.forDraw();T.eq(#rows,1,'the separate follower is not rendered again as an ordinary NPC')
 if #rows==1 then T.eq(rows[1],Objects.find(1))end
 local ordinary=Objects.find(1);ordinary.optionalFollower=true
 T.eq(#Objects.forDraw(),1,'a source extension cannot disguise a native NPC as a follower')
 T.eq(bystander.optionalFollower,nil)
 Host.currentMod='follower_probe'
 view.sprite=nil;T.eq(Follower.actor(),nil,'empty-party follower has no source artwork')
 T.eq(#Objects.forDraw(),1,'explicitly absent follower art cannot become a duplicate player')
 local renderer={draw=function()end}
 view.sprite=renderer
 local actor=Follower.actor();T.check(actor~=nil);T.eq(actor and actor.renderer,renderer)
 T.eq(#Objects.forDraw(),1,'the separately presented follower is emitted only once')
 T.eq(w.follower,follower);T.eq(w.entities[2],follower,'observation preserves native update and draw membership')
 T.eq(follower.px,p.px);T.eq(follower.py,p.py,'presentation queries do not move the native follower')
 require('src.core.game3.asset_stream').cancelOwner('follower_probe')
 T.eq(Follower.actor(),nil);T.eq(#Objects.forDraw(),1)
 Host.currentMod=nil;Objects.release();G.release()
end
T.finish('native followers retain a separate source presentation path')
