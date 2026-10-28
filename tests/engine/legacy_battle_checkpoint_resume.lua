-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
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
local F=require('tests.checkpoint_fixture')
local Screen=require('src.battle.BattleState')
local Serializer=require('src.core.SaveSerializer')
local original=Screen.resumeCheckpoint
local Capture=require('src.compat.gen1.BattleCheckpoint')
local nativeCapture=Capture.capture
for _,edition in ipairs({'red','blue','yellow','crystal','emerald'})do
 local f=F.boot(edition)
 local game,world,stack=f.game,f.world,f.stack
 local b=Screen.newWild(game,'FIXMON_B',15)
 b.phase,b.queue,b.introSlide='menu',{},0
 stack.states={world,b}
 -- Source mods temporarily clear their owned called-move charge pointer
 -- around capture. Both capability inspection and capture must reach that
 -- same seam; otherwise inspection rejects before the mod can normalize it.
 local charge={id='FIX_CALLED_MOVE',pp=1}
 b.player.charging=charge
 local captureCalls=0
 Capture.capture=function(g,battle,progress,copy)
  captureCalls=captureCalls+1
  assert(type(progress)=='table' and progress.version==g.save.version and type(copy)=='function','source capture argument contract')
  local saved=battle.player.charging
  battle.player.charging=nil
  local ok,result=pcall(nativeCapture,g,battle,progress,copy)
  battle.player.charging=saved
  if not ok then error(result,0)end
  return result
 end
 local cp=assert(f.checkpoints:capture(game))
 T.check(captureCalls>=2,'inspection and native capture dispatch the source capture seam')
 T.eq(b.player.charging,charge,'source capture preserves its live owned pointer')
 Capture.capture=nativeCapture
 b.player.charging=nil
 local calls=0
 Screen.resumeCheckpoint=function(self,...)
  calls=calls+1
  T.eq(self.game.stack:top(),self,'source continuation observes the real restored top state')
  T.eq(self.player.mon,self.game.save.party[1],'source continuation observes native restored Pokemon identity')
  return original(self,...)
 end
 local ok,why,detail=f.checkpoints:restore(game,cp)
 T.check(ok,edition..': source resume seam completes native restore '..tostring(why)..' '..tostring(detail))
 T.eq(calls,1,'native restore dispatches source continuation once')
 T.eq(Serializer.encode(assert(f.checkpoints:capture(game))),Serializer.encode(cp),'continuation does not replay native intro state')
 local restored=stack:top()
 Screen.resumeCheckpoint=function()error('source checkpoint validator rejected')end
 ok,why=f.checkpoints:restore(game,cp)
 T.check(not ok,'source rejection refuses native restore')
 T.eq(why,'restore_failed','source rejection uses the existing transaction failure')
 T.eq(stack:top(),restored,'source rejection preserves the prior native battle owner')
 T.eq(Serializer.encode(assert(f.checkpoints:capture(game))),Serializer.encode(cp),'source rejection preserves exact checkpoint state')
 Screen.resumeCheckpoint=original
 f.close()
end
T.finish('Source battle checkpoint continuation over the native transaction')
