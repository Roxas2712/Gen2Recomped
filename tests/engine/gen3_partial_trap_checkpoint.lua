local T=require('tests.harness')
love=require('tests.love_stub')
local rng=714821
love.math.random=function(a,b)
  rng=(rng*48271)%2147483647
  if not a then return rng/2147483647 end
  if not b then a,b=1,a end
  return a+(rng%(b-a+1))
end
love.math.getRandomState=function()return tostring(rng)end
love.math.setRandomState=function(v)rng=assert(tonumber(v))end
love.math.newRandomGenerator=function()return{setState=function(_,v)assert(tonumber(v))end}end
local S=require('src.core.SaveSerializer')
for _,version in ipairs({'ruby','sapphire','firered','leafgreen','emerald'})do
  local f=require('tests.checkpoint_fixture').boot(version)
  local game,stack=f.game,f.stack
  game.save.options.battleAnimations=false
  local b=require('src.battle.BattleState').newWild(game,'FIXMON_B',15)
  b.phase,b.queue,b.introSlide='menu',{},0
  b.player.mon.hp,b.player.mon.stats.hp,b.player.shownHP=400,400,400
  b.enemy.mon.hp,b.enemy.mon.stats.hp,b.enemy.shownHP=400,400,400
  b.player.gbaWrapTurns,b.player.gbaWrapMove,b.player.gbaWrapSource=4,'FIX_TACKLE',1
  stack.states={f.world,b}
  local cp,why,detail=f.checkpoints:capture(game)
  T.check(cp~=nil,version..' captures native binding: '..tostring(why)..' '..tostring(detail))
  assert(cp)
  local bytes=S.encode(cp)
  local function restore()
    T.check(f.checkpoints:restore(game,cp),'actual checkpoint restore accepts native binding')
    local fresh=stack:top()
    T.eq(fresh.player.gbaWrapTurns,4,'remaining duration survives reconstruction')
    T.eq(fresh.player.gbaWrapMove,'FIX_TACKLE','binding move survives reconstruction')
    T.eq(fresh.player.gbaWrapSource,1,'physical source survives reconstruction')
    T.eq(S.encode(assert(f.checkpoints:capture(game))),bytes,'complete checkpoint round trip is byte stable')
    return fresh
  end
  local function turn()
    local fresh=stack:top()
    game.input.wasPressed=function(_,key)return key=='a'end
    game.input.pressed=game.input.wasPressed
    fresh:chooseMenu('fight');fresh:chooseMove(1)
    local ticks=0
    repeat fresh:update(1/60);ticks=ticks+1
    until(fresh.phase=='menu'and not fresh.current and #fresh.queue==0)or ticks>=4000
    T.check(ticks<4000 and fresh.phase=='menu','bound restored victim completes a real independently selected turn')
    T.eq(fresh.player.gbaWrapTurns,3,'restored native residual ticks exactly once')
    return S.encode(assert(f.checkpoints:capture(game)))
  end
  restore();local expected=turn()
  restore();T.eq(turn(),expected,'restored binding reproduces complete future action and RNG state')
  T.eq(S.encode(cp),bytes,'future continuation never mutates caller checkpoint bytes')
  f.close()
end
T.finish('five-edition partial trap checkpoint continuation')
