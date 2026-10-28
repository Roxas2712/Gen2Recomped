-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local Game=require('src.core.Game')
local G=require('src.core.Game3')
local Version=require('src.core.GameVersion')
local Screens=require('src.ui.Screens')
local World=require('src.world.OverworldController')
local Save=require('src.core.SaveData')
local Speech=require('src.ui.Gen3OakSpeechFRLG')
local oldVersion,oldPush,oldNew=Version.get(),Screens.push,Save.newGame
local intro
local function session(screen)
 local definitions={OLD={},HOME={},FINAL={}}
 local g={data={maps=definitions,tilesets={},map_tilesets={},constants={gen3Layout={}},
  field={boot={screens={newGame=screen}}}},save={player={map='OLD'}},draws=0}
 g.bootConfig=function()return {screens={newGame=screen}}end
 g.adoptSave=function(self,save)T.eq(self.save,save,'new save adopted before native intro')end
 g.applyOptions=function()end
 local states={}
 local stack={states=states,top=function()return states[#states]end,
  pop=function()return table.remove(states)end,clearWorld=function(self)self.worldState=nil end}
 stack.push=function(self,factory,map,x,y,facing)
  T.eq(factory,World,'native world factory owns final admission')
  g.draws=g.draws+1
  local world={isOverworld=true,map={id=map,def=definitions[map]},player={cellX=x,cellY=y,facing=facing,gender=g.save.player.gender}}
  states[#states+1]=world;self.worldState=world;g.overworld=world
 end
 g.stack=stack
 local previous={isOverworld=true,map={id='OLD',def=definitions.OLD},player={},fadeOverlay={}}
 states[1]=previous;stack.worldState=previous;g.overworld=previous
 return g
end
Save.newGame=function()return {player={map='HOME',x=3,y=3,facing='down',gender='boy'},options={}}end
Screens.push=function(g,id,done)
 intro=id=='Gen3OakSpeechFRLG'and Speech.new(g,done)or{onDone=done}
 intro.screenId=id;g.stack.states[#g.stack.states+1]=intro;return intro
end
local function finish(screen)
 if getmetatable(screen)==Speech then screen:finish()else
  screen.onDone()
 end
end
for _,edition in ipairs({'firered','leafgreen','ruby','sapphire'})do
 Version.set(edition)
 local screen=(edition=='firered'or edition=='leafgreen')and'Gen3OakSpeechFRLG'or'Gen3RsBirchSpeech'
 local g=session(screen);local view=assert(G.forNative(g))
 T.eq(view.phase,'field',edition..' previous field was admitted')
 Game.newGame(g)
 T.eq(g.draws,0,edition..' does not construct a field beneath native introduction')
 T.eq(g.overworld,nil,edition..' retires the previous world pointer')
 T.eq(view.phase,'boot',edition..' facade remains boot while native introduction owns input')
 T.eq(g.stack:top(),intro,edition..' keeps actual native intro on top')
 g.save.player.name='QA';g.save.player.gender='girl';g.save.player.map='FINAL';g.save.player.x=7
 local current=intro;finish(current)
 T.eq(g.draws,1,edition..' introduction admits the world once')
 T.eq(g.overworld.map.id,'FINAL',edition..' world uses final introduction destination')
 T.eq(g.overworld.player.cellX,7,edition..' world uses final introduction position')
 T.eq(g.overworld.player.gender,'girl',edition..' avatar uses final introduction gender')
 T.eq(view.phase,'field',edition..' facade enters field after native completion')
 current.onDone();finish(current)
 T.eq(g.draws,1,edition..' duplicate completion cannot recreate the field')
 g=session(screen);Game.newGame(g);local stale=intro
 Game.newGame(g);finish(stale)
 T.eq(g.draws,0,edition..' replaced save retires stale completion')
 finish(intro);T.eq(g.draws,1,edition..' current native completion retains admission')
 g=session(false);Game.newGame(g)
 T.eq(g.draws,1,edition..' explicit no-introduction path remains immediate')
end
-- Emerald retains its existing world-under-Birch presentation; this fix is
-- specific to the native RS and FR/LG introductions with completion owners.
Version.set('emerald');local g=session('BirchSpeech');Game.newGame(g)
T.eq(g.draws,1,'Emerald retains its current native introduction lifecycle')
intro.onDone();T.eq(g.draws,1,'Emerald completion cannot add another world')
Screens.push,Save.newGame=oldPush,oldNew;Version.set(oldVersion)
T.finish('native GBA new-game introduction and field admission')
