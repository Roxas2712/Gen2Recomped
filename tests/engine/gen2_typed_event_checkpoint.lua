-- A derived status view must survive real semantic checkpoint reconstruction.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local Fixture=require('tests.checkpoint_fixture')
local Native=require('src.battle.BattleState')
local Version=require('src.core.GameVersion')
local previous=Version.get()
local rng=7183
love.math.random=function(lo,hi)
  rng=(rng*48271)%2147483647
  if not lo then return rng/2147483647 end
  if not hi then lo,hi=1,lo end
  return lo+rng%(hi-lo+1)
end
love.math.getRandomState=function()return tostring(rng)end
love.math.setRandomState=function(value)rng=assert(tonumber(value))end
love.math.newRandomGenerator=function()return{setState=function(_,value)assert(tonumber(value))end}end
for _,edition in ipairs({'gold','silver','crystal'})do
  local f=Fixture.boot(edition)
  local game=f.game
  local b=Native.newWild(game,'FIXMON_B',15)
  game.stack.states={f.world,b}
  b.queue,b.current,b.phase,b.afterQueue,b.introSlide={},nil,'resolving','menu',0
  b.enemy.mon.status='PSN'
  b:push({kind='status',side='enemy',mon=b.enemy.mon,status='BRN'})
  for _=1,8 do if b.phase=='menu'then break end;b:update(1/60)end
  T.eq(b.phase,'menu','typed status returns through actual native decision path')
  T.eq(b.shownStatus and b.shownStatus.enemy,'BRN','native status snapshot precedes checkpoint')
  local checkpoint,why,detail=f.checkpoints:capture(game)
  T.check(checkpoint~=nil,'derived view captures without opaque metatable: '..tostring(why)..' '..tostring(detail))
  if checkpoint then
    b.enemy.shownStatus=false
    local ok,code=f.checkpoints:restore(game,checkpoint)
    T.check(ok,'real checkpoint restores typed status: '..tostring(code))
    if ok then
      local restored=game.stack:top()
      T.neq(restored,b,'restore constructs a fresh native battle')
      T.eq(restored.shownStatus.enemy,'BRN','restored view reads native snapshot')
      T.eq(restored.enemy.mon.status,'PSN','restore keeps distinct actual combat status')
      restored.enemy.shownStatus='FRZ'
      T.eq(restored.shownStatus.enemy,'FRZ','restored view is live rather than a copied map')
      T.raises(function()restored.shownStatus.enemy='BRN'end,'owned','restored view retains native status owner')
    end
  end
  require('src.mods.Loader').teardown();f.close()
end
Version.set(previous)
T.finish('native Gen2 typed status checkpoint reconstruction')
