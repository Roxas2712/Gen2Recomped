package.path='./?.lua;'..package.path
love=require('tests.love_stub');love.graphics.polygon=function()end
local count=0;local function check(v,m)assert(v,m);count=count+1 end
local current=10;love.timer.getTime=function()return current end
local scene={available=true};local doc={account_id='1',visitors={},preferences={visibility_enabled=true,friends={}}}
package.loaded['src.cloud.Play']={read=function()return doc end,context=function()return scene end}
local spriteCalls=0
package.loaded['src.render.SpriteRenderer']={new=function(def)return {def=def,draw=function()spriteCalls=spriteCalls+1 end}end}
local sprites={};for _,id in ipairs({'SPRITE_BLUE','SPRITE_KRIS','SPRITE_RED','SPRITE_LASS','PROP'}) do sprites[id]={id=id,image=id..'.png',walker=id~='PROP'} end
local game={data={sprites=sprites,field={playerForms={boy={walk='SPRITE_RED'},girl={walk='SPRITE_KRIS'}}}},save={flags={safe=true},party={'untouched'}}}
package.loaded['src.core.Game']=game
local world={map={id='PALLET'},player={sprite={def=sprites.SPRITE_RED}},entities={{px=16,py=16}},npcs={},runner={}}
local R=require('src.world.RemotePlayers')
for i=1,7 do doc.visitors[i]={account_id=tostring(i+1),device='device'..i,nickname='Friend'..i,character_seed=i,position={map='PALLET',x=i*16,y=32,facing='left'}} end
local actors=R.actors(world)
check(#actors==5,'only five distinct friends render even if a malformed server response contains more')
local entities=R.entities(world,world.entities)
check(#entities==6 and #world.entities==1 and not next(world.npcs),'render actors never enter world entities or NPC lookup')
check(game.save.flags.safe and game.save.party[1]=='untouched','presentation never writes the adventure save')
check(not actors[1].update and not actors[1].tryMove and not actors[1].script,'remote actors have no AI, collision movement or script hooks')
actors[1]:draw(0,0);check(spriteCalls==1,'native character art and overhead nameplate render without world simulation')
local first=actors[1];local x=first.px;doc.visitors[1].position.x=x+16;current=current+.05
actors=R.actors(world);check(actors[1]==first and first.px>x and first.px<x+16,'network movement interpolates on the same transient actor')
local def,id=R.spriteChoice(game.data,1);check(id=='SPRITE_BLUE' and def.walker,'rivals have the largest weighted assignment bucket')
for seed=1,100 do local _,a=R.spriteChoice(game.data,seed);local _,b=R.spriteChoice(game.data,seed);check(a==b and a~='PROP','account seed deterministically selects a walking character') end
-- Different local player selection must not change the friend assignment.
world.player.sprite.def=sprites.SPRITE_KRIS;check(select(2,R.spriteChoice(game.data,1))=='SPRITE_BLUE','assignment does not depend on the viewer gender or local player sprite')
doc.visitors[2]=doc.visitors[1];actors=R.actors(world);local seen={};for _,a in ipairs(actors)do check(not seen[a.account_id],'one account is drawn only once across devices');seen[a.account_id]=true end
doc.preferences.friends={{account_id='2',visible=false}};for _,a in ipairs(R.actors(world))do check(a.account_id~='2','per-friend exclusion also applies locally')end
doc.preferences.visibility_enabled=false;check(#R.actors(world)==0,'global privacy switch hides all figures immediately')
doc.preferences.visibility_enabled=true;world.map.id='OTHER';check(R.entities(world,world.entities)==world.entities,'other maps keep the exact original render list')
world.map.id='PALLET';scene.available=false;check(#R.actors(world)==0,'scripts, battles and unavailable overworlds hide transient actors')
scene.available=true
local opened,selected
package.loaded['src.ui.RetroOverlay']={open=function(g)opened=g end,action=function(a)selected=a end}
local actors2=R.actors(world);check(#actors2>0,'friends reappear only while their current presence is available')
check(R.interact(world,actors2[1].cellX,actors2[1].cellY) and opened==game and selected=='friends','talking opens the private friend action menu instead of running a world script')
doc=nil;check(#R.actors(world)==0,'sign-out or expired presence drops every transient figure')
print('Transient friends: '..count..' checks passed')
