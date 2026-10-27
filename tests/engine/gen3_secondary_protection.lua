package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local S=require('src.battle.Gen3Secondary')
for _,version in ipairs({'ruby','sapphire','firered','leafgreen','emerald'})do
  local f=require('tests.enemy_actions.fixture').new('.','gen2',version,3,'unified',function(data)data.pokemon.CHARMANDER.abilities={}end)
  local x=f.fresh('TACKLE');local b,u,t=x.battle,x.user,x.target
  u.abilityOverride=false;t.abilityOverride=false
  local ctx=require('src.battle.EffectRegistry').makeCtx(b,u,t,f.data.moves[f.ids.TACKLE],x.move,false)
  local words=0
  for _,chance in ipairs({0,1,30,100})do
    ctx.move.secondaryChance=chance
    for word=0,99 do
      b.rng=function(lo,hi)T.eq(lo,0,'native chance lower bound');T.eq(hi,99,'native chance upper bound');words=words+1;return word end
      t.stages.speed=nil
      S.withChance(ctx,{stat='speed',delta=-1})
      local hit=version=='emerald'and word<chance or version~='emerald'and word<=chance
      T.eq(t.stages.speed or 0,hit and -1 or 0,version..' native chance boundary '..chance..'/'..word)
    end
  end
  T.eq(words,400,'every probability including zero draws exactly once')
  for _,protection in ipairs({'NONE','WHITE_SMOKE','CLEAR_BODY','SHIELD_DUST','HYPER_CUTTER','KEEN_EYE','MIST'})do
    t.abilityOverride=protection~='MIST'and protection or false;t.mist=protection=='MIST'or nil
    for _,stat in ipairs({'attack','defense','speed','spatk','spdef','accuracy'})do
      for _,chance in ipairs({30,100,255})do
        ctx.move.secondaryChance=chance;t.stages[stat]=nil
        b.rng=function()return 0 end
        S.withChance(ctx,{stat=stat,delta=-1})
        local blocked=protection=='MIST'or protection=='WHITE_SMOKE'or protection=='CLEAR_BODY'or protection=='SHIELD_DUST'
          or protection=='HYPER_CUTTER'and stat=='attack'or protection=='KEEN_EYE'and stat=='accuracy'
        T.eq(t.stages[stat]or 0,blocked and 0 or -1,'probability never grants permission to bypass '..protection..'/'..stat)
      end
    end
  end
  t.abilityOverride='WHITE_SMOKE';t.mist=nil;ctx.move.secondaryChance=100;u.abilityOverride='WHITE_SMOKE'
  u.stages.attack=nil;S.withChance(ctx,{stat='attack',delta=-1,user=true})
  T.eq(u.stages.attack,-1,'own stat losses remain possible')
  f.close()
end
do
  local V,F,H=require('src.core.GameVersion'),require('src.link.Fingerprint'),require('src.link.Handshake')
  local data=T.fixtures.fresh();local game={data=data,save={player={name='RULES'}}}
  V.set('ruby');local ruby=F.compute(data,{});local a=H.hello(game,'battle');local records=F.records(data,'pokemon')
  V.set('emerald');local emerald=F.compute(data,{});local b=H.hello(game,'battle')
  T.neq(emerald,ruby,'distinct cartridge chance rules cannot share a lockstep fingerprint')
  T.eq(H.checkCompat(a,b),'subset','different secondary command rules refuse full battles')
  T.eq(H.checkCompat(b,a),'subset','cartridge command guard is symmetric')
  T.same(F.records(data,'pokemon'),records,'secondary command rules retain shared trade definitions')
  V.set('ruby');T.eq(F.compute(data,{}),ruby,'cached fingerprint follows cartridge rule after switching back')
  print('NATIVE_SECONDARY_FINGERPRINTS '..ruby..' '..emerald)
end
T.finish('five-edition secondary protection and exact RS/FRLG versus Emerald chance boundaries')
