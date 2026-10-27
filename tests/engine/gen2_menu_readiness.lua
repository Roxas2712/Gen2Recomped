package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local World=require('src.world.OverworldController')
local running=false
local w=setmetatable({runner={isRunning=function()return running end},scriptMoves={},player={}}, {__index=World})
T.eq(w:scriptRunning(),false,'idle script owner')
T.eq(w:busy(),false,'idle world not busy');T.eq(w:acceptsMenuInput(),true,'idle world accepts menu')
running=true;T.eq(w:scriptRunning(),true,'actual native runner owns script');T.eq(w:acceptsMenuInput(),false,'scripts block menu');running=false
for _,key in ipairs({'engaging','emote','teleportOut','whirlSpin','gen4Waterfall','transitioning','flyAnim','fishing'})do
 w[key]={};T.eq(w:busy(),true,key..' busy');T.eq(w:acceptsMenuInput(),false,key..' blocks menu');w[key]=nil
end
w.scriptMoves[1]={};T.eq(w:acceptsMenuInput(),false,'script movement blocks menu');w.scriptMoves={}
w.pendingScripts={{}};T.eq(w:acceptsMenuInput(),false,'pending map setup blocks menu');w.pendingScripts=nil
w.player.moving=true;T.eq(w:busy(),false,'ordinary step is not a script');T.eq(w:acceptsMenuInput(),false,'mid-step menu deferred');w.player.moving=nil
w.player.inputLocked=true;T.eq(w:acceptsMenuInput(),false,'input owner lock retained');w.player.inputLocked=nil
w.iceSlide='left';T.eq(w:acceptsMenuInput(),false,'ice slide blocks menu');w.iceSlide=nil
w.battleActive=true;T.eq(w:acceptsMenuInput(),false,'battle blocks world menus');w.battleActive=nil
T.eq(w:acceptsMenuInput(),true,'readiness recovers after owners release')
local Version=require('src.core.GameVersion')
local Stack=require('src.core.StateStack')
local previous=Version.get()
local slot,oldGame
for i=1,100 do local name,value=debug.getupvalue(World.busy,i)
 if name=='Game'then slot,oldGame=i,value;break end;if not name then break end
end
assert(slot)
for _,edition in ipairs({'gold','silver','crystal'})do
 Version.set(edition)
 local s=setmetatable({}, {__index=Stack});s:init()
 local g={stack=s};s:setWorldOwner(g)
 local field=setmetatable({isOverworld=true,runner={isRunning=function()return running end},player={},scriptMoves={}}, {__index=World})
 g.overworld=field;s:push(field);debug.setupvalue(World.busy,slot,g)
 s:push({})
 T.eq(field:busy(),true,edition..' menu still blocks native movement wrappers')
 T.eq(field:acceptsMenuInput(),true,edition..' settled field can be observed beneath an overlay')
 running=true;T.eq(field:acceptsMenuInput(),false,'scripts still block underlying field readiness');running=false
 field.battleActive=true;T.eq(field:acceptsMenuInput(),false,'battles cannot become save/restart safe');field.battleActive=nil
 field.transitioning=true;T.eq(field:acceptsMenuInput(),false,'warp transitions remain unsafe');field.transitioning=nil
 field.player.moving=true;T.eq(field:acceptsMenuInput(),false,'underlying actor movement remains unsafe');field.player.moving=nil
 field.player.inputLocked=true;T.eq(field:acceptsMenuInput(),false,'field input locks remain unsafe');field.player.inputLocked=nil
 T.eq(field:busy(),true,'underlying readiness cannot release overlay movement ownership')
 s:pop();T.eq(field:busy(),false,'native movement resumes only after the overlay closes')
end
debug.setupvalue(World.busy,slot,oldGame);Version.set(previous)
T.finish('native Gen2 menu readiness')
