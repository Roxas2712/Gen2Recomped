package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
for _,version in ipairs({'ruby','sapphire','firered','leafgreen','emerald'})do
  local f=require('tests.enemy_actions.fixture').new('.','gen2',version,3,'unified',function(data,_,ids)
    for _,row in ipairs({{315,'OVERHEAT',204,'OVERHEAT_EFFECT'},{354,'PSYCHO_BOOST',204,'OVERHEAT_EFFECT'},
      {276,'SUPERPOWER',182,'SUPERPOWER_EFFECT'},{174,'CURSE',109,'CURSE_EFFECT'}})do
      local n,id,effect,name=unpack(row);ids[id]=id
      data.moves[id]={id=id,index=n,name=id,effect=name,gen3Effect=effect,power=id=='CURSE'and 0 or 15,
        type='NORMAL',accuracy=100,pp=10,target=id=='CURSE'and 16 or 0,flags=2,protectAffected=true}
    end
    data.pokemon.CHARMANDER.abilities={}
  end)
  for _,ability in ipairs({'WHITE_SMOKE','CLEAR_BODY','HYPER_CUTTER','KEEN_EYE'})do
    for _,id in ipairs({'OVERHEAT','PSYCHO_BOOST','SUPERPOWER','CURSE'})do
      local x=f.fresh(id);local b,u,t=x.battle,x.user,x.target
      u.abilityOverride=ability;t.abilityOverride=false
      b.rng=function(lo,hi)if hi==65535 then return 35 end;return hi or lo end
      for n=1,4 do
        x.use()
        T.eq(x.pp(),10-n,'self-cost move spends its own PP')
        if id=='CURSE'then
          T.eq(u.stages.speed,-n,'native Curse speed loss bypasses the user\'s ability')
          T.eq(u.stages.attack,n,'Curse retains its ordinary attack increase')
          T.eq(u.stages.defense,n,'Curse retains its ordinary defense increase')
        elseif id=='SUPERPOWER'then
          T.eq(u.stages.attack,-n,'Superpower always pays its own attack cost')
          T.eq(u.stages.defense,-n,'Superpower always pays its own defense cost')
        else T.eq(u.stages.spatk,-math.min(n*2,6),'Overheat/Psycho Boost pay their own special attack cost')end
      end
      local ctx=require('src.battle.EffectRegistry').makeCtx(b,t,u,f.data.moves[f.ids.TACKLE],{id=f.ids.TACKLE,pp=10},false)
      local old=u.stages.attack or 0
      ctx.changeStage(u,'attack',-1,false)
      T.eq(u.stages.attack or 0,(ability=='WHITE_SMOKE'or ability=='CLEAR_BODY'or ability=='HYPER_CUTTER')and old or old-1,
        'opposing secondary drop still respects defensive abilities')
    end
  end
  f.close()
end
T.finish('five-edition native self-stat costs and opposing stat protection')
