-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local Effect=require('src.core.game3.battle.effect_ctx')
local Registry=require('src.battle.EffectRegistry')
local Battle=require('src.core.game3.battle')
local G=require('src.core.Game3');local V=require('src.core.GameVersion')
local original=package.loaded['src.core.Game']
local function pack(...)return{n=select('#',...),...}end
local function individual(fn)
 local random=love.math.random;love.math.random=function(lo)return lo or 0 end
 local ok,value=pcall(fn);love.math.random=random;if not ok then error(value,0)end;return value
end
local function fresh(edition)
 if V.generation(edition)==2 then
  V.set(edition);local data=T.fixtures.fresh();data.constants.gen=2
  require('src.render.Font').load(data);require('src.battle.TypeChart').load(data)
  local save=require('src.core.SaveData').newGame()
  save.party={require('src.pokemon.Pokemon').new(data,'FIXMON_A',30,function(lo)return lo or 0 end)}
  local game={data=data,save=save,mods={exports={}},input={wasPressed=function()return false end,isDown=function()return false end},
   stack=setmetatable({},{__index=require('src.core.StateStack')})};game.stack:init()
  package.loaded['src.core.Game']=game
  local b=individual(function()return require('src.battle.BattleState').newWild(game,'FIXMON_C',30)end)
  return{game=game,close=function()end},b
 end
 local f=require('tools.battle-source-runtime.fixture').new(edition);package.loaded['src.core.Game']=f.game
 local b=individual(function()return f.fresh('TACKLE').battle end);f.game.stack:push(b);Battle.getState()
 return f,b
end
local function close(f)
 if f.game.stack:top()then f.game.stack:pop()end;f.close();G.release()
end
T.eq(Effect.current(),nil);T.eq(Effect.depth(),0)
for _,edition in ipairs{'firered','leafgreen','emerald','ruby','sapphire'}do
 local f,b=fresh(edition);local game=f.game;local move=game.data.moves.MOVE_033
 local ctx=Registry.makeCtx(b,b.player,b.player,move,b.player.mon.moves[1],false)
 local kept,rng,adapter
 local calls,rolls=0,0;b.rng=function(lo)rolls=rolls+1;return lo or 0 end;ctx.rng=b.rng
 local result=pack(Registry.callEffect(ctx,'primary',function(actual)
  calls=calls+1;T.eq(actual,ctx,'native callback receives its original context')
  local c=Effect.current();kept=c;T.eq(c,Effect.current());T.eq(Effect.depth(),1)
  T.eq(c.user,Battle.getState().player);T.eq(c.target,c.user,'self-targeting effect keeps its actual target')
  T.eq(c.adapter:foeOf(c.user),Battle.getState().enemy,'team message selects the opposite side')
  T.eq(c.adapter:foeOf(nil),nil);T.eq(c.adapter:foeOf({side='player'}),nil)
  T.eq(c.moveId,33);T.eq(c.move.name,'TACKLE');T.eq(c.opts.phase,'primary')
  T.eq(rolls,0,'querying context never consumes RNG');rng=c.rng;adapter=c.adapter
  T.raises(function()c.user={}end,'read-only');T.raises(function()c.adapter.state={}end,'read-only')
  local copy=c.move;copy.name='CHANGED';T.eq(c.move.name,'TACKLE');T.eq(move.name,'TACKLE')
  local child=Registry.makeCtx(b,b.enemy,b.player,move,b.enemy.mon.moves[1],true)
  local nested=pack(Registry.callEffect(child,'perform',function()
   local current=Effect.current();T.neq(current,c);T.eq(current.user,Battle.getState().enemy)
   T.eq(current.adapter:foeOf(current.user),Battle.getState().player);T.eq(Effect.depth(),2)
   return nil,23,nil
  end))
  T.eq(nested.n,3);T.eq(nested[2],23);T.eq(Effect.current(),c);T.eq(Effect.depth(),1)
  local save=game.save;game.save={};T.eq(Effect.current(),nil);game.save=save
  local cover={};game.stack:push(cover);T.eq(Effect.current(),nil);game.stack:pop()
  T.eq(c.rng(7,9),7);T.eq(rolls,1)
  return nil,17,nil
 end))
 T.eq(result.n,3);T.eq(result[1],nil);T.eq(result[2],17);T.eq(result[3],nil);T.eq(calls,1)
 T.eq(Effect.current(),nil);T.eq(Effect.depth(),0);T.eq(kept.user,nil);T.eq(adapter:foeOf({}),nil)
 T.raises(function()rng(1,2)end,'retired');T.eq(rolls,1)
 T.raises(function()Registry.callEffect(ctx,'primary',function()T.neq(Effect.current(),nil);error('native effect failure')end)end,'native effect failure')
 T.eq(Effect.current(),nil);T.eq(Effect.depth(),0)
 close(f)
 -- Drive actual native primary, full and damaging record dispatches. The
 -- source query must see the existing callback, never a separate executor.
 for _,kind in ipairs{'primary','full','secondary'}do
  local native,screen=fresh(edition);local data=native.game.data;local def=data.moves.MOVE_033
  def.effect='NATIVE_CONTEXT_PROBE';def.power=kind=='primary'and 0 or 35;def.effectChance=100
  local observed=0;local phase
  local record={kind=kind}
  local function witness(c)
   observed=observed+1;T.eq(c.battle,screen);local current=assert(Effect.current())
   T.eq(current.user,Battle.getState().player);T.eq(current.adapter:foeOf(current.user),Battle.getState().enemy)
   phase=current.opts.phase;return{'NATIVE EFFECT'}
  end
  if kind=='full'then record.perform=witness else record.run=witness end
  data.move_effects={NATIVE_CONTEXT_PROBE=record}
  screen:performMove(screen.player,screen.enemy,screen.player.mon.moves[1])
  T.eq(observed,1);T.eq(phase,kind=='secondary'and'damage'or kind=='full'and'perform'or'primary')
  T.eq(Effect.current(),nil);T.eq(Effect.depth(),0);close(native)
 end
end
do
 local f,b=fresh('emerald');local data=f.game.data
 local Pokemon=require('src.pokemon.Pokemon')
 f.game.save.party[2]=Pokemon.new(data,'CHARMANDER',30,function(lo)return lo or 0 end)
 b:makeWildDouble(Pokemon.new(data,'CHARMANDER',30,function(lo)return lo or 0 end))
 for pos=0,3 do
  local raw=assert(b:battlerAt(pos),'native double slot absent')
  local ctx=Registry.makeCtx(b,raw,raw,data.moves.MOVE_033,raw.mon.moves[1],false)
  Registry.callEffect(ctx,'primary',function()
   local c=assert(Effect.current());local other=assert(c.adapter:foeOf(c.user))
   T.eq(c.user.id,pos);T.eq(other.id,pos%2==0 and pos+1 or pos-1)
   T.neq(other.side,c.user.side,'all four native double slots select the opposite team')
  end)
 end
 b:placeBattler(3,nil)
 local raw=b:battlerAt(2);local ctx=Registry.makeCtx(b,raw,raw,data.moves.MOVE_033,raw.mon.moves[1],false)
 Registry.callEffect(ctx,'primary',function()local c=Effect.current();T.eq(c.adapter:foeOf(c.user).id,1,'empty opposite flank falls back to its real native lead')end)
 close(f)
end
-- No module / loaded module comparisons use the same actual native effect
-- record and deterministic RNG. Gen2 never gains a GBA effect context.
for _,edition in ipairs{'firered','gold','silver','crystal'}do
 local traces={}
 for _,enabled in ipairs{false,true}do
  package.loaded['src.core.game3.battle.effect_ctx']=enabled and Effect or nil
  local f,b=fresh(edition);local rolls,calls=0,0
  b.rng=function(lo)rolls=rolls+1;return lo or 0 end
  local def=b:moveDef(b.player.mon.moves[1]);def.effect='NATIVE_CONTEXT_TRACE'
  f.game.data.move_effects={NATIVE_CONTEXT_TRACE={kind='secondary',run=function()
   calls=calls+1;if edition~='firered'then T.eq(Effect.current(),nil)end;return{}
  end}}
  local pp=b.player.mon.moves[1].pp;b:performMove(b.player,b.enemy,b.player.mon.moves[1])
  traces[#traces+1]={b.player.mon.hp,b.enemy.mon.hp,b.player.mon.moves[1].pp,pp,rolls,calls,#b.queue}
  close(f)
 end
 T.same(traces[1],traces[2],edition..' native effect/HP/PP/RNG/queue trace unchanged')
end
package.loaded['src.core.game3.battle.effect_ctx']=Effect;package.loaded['src.core.Game']=original;V.set('firered')
T.finish('native effect callback scope, same-team targets, nested contexts, returns, errors and unchanged native traces')
