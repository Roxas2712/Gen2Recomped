package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local Effect=require('src.core.game3.battle.effect_ctx')
local Registry=require('src.battle.EffectRegistry')
local Battle=require('src.core.game3.battle')
local G=require('src.core.Game3')
local Probe=dofile('tests/native_action_plan/turn.lua')
local function open(edition)
 local f,b=Probe.open(edition)
 -- This direct effect probe does not resolve a turn. Admit the actual
 -- native slot placement normally established by enter/resolveTurn first.
 b:syncSides()
 return f,b
end
local function context(b,user)
 return Registry.makeCtx(b,user,b.enemy,b.data.moves.MOVE_033,user.mon.moves[1],false)
end
for _,edition in ipairs{'firered','leafgreen','ruby','sapphire','emerald'}do
 local f,b=open(edition);local ctx=context(b,b.player)
 local kept,rng;local rolls=0;ctx.rng=function(lo)rolls=rolls+1;return lo end
 local co=coroutine.create(function()
  return Registry.callEffect(ctx,'primary',function()
   kept=Effect.current();rng=kept.rng;T.eq(Effect.depth(),1)
   coroutine.yield('held')
   T.eq(Effect.current(),kept,'resumed owner recovers only its own effect')
   T.eq(rng(4,7),4);return nil,17,nil
  end)
 end)
 local ok,value=coroutine.resume(co);T.eq(ok,true);T.eq(value,'held')
 T.eq(Effect.current(),nil,'suspended effect is unavailable to the main coroutine')
 T.eq(Effect.depth(),0,'suspended sibling does not contribute to native effect depth')
 T.eq(kept.user,nil,'retained observations cannot expose a suspended sibling')
 T.eq(pcall(rng,1,2),false,'retained RNG cannot consume a suspended sibling clock')
 T.eq(rolls,0)
 Registry.callEffect(context(b,b.enemy),'perform',function()
  T.eq(Effect.current().user,Battle.getState().enemy,'independent root observes actual enemy')
  T.eq(Effect.depth(),1,'independent native root has its own depth')
 end)
 T.eq(Effect.current(),nil)
 -- A newer resumer's native effect cannot shadow the child's own context.
 Registry.callEffect(context(b,b.enemy),'primary',function()
  local parent=Effect.current()
  local resumed,a,z,last=coroutine.resume(co)
  T.eq(resumed,true);T.eq(a,nil);T.eq(z,17);T.eq(last,nil)
  T.eq(Effect.current(),parent,'resumer effect survives completion of an independent child');T.eq(Effect.depth(),1)
 end)
 T.eq(rolls,1);T.eq(Effect.current(),nil);T.eq(Effect.depth(),0)
 T.eq(kept.user,nil);T.eq(pcall(rng,1,2),false)
 Probe.close(f)
end

-- The real callback-attribution owner retires its suspended child. Effect
-- observations must not keep that child's RNG permission alive afterwards.
do
 local f,b=open('emerald');local ctx=context(b,b.player)
 local co,rng;local rolls=0;ctx.rng=function(lo)rolls=rolls+1;return lo end
 G._withCallbackOwner('parent',function()
  co=coroutine.create(function()
   return G._withCallbackOwner('child',function()
    return Registry.callEffect(ctx,'primary',function()
     rng=Effect.current().rng;coroutine.yield('held')
     T.eq(Effect.current(),nil,'revoked child has no current effect')
     T.eq(pcall(rng,1,2),false,'revoked child cannot consume effect RNG')
    end)
   end)
  end)
  T.eq(coroutine.resume(co),true)
 end)
 local ok,why=coroutine.resume(co);T.eq(ok,false)
 T.eq(tostring(why):find('retired',1,true)~=nil,true)
 T.eq(rolls,0);T.eq(Effect.current(),nil);T.eq(Effect.depth(),0)
 Probe.close(f)
end

-- A retained descriptor must not root an abandoned coroutine/controller.
do
 local f,b=open('emerald');local ctx=context(b,b.player)
 local kept;local weak=setmetatable({b},{__mode='v'})
 local co=coroutine.create(function()
  Registry.callEffect(ctx,'primary',function()kept=Effect.current();coroutine.yield()end)
 end)
 T.eq(coroutine.resume(co),true)
 Probe.close(f);ctx,b,f,co=nil,nil,nil,nil
 collectgarbage('collect');collectgarbage('collect')
 T.eq(weak[1],nil,'retained descriptor cannot pin an abandoned native controller')
 T.eq(kept.user,nil);T.eq(Effect.current(),nil);T.eq(Effect.depth(),0)
end
T.finish('Coroutine-local native effect observations, RNG authority, independent roots and abandoned-owner lifetime')
