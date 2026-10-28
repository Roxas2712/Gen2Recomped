-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local Copy=require('src.mods.Merge').deepCopy
local Input=require('src.core.Input')
local F=require('tests.checkpoint_fixture')
for _,edition in ipairs({'firered','leafgreen','ruby','sapphire','emerald'})do
 for _,protected in ipairs({false,true})do
  local f=F.boot(edition,3,'unified');local data=f.game.data
  data.moves.FIXED_LINK={id='FIXED_LINK',index=69,name='SEISMIC TOSS',effect='SPECIAL_DAMAGE_EFFECT',gen3Effect=87,type='NORMAL',power=1,accuracy=100,pp=5,target=0,flags=51}
  data.moves.STATUS_LINK={id='STATUS_LINK',index=150,name='SPLASH',effect='SPLASH_EFFECT',gen3Effect=85,type='NORMAL',power=0,accuracy=0,pp=40,target=16,flags=0}
  T.link.prepare(data)
  local ga=T.link.fakeGame(data,'FIXMON_A',{name='HOST',level=30})
  local gb=T.link.fakeGame(data,'FIXMON_A',{name='GUEST',level=30})
  for i,game in ipairs({ga,gb})do
   local mon=game.save.party[1];mon.nickname=i==1 and'H_ALPHA'or'G_ALPHA'
   mon.moves={{id='FIXED_LINK',pp=5},{id='STATUS_LINK',pp=40}}
   mon.stats.hp,mon.hp=400,400
  end
  local Net,Protocol,Link=require('src.link.Net'),require('src.link.Protocol'),require('src.link.LinkBattle')
  local na,nb=Net.loopbackPair();local pa,pb=Protocol.packParty(ga.save.party),Protocol.packParty(gb.save.party)
  local a=assert(Link.newHost(ga,na,{myParty=pa,theirParty=pb,theirName='GUEST',seed=3917,verdict='full',strict=true}))
  local b=assert(Link.newGuest(gb,nb,{myParty=pb,theirParty=pa,theirName='HOST',seed=3917,verdict='full',strict=true}))
  local lowerCalls=0
  f.loaded.loader.exports.checkpoint_fixture.api.hooks:wrap('battle.enemy_switch_or_item',function()lowerCalls=lowerCalls+1;return false end)
  for i,battle in ipairs({a,b})do
   local game=i==1 and ga or gb;game.stack:push(battle)
   for _,actor in ipairs({battle.player,battle.enemy})do
    actor.abilityOverride=false
    if protected and actor.mon.nickname=='H_ALPHA'then actor.substituteHP=100 end
    actor.curStats.speed=actor.mon.nickname=='H_ALPHA'and 200 or 100
   end
  end
  local seen={}
  for frame=1,30000 do
   for i,game in ipairs({ga,gb})do
    local battle=i==1 and a or b
    f.loaded.loader.game=game
    battle.moveIndex=(battle.turnCount or 0)==0 and 1 or 2
    Input.pressed=battle.localHashes[3]and{}or{a=true}
    game.stack:update(1/60)
    for turn=1,3 do
     if battle.localHashes[turn]and not(seen[i]and seen[i][turn])then
      seen[i]=seen[i]or{};seen[i][turn]=true
      for _,actor in ipairs({battle.player,battle.enemy})do
       local substituted=protected and actor.mon.nickname=='H_ALPHA'
       T.eq(actor.expLastLandedMove,69,'actual first-turn strike remains the last landed move')
       T.eq(actor.expLastHitByType,0,'native Normal type survives linked status turns')
       T.eq(actor.expLastHitById,not substituted and(actor.isPlayer and 1 or 0)or nil,'HP attacker is local to each peer; Substitute retains no HP attacker')
      end
     end
    end
   end
   if a.localHashes[3]and b.localHashes[3]then break end
  end
  for turn=1,3 do
   T.check(a.localHashes[turn]~=nil and b.localHashes[turn]~=nil,'both peers complete a native history turn')
   T.eq(a.localHashes[turn],b.localHashes[turn],'complete native turn hashes agree')
   T.same(a.localParts[turn],b.localParts[turn],'all party and volatile components agree')
  end
  T.eq(lowerCalls,0,'actual linked history turns consume peer choices without trainer AI callbacks')
  T.eq(a.result,nil,'host stays in the live battle')
  T.eq(b.result,nil,'guest stays in the live battle')
  f.close()
 end
end
T.finish('native fixed-damage loopback commands, Substitute and received-history hashes')
