package.path='./?.lua;./?/init.lua;'..package.path
local T,Copy=require('tests.modkit'),require('src.mods.Merge').deepCopy
for _,version in ipairs({'ruby','sapphire','firered','leafgreen','emerald'})do
  local f=require('tests.enemy_actions.partial_trap').fixture(version)
  local H=require('src.link.Handshake')
  local current=H.hello(f.game,'battle');local old=Copy(current);old.nativeBattleRevision=20
  T.check(current.nativeBattleRevision>=21,'native binding advertises changed runtime rules')
  T.eq(H.checkCompat(current,old),'subset','old Gen1 binding rules cannot enter native lockstep')
  T.eq(H.checkCompat(old,current),'subset','native rule guard is symmetric')
  local def=f.data.pokemon.CHARMANDER
  def.evYield={};def.baseStats.spatk=50;def.baseStats.spdef=50;def.baseStats.hp=200
  T.link.prepare(f.data)
  local ga=T.link.fakeGame(f.data,'CHARMANDER',{name='HOST',level=30})
  local gb=T.link.fakeGame(f.data,'CHARMANDER',{name='GUEST',level=30})
  for _,g in ipairs({ga,gb})do
    g.save.options.ruleset='gen3_emerald'
    g.save.party[1].moves={{id='BIND',pp=10},{id=f.ids.TACKLE,pp=10}}
  end
  f.e.api.hooks:wrap('battle.crit',function()return false end)
  local P,N,L=require('src.link.Protocol'),require('src.link.Net'),require('src.link.LinkBattle')
  local na,nb=N.loopbackPair();local pa,pb=P.packParty(ga.save.party),P.packParty(gb.save.party)
  local a=assert(L.newHost(ga,na,{myParty=pa,theirParty=pb,theirName='GUEST',seed=327,verdict='full',strict=true}))
  local b=assert(L.newGuest(gb,nb,{myParty=pb,theirParty=pa,theirName='HOST',seed=327,verdict='full',strict=true}))
  ga.stack:push(a);gb.stack:push(b)
  local firstSeen=false
  for _=1,40000 do
    for i,g in ipairs({ga,gb})do
      local battle=i==1 and a or b
      battle.moveIndex=(battle.turnCount or 0)==0 and 1 or 2
      require('src.core.Input').pressed={a=true};g.stack:update(1/60)
    end
    if a.localHashes[1]and b.localHashes[1]and not firstSeen then
      firstSeen=true
      for _,battle in ipairs({a,b})do
        T.check(require('src.battle.Gen3PartialTrap').active(battle.player),'real linked Bind produces a native binding')
        T.eq(battle:fightLockedAction(battle.player),nil,'linked bound player retains independent command selection')
      end
    end
    if a.localHashes[2]and b.localHashes[2]then break end
  end
  T.check(firstSeen,'real first binding turn completes on both peers')
  for turn=1,2 do
    T.check(a.localHashes[turn]~=nil and b.localHashes[turn]~=nil,'native linked turn completes')
    T.eq(a.localHashes[turn],b.localHashes[turn],'binding turns hash equally from opposite viewpoints')
    T.same(a.localParts[turn],b.localParts[turn],'complete volatile and bench state agrees')
  end
  for _,battle in ipairs({a,b})do
    for _,who in ipairs({battle.player,battle.enemy})do
      T.eq(who.mon.moves[1].pp,9,'binding attack is selected and paid exactly once')
      T.eq(who.mon.moves[2].pp,9,'bound victim executes a separately chosen attack next turn')
    end
    T.eq(battle.result,nil,'no hash mismatch or hidden forced lock finishes the link battle')
  end
  f.close()
end
T.finish('five-edition binding in actual paired link menus and completed turn hashes')
