-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local root,backend,edition,mode=unpack(arg)
local V=require('src.core.GameVersion');V.set(edition)
local gba=V.generation()==3
local rows={}
local function value(x)if x==nil then return false end;return x end
local function status(x)if x==nil or x==false or x==0 or x==''then return false end;return x end
local function native(who)return who.mon or who end
local profiles={'read','unnamed','flat HP','nested HP','flat stat','nested stat','flat PP','nested PP','flat moves replacement','detached stats','flat clear status','nested clear status','conflicting HP aliases','outer snapshot','outer nested post','outer flat post','outer error','faint target'}
for _,profile in ipairs(profiles)do
 local f=dofile(root..'/tests/charge_required/fixture.lua').new(root,backend,edition,3,'unified',false,false,
  'portable_enemy_action',function(data,gen)if backend=='gen2'and gen==3 then data.constants.generation=3 end end,
  function(files)
   local J=require('src.link.Json');local path='mods/portable_enemy_action/manifest.json';local m=J.decode(files[path]);m.games={'gen1','gen2','gen3'};files[path]=J.encode(m)
   files['mods/portable_enemy_action/main.lua']='return function(mod)mod.exports.api=mod end'
  end)
 local c=f.fresh('TACKLE');local b=c.battle
 if backend=='gen2'then b:syncSides()end
 local user,target=c.user,c.target
 if gba and mode=='right'then
  b.double=true
  local copy=require('src.mods.Merge').deepCopy
  for pos=2,3 do
   local template=pos==2 and user or target
   if backend=='gen1'then
    b.battlers[pos]=require('src.core.game3.battle.state').makeBattler(copy(template.mon),pos==2 and'player'or'enemy',{id=pos,partyIndex=2})
   else b:placeBattler(pos,require('src.battle.BattleState').makeBattler(f.data,copy(template.mon),pos==2))end
  end
  if backend=='gen2'then b:syncSides()end
  user=backend=='gen1'and b.battlers[2]or b:battlerAt(2)
  target=backend=='gen1'and b.battlers[3]or b:battlerAt(3)
 end
 for _,who in ipairs({user,target})do
  local p=native(who);p.hp,p.maxHp,p.nickname,p.shiny=400,400,'PROBE',false
  if profile=='unnamed'then p.nickname,p.name=nil,nil end
  if backend=='gen1'and gba then
   who.type1,who.type2,who.ability=0,0,0
   p.maxHp,p.attack,p.defense,p.speed,p.spAtk,p.spDef,p.ppBonusesPacked=400,50,50,50,50,50,0
  else
   p.stats.hp=400
   for _,key in ipairs({'attack','defense','speed','special','spatk','spdef'})do p.stats[key]=50 end
   -- The fixture's default foe learned a different Tackle definition.
   -- Seed the same legal move/PP on both actors, preserving native slots.
   p.moves[1].id,p.moves[1].pp,p.moves[1].ppUps=f.ids.TACKLE,10,0
   for slot=#p.moves,2,-1 do p.moves[slot]=nil end
   if gba then who.curTypes,who.abilityOverride={'NORMAL'},false end
  end
 end
 if profile:find('clear status',1,true)then native(user).status='BRN'end
 if profile=='faint target'then native(target).hp=1 end
 local rng,calculations,observations,notifications={},{},{},{}
 b.rng=function(lo,hi)rng[#rng+1]={lo=lo,hi=hi,value=lo};return lo end
 if backend=='gen1'and f.gen==2 then
  b.random=function(n)rng[#rng+1]={lo=0,hi=(n or 1)-1,value=0};return 0 end
 end
 local function read(who)
  local out={id=value(who.id),side=value(who.side),statsAlias=who.stats~=nil and who.mon and who.stats==who.mon.stats,
   movesAlias=who.moves~=nil and who.mon and who.moves==who.mon.moves}
  for _,key in ipairs({'species','name','nickname','level','hp','maxHp','status','isEgg','shiny'})do
   out[key]=value(who[key]);out['nested_'..key]=value(who.mon and who.mon[key])
  end
  out.attack=value(who.stats and who.stats.attack);out.nestedAttack=value(who.mon and who.mon.stats and who.mon.stats.attack)
  out.pp=value(who.moves and who.moves[1]and who.moves[1].pp);out.nestedPP=value(who.mon and who.mon.moves[1]and who.mon.moves[1].pp)
  return out
 end
 local chain=profile:find('outer',1,true)~=nil
 if chain then f.e.api.hooks:wrap('battle.damage',function(nextDamage,ctx)
  local amount,info=nextDamage(ctx);ctx.user.hp=330;return amount,info
 end,0)end
 f.e.api.hooks:wrap('battle.damage',function(nextDamage,ctx)
  observations[#observations+1]={stage='before',user=read(ctx.user),target=read(ctx.target)}
  if profile=='flat HP'or chain then ctx.user.hp=350
  elseif profile=='nested HP'then ctx.user.mon.hp=350
  elseif profile=='flat stat'then ctx.user.stats.attack=100
  elseif profile=='nested stat'then ctx.user.mon.stats.attack=100
  elseif profile=='flat PP'then ctx.user.moves[1].pp=3
  elseif profile=='nested PP'then ctx.user.mon.moves[1].pp=3
  elseif profile=='flat moves replacement'then ctx.user.moves=require('src.mods.Merge').deepCopy(ctx.user.moves);ctx.user.moves[1].pp=2
  elseif profile=='detached stats'then local old=ctx.user.stats;ctx.user.mon.stats=require('src.mods.Merge').deepCopy(ctx.user.mon.stats);ctx.user.mon.stats.attack=90;old.attack=110
  elseif profile=='flat clear status'then ctx.user.status=nil
  elseif profile=='nested clear status'then ctx.user.mon.status=nil
  elseif profile=='conflicting HP aliases'then ctx.user.hp=350;ctx.user.mon.hp=325 end
  local amount,info=nextDamage(ctx)
  calculations[#calculations+1]={damage=amount,crit=info and(info.critical or info.crit)or false,typeMult=info and(info.effectiveness and math.floor(info.effectiveness*10+.5)or info.typeMult)or false}
  observations[#observations+1]={stage='after',user=read(ctx.user),target=read(ctx.target)}
  if profile=='outer nested post'then ctx.user.mon.hp=320
  elseif profile=='outer flat post'then ctx.user.hp=310
  elseif profile=='outer error'then ctx.user.mon.hp=-1;error('authored callback failure')end
  return amount,info
 end,100)
 f.e.api.events:on('battle.fainted',function(e)
  notifications[#notifications+1]=read(e.battler)
  e.battler.hp=100;e.battler.mon.hp=100
 end)
 if gba and mode=='right'then
  if backend=='gen1'then require('src.core.game3.battle.engine').resolveMove(user,target,33,1,require('src.core.game3.battle.adapter').new(b),b,{}, {})
  else b:performMove(user,target,user.curMoves[1])end
 else c.use()end
 -- Gold's native useMove stops before its faint sweep. Enter the actual
 -- owning sweep; never synthesize a notification in the comparison.
 if profile=='faint target'and backend=='gen1'and f.gen==2 then b:resolveFaints()end
 assert(#observations==2 and #calculations==1,'public damage hook must delegate exactly once')
 local p=native(user)
 local after={userHP=p.hp,targetHP=native(target).hp,attack=p.stats and p.stats.attack or p.attack,status=status(p.status),pp=gba and backend=='gen1'and p.pp[1]or p.moves[1].pp}
 if profile=='outer error'then assert(after.userHP==330,'failed outer hook must preserve inner committed HP')end
 if profile=='faint target'then assert(after.targetHP==0 and #notifications==1,'real faint producer must ignore notification writes')end
 rows[#rows+1]={profile=profile,after=after,rng=rng,calculations=calculations,observations=observations,notifications=notifications}
 f.close()
end
print('BATTLER_RECORDS_CONTRACT '..require('src.link.Json').encode(rows))
