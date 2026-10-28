-- Exercise the actual damaging pipeline and HP/Substitute cap, not a second
-- implementation of the drain formula. Damage rolls are fixed at the seam.
love=require('tests.love_stub')
local V=require('src.core.GameVersion')
local Effects=require('src.battle.MoveEffects')
local Registry=require('src.battle.EffectRegistry')
local Battle=require('src.battle.BattleState')
local n=0
local function eq(a,b,why)n=n+1;assert(a==b,why..': '..tostring(a)..' ~= '..tostring(b))end
local function run(version,spec)
  V.set(version)
  local user={name='USER',isPlayer=true,curTypes={'GRASS'},stages={},def={abilities={}},
    mon={hp=spec.userHP or 7,stats={hp=200},moves={}}}
  local target={name='TARGET',isPlayer=false,curTypes={'NORMAL'},stages={},
    def={abilities=spec.ooze and {'LIQUID_OOZE'}or {}},
    mon={hp=spec.hp,stats={hp=100},status=spec.dream and 'SLP'or nil,moves={}},
    substituteHP=spec.sub,enduring=spec.endure}
  local effect=spec.dream and 'DREAM_EATER_EFFECT'or 'DRAIN_HP_EFFECT'
  local move={id=spec.dream and 'DREAM_EATER'or 'ABSORB',type=spec.dream and 'PSYCHIC_TYPE'or 'GRASS',
    effect=effect,power=spec.dream and 100 or 20,accuracy=100,gen3Effect=spec.dream and 8 or 3}
  local battle={data={constants={},items={},moves={[move.id]=move}},queue={},nextInsert=0,
    player=user,enemy=target,ruleset={},messages={},faints={},rngCalls=0}
  setmetatable(battle,{__index=Battle})
  function battle.rng(lo)battle.rngCalls=battle.rngCalls+1;return lo end
  function battle:accuracyRoll()return true end
  function battle:computeDamage()return spec.raw or 120,{crit=false,typeMult=spec.immune and 0 or 10}end
  function battle:focusBandHolds()return false end
  function battle:animationsOn()return false end
  function battle:cancelMoveAnim()end
  function battle:waitNext()end
  function battle:drainNext()end
  function battle:sayNext(line)self.messages[#self.messages+1]=line end
  function battle:onFaint(who)if not who.faintQueued then who.faintQueued=true;self.faints[#self.faints+1]=who end end
  function battle:romText(_,fallback)return fallback end
  function battle:activeBattlers()return ipairs({user,target})end
  function battle:holdItemTrigger()return false end
  local ctx=Registry.makeCtx(battle,user,target,move,{id=move.id,pp=20},false)
  Registry.runDamaging(battle,ctx,Effects.RECORDS[effect])
  return user,target,battle,ctx
end
local cases={
  {name='one HP overkill',hp=1,expected=8,dealt=1},
  {name='twenty-five HP overkill',hp=25,expected=19,dealt=25},
  {name='ordinary seven damage',hp=100,raw=7,expected=10,dealt=7},
  {name='odd three damage',hp=100,raw=3,expected=8,dealt=3},
  {name='Endure at one HP',hp=1,endure=true,expected=8,dealt=0,remain=1},
  {name='Substitute capped to five',hp=50,sub=5,expected=9,dealt=5,remain=50},
  {name='Liquid Ooze capped to six',hp=6,ooze=true,expected=4,dealt=6},
  {name='Liquid Ooze double faint',hp=25,ooze=true,expected=0,dealt=25,doubleFaint=true},
  {name='Dream Eater overkill',hp=25,dream=true,expected=19,dealt=25},
  {name='Gen3 Dream Eater bypasses Liquid Ooze',hp=6,dream=true,ooze=true,expected=10,dealt=6},
  {name='type immunity does not drain',hp=25,immune=true,expected=7,dealt=nil,remain=25},
}
for _,version in ipairs({'ruby','sapphire','leafgreen','firered','emerald'})do
  for _,spec in ipairs(cases)do
    local user,target,battle,ctx=run(version,spec);local prefix=version..' '..spec.name
    eq(user.mon.hp,spec.expected,prefix..' actual user HP')
    eq(ctx.totalDealt,spec.dealt,prefix..' actual loss reaches effect')
    if spec.remain then eq(target.mon.hp,spec.remain,prefix..' target HP')end
    if not spec.immune then
      eq(battle.lastDamage,spec.raw or 120,prefix..' native counter memory retained')
      if spec.sub then eq(target.specialDamageTaken,nil,prefix..' owner counter ignores Substitute')
      elseif spec.dealt>0 then eq(target.specialDamageTaken,spec.dealt,prefix..' actual special counter memory')end
    end
    if spec.doubleFaint then
      eq(#battle.faints,2,prefix..' both faints queued once')
      eq(battle.faints[1],user,prefix..' native ability first queues attacker faint')
      eq(battle.faints[2],target,prefix..' defender follows attacker')
    end
    eq(battle.rngCalls,0,prefix..' healing adds no RNG rolls')
  end
end
for _,version in ipairs({'red','gold'})do
  for _,dream in ipairs({false,true})do
    local user,_,battle=run(version,{hp=1,dream=dream})
    eq(user.mon.hp,67,version..' retains existing raw-damage drain')
    eq(battle.lastDamage,60,version..' retains old halved Counter memory')
  end
end
print('GEN3_DRAIN_PIPELINE_CHECKS',n)
