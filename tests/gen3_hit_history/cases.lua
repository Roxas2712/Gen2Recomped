-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Actual move commands produce every observed history value; none are seeded.
local C = {}
function C.run(root, backend, edition, mode)
  local rows = {}
  local definitions = {
    {33,'TACKLE',0,'NO_ADDITIONAL_EFFECT',35,100,51},
    {200,'UNMIRRORABLE',0,'NO_ADDITIONAL_EFFECT',35,100,35},
    {201,'MISSED_MOVE',0,'NO_ADDITIONAL_EFFECT',35,1,51},
    {119,'MIRROR_MOVE',9,'MIRROR_MOVE_EFFECT',0,100,0},
    {311,'WEATHER_BALL',203,'WEATHER_BALL_EFFECT',50,100,51},
    {24,'DOUBLE_KICK',44,'ATTACK_TWICE_EFFECT',10,100,51},
    {167,'TRIPLE_KICK',104,'TRIPLE_KICK_EFFECT',10,90,51},
    {150,'SPLASH',85,'SPLASH_EFFECT',0,100,0},
    {202,'ZERO_POWER',0,'NO_ADDITIONAL_EFFECT',0,100,51},
    {226,'BATON_PASS',127,'BATON_PASS_EFFECT',0,0,0},
  }
  for _, case in ipairs({'normal','substitute','substitute then HP','miss','immunity','unmirrorable',
      'hit then miss','hit then immunity','foe retaliates','called mirror','endure zero','faint',
      'rain','sun','sand','hail','double hit','double immunity','triple kick','triple late miss',
      'row edited after hit','triple first miss','triple protect','hit then protect','baton pass','splash','zero power'}) do
    local f = dofile(root..'/tests/charge_required/fixture.lua').new(root,backend,edition,3,'unified',false,false,
      'portable_enemy_action',function(data,_,_,rom,names)
        for _, row in ipairs(definitions) do
          local n,name,effect,host,power,accuracy,flags=unpack(row)
          if backend=='gen1' then
            rom[n]={effect=effect,power=power,type=0,accuracy=accuracy,pp=40,target=0,priority=0,flags=flags,secondaryChance=0}
            data.gen3Moves._rom[n]=rom[n];data.gen3Pokemon._moveNames[n]=name;names[n]=name
          else
            local id=('MOVE_%03d'):format(n)
            data.moves[id]={id=id,index=n,name=name,effect=host,gen3Effect=effect,type='NORMAL',gen3Type=0,
              power=power,accuracy=accuracy,pp=40,target=0,priority=0,flags=flags,secondaryChance=0}
          end
        end
        if backend=='gen2' then
          data.constants.generation=3;data.type_chart.types=data.type_chart.types or{}
          for name,id in pairs({NORMAL=0,GHOST=7,FIRE=10,WATER=11,ROCK=5,ICE=15})do
            data.type_chart.types[name]={id=name,index=id,category=(id==10 or id==11 or id==15)and'special'or'physical'}
          end
          data.type_chart.matchups[#data.type_chart.matchups+1]={attacker='NORMAL',defender='GHOST',multiplier=0}
        end
      end,function(files)
        files['mods/portable_enemy_action/main.lua']='return function(mod) mod.exports.api=mod end'
      end)
    local copy=require('src.mods.Merge').deepCopy
    local b=f.fresh('TACKLE').battle
    local players={b.player.mon,copy(b.player.mon),copy(b.player.mon)}
    local foes={b.enemy.mon,copy(b.enemy.mon),copy(b.enemy.mon)}
    local State,Engine,Adapter,ad
    if backend=='gen1' then
      State,Engine=require('src.core.game3.battle.state'),require('src.core.game3.battle.engine')
      Adapter=require('src.core.game3.battle.adapter')
      b=State.new({wild=false,double=mode~='single',playerParty=players,foeParty=foes});ad=Adapter.new(b)
    else
      b.kind,b.trainer,b.enemyParty='trainer',{name='HISTORY',items={}},foes
      f.game.save.party,b.playerParty,b.playerPartyIndices=players,players,{1,2,3};b:syncSides()
      if mode~='single' then b.double=true;b:sendOutSecondPair()end
    end
    local function at(pos)
      if backend=='gen1' then return State.battler(b,pos)end
      return b:battlerAt(pos)
    end
    if mode=='right-empty-left' then
      if backend=='gen1' then b.battlers[1]=nil;b.absent=b.absent or{};b.absent[1]=true
      else b:placeBattler(1,nil);b:syncSides()end
    end
    local user=at(mode=='right'and 2 or 0)
    local target=at((mode=='single' or mode=='left') and 1 or 3)
    for pos=0,3 do
      local actor=at(pos)
      if actor then
        actor.mon.hp,actor.mon.maxHp=400,400
        if backend=='gen1' then
          actor.type1,actor.type2,actor.ability=0,0,0
          actor.mon.attack,actor.mon.defense,actor.mon.speed,actor.mon.spAtk,actor.mon.spDef=50,50,50,50,50
          actor.mon.moves,actor.mon.pp,actor.mon.maxPp={},{},{}
          for slot,row in ipairs(definitions)do actor.mon.moves[slot],actor.mon.pp[slot],actor.mon.maxPp[slot]=row[1],40,40 end
        else
          actor.curTypes,actor.abilityOverride={'NORMAL'},false
          for _,stat in ipairs({'attack','defense','speed','special','spatk','spdef'})do actor.curStats[stat]=50;actor.mon.stats[stat]=50 end
          actor.mon.stats.hp=400;actor.mon.moves={}
          for _,row in ipairs(definitions)do actor.mon.moves[#actor.mon.moves+1]={id=('MOVE_%03d'):format(row[1]),pp=40}end
          actor.curMoves=actor.mon.moves
        end
      end
    end
    local function value(v)if v==nil then return false end;return v end
    local function history(actor)
      local mirror=backend=='gen1' and actor.expLastTakenMove or actor.gbaLastTakenMove
      if backend=='gen2' and mirror then mirror=f.data.moves[mirror] and f.data.moves[mirror].index end
      return {landed=value(actor.expLastLandedMove),kind=value(actor.expLastHitByType),attacker=value(actor.expLastHitById),mirror=value(mirror)}
    end
    local function ghost()
      if backend=='gen1' then target.type1,target.type2=7,7 else target.curTypes={'GHOST'}end
    end
    local function allHistory()
      local out={}
      for pos=0,3 do local actor=at(pos);if actor then out[#out+1]={position=pos,history=history(actor)}end end
      return out
    end
    local trace,actors,events,raw,rng={history(target)},{allHistory()},{},{},{}
    local observedTarget=target
    local high,accuracy,late=false,0,false
    b.rng=function(lo,hi)
      local v=lo or 0
      if lo==1 and hi==100 then accuracy=accuracy+1;if high or late and accuracy>1 then v=hi end
      elseif high then v=hi or lo or 0 end
      rng[#rng+1]={lo=value(lo),hi=value(hi),value=v};return v
    end
    f.e.api.events:on('battle.damage_dealt',function(e)
      -- API3 events are detached; observe the actual command recipient through
      -- the fixture owner rather than mistaking a view for a live battler.
      events[#events+1]={history=history(observedTarget),substitute=e.substitute==true,kind=e.kind}
      if case=='double immunity' and #events==1 then ghost()end
      if case=='row edited after hit' then
        -- The next action can see a changed dataset; this landed hit cannot.
        if backend=='gen1' then f.data.gen3Moves._rom[33].type=17
        else f.data.moves.MOVE_033.type='DARK';f.data.moves.MOVE_033.gen3Type=17 end
      end
    end)
    local function use(n,attacking,defending)
      attacking,defending=attacking or user,defending or target
      observedTarget=defending
      local slot;for i,row in ipairs(definitions)do if row[1]==n then slot=i;break end end
      if backend=='gen1' then Engine.resolveMove(attacking,defending,n,slot,ad,b,{}, {})
      else b:performMove(attacking,defending,attacking.curMoves[slot])end
      if n==226 then
        local replacement=at((mode=='single' or mode=='left') and 1 or 3)
        assert(replacement~=target,'actual Baton Pass replaces the recipient')
        target=replacement
      end
      trace[#trace+1]=history(target)
      actors[#actors+1]=allHistory()
      raw[#raw+1]={hp=target.mon.hp,substitute=target.substituteHP or 0,draws=copy(rng)}
    end
    if case=='substitute' or case=='substitute then HP' then target.substituteHP=100 end
    if case=='immunity' then ghost()end
    if case=='triple protect' then target[backend=='gen1'and'expProtected'or'protecting']=true end
    if case=='miss' or case=='triple first miss' then high=true end
    if case=='triple late miss' then late=true end
    if case=='endure zero' then
      target.mon.hp=1
      if backend=='gen1' then target.expEnduring=true else target.enduring=true end
    end
    if case=='faint' then target.mon.hp=1 end
    local weather=({rain='RAIN',sun='SUN',sand='SAND',hail='HAIL'})[case]
    if weather then
      if backend=='gen1' then b.weather=weather else b.field.weather=weather=='SAND' and 'SANDSTORM' or weather end
    end
    local chosen=33
    if case=='miss' then chosen=201 elseif case=='unmirrorable' then chosen=200
    elseif weather then chosen=311 elseif case:find('double',1,true)then chosen=24
    elseif case:find('triple',1,true)then chosen=167 elseif case=='splash'then chosen=150
    elseif case=='zero power'then chosen=202 end
    use(chosen)
    if case=='hit then miss' then high=true;use(201)
    elseif case=='hit then immunity' then ghost();use(200)
    elseif case=='foe retaliates' then use(33,target,user)
    elseif case=='called mirror' then use(119,target,user)
    elseif case=='substitute then HP' then target.substituteHP=nil;use(33)
    elseif case=='hit then protect' then target[backend=='gen1'and'expProtected'or'protecting']=true;use(24)
    elseif case=='baton pass' then b.interactiveChoices=false;b.batonPassChooser=function()return 3 end;use(226,target,target)end
    local final=trace[#trace]
    if case=='normal'or case=='unmirrorable'or case=='endure zero'or case=='faint'then
      assert(final.landed==chosen and final.kind==0,'successful actual native history')
      assert(final.attacker==(backend=='gen1'and user.id or user.position),'numeric attacker, including slot zero')
    end
    if case=='baton pass'then assert(final.landed==false and final.kind==false and final.attacker==false,'actual Baton Pass clears received history')end
    if case=='substitute' then assert(final.landed==33 and final.attacker==false,'Substitute owns landed history but no HP attacker')end
    if case=='hit then miss'or case=='hit then immunity'then assert(final.landed==33,'failed later action retains prior landed move')end
    rows[#rows+1]={case=case,history=trace,actors=actors,events=events,raw=raw}
    f.close()
  end
  return rows
end
return C
