-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local Copy=require('src.mods.Merge').deepCopy
local Input=require('src.core.Input')
local Fixture=require('tests.checkpoint_fixture')
local function peers(f, reaction)
  local data=f.game.data
  data.moves.FAINT_HIT={id='FAINT_HIT',index=69,name='SEISMIC TOSS',effect='SPECIAL_DAMAGE_EFFECT',gen3Effect=87,type='NORMAL',power=1,accuracy=100,pp=5,target=0,flags=51}
  data.moves.FAINT_REACT={id='FAINT_REACT',index=reaction=='grudge'and 288 or 194,name='REACTION',effect=reaction=='grudge'and'GRUDGE_EFFECT'or'DESTINY_BOND_EFFECT',gen3Effect=reaction=='grudge'and 194 or 98,type='GHOST',power=0,accuracy=0,pp=40,target=16,flags=0}
  data.moves.FAINT_WAIT={id='FAINT_WAIT',index=150,name='SPLASH',effect='SPLASH_EFFECT',gen3Effect=85,type='NORMAL',power=0,accuracy=0,pp=40,target=16,flags=0}
  T.link.prepare(data)
  local ga=T.link.fakeGame(data,'FIXMON_A',{name='HOST',level=30})
  local gb=T.link.fakeGame(data,'FIXMON_A',{name='GUEST',level=30})
  for i,game in ipairs({ga,gb})do
    local mon=game.save.party[1]
    mon.nickname=i==1 and'ATTACKER'or'VICTIM';mon.stats.hp,mon.hp=400,400
    mon.moves={{id=reaction and(i==1 and'FAINT_HIT'or'FAINT_REACT')or'FAINT_WAIT',pp=i==1 and reaction and 5 or 40}}
    if reaction then
      local reserve=Copy(mon);reserve.nickname='RESERVE';reserve.moves={{id='FAINT_WAIT',pp=40}};game.save.party[2]=reserve
      if i==2 then mon.hp,mon.status=1,'PSN' end
    end
  end
  local Net,Protocol,Link=require('src.link.Net'),require('src.link.Protocol'),require('src.link.LinkBattle')
  local na,nb=Net.loopbackPair();local pa,pb=Protocol.packParty(ga.save.party),Protocol.packParty(gb.save.party)
  local a=assert(Link.newHost(ga,na,{myParty=pa,theirParty=pb,theirName='GUEST',seed=3917,verdict='full',strict=true}))
  local b=assert(Link.newGuest(gb,nb,{myParty=pb,theirParty=pa,theirName='HOST',seed=3917,verdict='full',strict=true}))
  local actors={}
  for i,battle in ipairs({a,b})do
    (i==1 and ga or gb).stack:push(battle)
    actors[i]={}
    for _,actor in ipairs({battle.player,battle.enemy})do
      actor.abilityOverride=false
      actor.curStats.speed=actor.mon.nickname=='VICTIM'and 200 or 50
      actors[i][actor.mon.nickname]=actor
    end
    actors[i].initialHP=actors[i].ATTACKER.mon.hp
  end
  return {ga,gb},{a,b},actors
end
local function round(f,games,battles)
  for frame=1,20000 do
    for i,game in ipairs(games)do
      local b=battles[i];f.loaded.loader.game=game;b.moveIndex=1
      Input.pressed=b.localHashes[1]and{}or{a=true}
      game.stack:update(1/60)
    end
    if battles[1].localHashes[1]and battles[2].localHashes[1]then return end
  end
  T.check(false,'both actual peers finish the native round')
end
for _,edition in ipairs({'firered','leafgreen','emerald','ruby','sapphire'})do
  for _,reaction in ipairs({'grudge','bond'})do
    local f=Fixture.boot(edition,3,'unified')
    local games,battles,actors=peers(f,reaction)
    local events={{},{}};local current
    f.loaded.loader.exports.checkpoint_fixture.api.events:on('battle.fainted',function(e)
      events[current][#events[current]+1]=e.battler.mon.nickname
      T.eq(e.battler.mon.status,nil,'real linked faint notification follows native status clear')
    end)
    for i,game in ipairs(games)do
      local update=game.stack.update
      game.stack.update=function(self,dt)current=i;return update(self,dt)end
    end
    round(f,games,battles)
    T.eq(battles[1].localHashes[1],battles[2].localHashes[1],'canonical linked HP/status hashes agree')
    T.same(battles[1].localParts[1],battles[2].localParts[1],'all actual linked state components agree')
    T.eq(actors[1].VICTIM.mon.happiness,actors[2].VICTIM.mon.happiness,'both linked copies retain the same native victim friendship')
    T.eq(actors[1].ATTACKER.mon.happiness,actors[2].ATTACKER.mon.happiness,'both linked copies retain the same native reaction-user friendship')
    local rs=edition=='ruby'or edition=='sapphire'
    T.eq(actors[1].VICTIM.mon.happiness,rs and 70 or 69,'equal-level faint follows edition rules on both peers')
    for _,game in ipairs(games)do T.eq(game.save.party[1].happiness,70,'linked battle copies do not mutate the saved world party')end
    for i=1,2 do
      T.eq(actors[i].VICTIM.mon.hp,0,'real native reaction user is knocked out')
      T.eq(actors[i].VICTIM.mon.status,nil,'native KO removes poison')
      T.eq(actors[i].ATTACKER.mon.moves[1].pp,reaction=='grudge'and 0 or 4,'actual selected linked PP follows the native reaction')
      T.eq(actors[i].ATTACKER.mon.hp,reaction=='bond'and 0 or actors[i].initialHP,'native Destiny Bond owns only the actual attacker; party wire HP remains authoritative')
      T.same(events[i],reaction=='bond'and{'VICTIM','ATTACKER'}or{'VICTIM'},'linked announcements preserve target/user order')
    end
    f.close()
  end
  -- Deliberately diverge exactly one native semantic bit after both moves.
  -- HP, PP, stats and the legacy value hash remain equal. The real transport
  -- must catch the differing future behavior in its fatal active component.
  for _,key in ipairs({'_gbaLogicalFaint','grudge','destinyBond','_gbaFriendshipFainted','friendshipAlias'})do
    local f=Fixture.boot(edition,3,'unified')
    local games,battles=peers(f)
    local original=battles[1].endOfTurn
    battles[1].endOfTurn=function(self,...)
      original(self,...)
      if key=='friendshipAlias'then self.player.mon.friendship=1 else self.player[key]=true end
    end
    round(f,games,battles)
    T.eq(battles[1].localHashes[1],battles[2].localHashes[1],'negative control preserves the old HP/status value hash')
    if key=='friendshipAlias'then
      T.eq(battles[1].player.mon.happiness,battles[2].enemy.mon.happiness,'friendship negative control preserves the happiness alias')
      T.neq(battles[1].localParts[1].bench,battles[2].localParts[1].bench,'native party hash includes authoritative friendship')
    else T.eq(battles[1].localParts[1].bench,battles[2].localParts[1].bench,'negative control preserves the complete party state')end
    T.neq(battles[1].localParts[1].actives,battles[2].localParts[1].actives,'actual link hashes include '..key)
    for _=1,8 do for i,game in ipairs(games)do f.loaded.loader.game=game;Input.pressed={};game.stack:update(1/60)end end
    T.eq(battles[1].result,'draw','host refuses divergent native faint rules')
    T.eq(battles[2].result,'draw','guest refuses divergent native faint rules')
    f.close()
  end
end
T.finish('real two-peer native Grudge/Destiny Bond and fatal faint-state hash controls')
