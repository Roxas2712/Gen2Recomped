local T=require('tests.harness')
love=require('tests.love_stub')
require('src.core.ModCompat').install()
local ok,Anim=pcall(require,'src.ui.gen2.EvolutionAnim')
T.check(ok,'released GSC mod can import its evolution presentation')
if not ok then print(tostring(Anim));T.finish()end
T.eq(Anim,require('src.compat.gen2.EvolutionAnim'),'both names share the class patched by presentation mods')
local E=require('src.core.gen2.Evolution')
T.eq(E.flashFrames(),144,'cart flash schedule has 72 hold and 72 swap frames')
local rounds=E.flashRounds();rounds[1].wait=999
T.eq(E.flashRounds()[1].wait,16,'subclasses receive their own animation schedule')
T.eq(E.EVOLVING_FRAMES,50,'intro timing remains the GSC contract')
T.eq(E.BALL_SPAWN_FRAMES+E.BALL_TAIL_FRAMES,64,'reveal timing remains the GSC contract')

-- External mods inherit the class and override phase/commit endpoints;
-- replacing it with the shared EvolutionState would not run this protocol.
local Child=setmetatable({},{__index=Anim});Child.__index=Child
local writes,completed=0,0
function Child:commit()writes=writes+1 end
function Child:setPhase(phase)
 if phase=='picAnim'then return self:setPhase('congrats')end
 if phase=='paragraph'then
  self.phase='done';completed=completed+1;return
 end
 return Anim.setPhase(self,phase)
end
local game={data={pokemon={OLD={name='Old'},NEW={name='New'}}},save={party={}},input={wasPressed=function()return false end}}
local s=setmetatable({game=game,data=game.data,mon={species='OLD',hp=10},
 oldSpecies='OLD',newSpecies='NEW',nick='TEST',newName='New',
 rounds=E.flashRounds(),picCache={},balls={},ballFrame=0,force=true},Child)
s:setPhase('evolving')
local phases={}
for frame=1,1000 do
 phases[s.phase]=true;s:update(1/60)
 if s.phase=='done'then break end
end
T.check(phases.evolving and phases.cry and phases.flash and phases.reveal and phases.congrats,'inherited update reaches all GSC movie beats')
T.eq(completed,1,'consumer completion runs once')
T.eq(writes,0,'presentation-only subclass never commits an evolution')
T.eq(s.mon.species,'OLD','temporary visual transformation preserves species')
T.check(s.showNew and not s.blackout,'reveal ends with the new pic in colour')
s:update(1/60);T.eq(completed,1,'done updates do not replay completion')

local Sprites=require('src.pokemon.Sprites')
local Runtime=require('src.mods.Runtime')
local oldWants,oldCall=Runtime.wantsHook,Runtime.call
local calls=0
Runtime.wantsHook=function(name)return name=='pokemon.sprite'end
Runtime.call=function(name,base,path,ctx)
 calls=calls+1;T.eq(ctx.kind,'evolution','legacy pic preserves scene context')
 ctx.trueColor=true;return 'mod-mega.png'
end
local path,trueColor=Sprites.pic('old.png',{data=game.data,species='OLD',kind='evolution',mon=s.mon})
T.eq(path,'mod-mega.png','legacy pic uses the live native sprite hook')
T.check(trueColor,'hook true-colour result survives the legacy helper')
T.eq(calls,1,'legacy helper calls the sprite seam once')
Runtime.wantsHook,Runtime.call=oldWants,oldCall

-- The evolution scene uses idle first, then its wait/cry, then play.
-- A native battle PicAnim would play first and append idle afterwards.
game.data.pokemon.NEW.spriteFront='native-still.png'
game.data.pokemon.NEW.picAnim={sheet='native-strip.png',count=1,width=8,height=8,
 idle={{frame=0,dur=2}},play={{frame=1,dur=3}}}
local movie=setmetatable({game=game,data=game.data,mon={species='OLD',hp=10},
 newSpecies='NEW',picCache={},balls={}},Anim)
local cries=0
function movie:playCry()cries=cries+1 end
movie:setPhase('picAnim')
T.eq(movie.picAnim.which,'idle','GSC evolution selects native idle before play')
T.eq(cries,0,'new pic cry waits for the idle prelude')
for i=1,2 do movie:update(1/60)end
T.eq(movie.picStage,'wait','idle finishes before the scene wait')
for i=1,17 do movie:update(1/60)end
T.eq(cries,0,'GSC scene retains the 18-frame wait')
movie:update(1/60)
T.eq(cries,1,'new pic cry starts with the main animation')
T.eq(movie.picAnim.which,'play','GSC evolution selects native play after its cry')
for i=1,3 do movie:update(1/60)end
T.eq(movie.phase,'congrats','GSC evolution does not append the battle idle tail')
T.finish()
