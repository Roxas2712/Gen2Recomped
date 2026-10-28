-- Native semantic reconstruction must retain an enemy's cleared Fly/Dig box.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local Fixture=require('tests.checkpoint_fixture')
local Battle=require('src.battle.BattleState')
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
for _,edition in ipairs{'gold','silver','crystal'}do for _,id in ipairs{'FLY','DIG'}do
  local f=Fixture.boot(edition);local game=f.game
  game.data.moves[id]={id=id,name=id,type='NORMAL',power=1,accuracy=100,accuracyRaw=255,pp=10,effect='FLY_EFFECT'}
  game.input.wasPressed=function()return true end
  game.input.isDown=function()return true end
  game.save.options.textSpeed=1
  local b=Battle.newWild(game,'FIXMON_B',15)
  game.stack.states={f.world,b}
  b.queue,b.current,b.phase,b.afterQueue,b.introSlide={},nil,'resolving','menu',0
  local move={id=id,pp=10};b.enemy.curMoves[1]=move;b.enemy.mon.moves[1]=move
  b:performMove(b.enemy,b.player,move)
  local function finish(screen)
    local frames=0
    while screen.phase~='menu' and frames<1500 do screen:update(1/60);frames=frames+1 end
    T.check(frames<1500,'actual native queue reaches its decision phase')
  end
  finish(b)
  T.eq(b:isUnderground('enemy'),true,'actual native first turn clears enemy picture')
  local snapshot,why,detail=f.checkpoints:capture(game)
  T.check(snapshot~=nil,'cleared native picture captures without opaque object keys: '..tostring(why)..' '..tostring(detail))
  if snapshot then
    local ok,why=f.checkpoints:restore(game,snapshot)
    T.check(ok,'actual semantic checkpoint restores: '..tostring(why))
    if ok then
      local resumed=game.stack:top();local p=resumed._gen2VanishPictures.enemy
      T.neq(resumed,b,'restore creates its own native screen')
      T.eq(p.battler,resumed.enemy,'cleared box rebinds the reconstructed native battler')
      T.eq(p.mon,resumed.enemy.mon,'cleared box rebinds its actual Pokemon')
      T.eq(p.phase,'hidden','decision checkpoint retains only completed charge presentation')
      T.eq(p.row,nil,'no retired queue row survives a decision checkpoint')
      T.eq(p.runner,nil,'no animation VM is serialized')
      T.eq(resumed:isUnderground('enemy'),true,'fresh actual screen keeps the enemy absent')
      T.eq(resumed:animPicState('enemy').hidden,true,'public native drawing retains the same cleared box')
      local charged=resumed.enemy.charging
      T.eq(charged,resumed.enemy.curMoves[1],'native charge continuation retains its real learned move identity')
      resumed.phase,resumed.afterQueue='resolving','menu'
      resumed:performMove(resumed.enemy,resumed.player,charged);finish(resumed)
      T.eq(resumed:isUnderground('enemy'),false,'restored actual second turn reveals enemy again')
      T.eq(next(resumed._gen2VanishPictures),nil,'restored release drops its own presentation latch')
      T.eq(charged.pp,9,'checkpoint continuation spends no extra PP')
      T.eq(resumed.enemy.charging,nil,'native second turn clears its actual charge state')
    end
  end
  require('src.mods.Loader').teardown();f.close()
end end
Version.set(previous)
T.finish('native GSC Fly/Dig decision checkpoint reconstruction and release')
