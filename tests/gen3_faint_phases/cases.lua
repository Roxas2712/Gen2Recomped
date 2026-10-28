-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Native actions with explicitly seeded legal battlers/volatile scenarios.
-- This measures public HP/status/PP/faint phases, not friendship or gameplay.
local C = {}
local profiles = {
  'normal', 'protect first', 'protect all', 'immune first', 'Damp',
  'Damp after first', 'fainted Damp', 'fainted target', 'all targets faint', 'burned user',
  'target status', 'target Grudge', 'target Destiny Bond', 'target both',
  'user both', 'damage hook heals', 'Shell Bell heals',
  'fixed Grudge', 'fixed Destiny Bond', 'fixed both', 'fixed ally Bond',
  'fixed called Grudge', 'fixed called Bond',
  'Metronome Explosion', 'Metronome status', 'Metronome heal',
  'Nature Power Grudge', 'Nature Power Bond', 'Nature Power both',
  'Nature Power ally Bond', 'Nature Power first foe Bond',
}
function C.run(root, backend, edition, mode)
  local rows = {}
  for _, profile in ipairs(profiles) do
    for _, high in ipairs({false, true}) do
      local fixed = profile:sub(1, 5) == 'fixed'
      local called = profile:find('called', 1, true) ~= nil
      local metronome = profile:find('Metronome', 1, true) ~= nil
      local nature = profile:find('Nature Power', 1, true) ~= nil
      local number, effect = fixed and 69 or nature and 89 or 153, fixed and 87 or nature and 147 or 7
      local f = dofile(root .. '/tests/charge_required/fixture.lua').new(root, backend, edition, 3,
        'unified', false, false, 'portable_enemy_action', function(data, _, _, rom, names)
          if backend == 'gen1' then
            rom[number] = {effect=effect,power=fixed and 1 or nature and 100 or 200,type=nature and 4 or 0,accuracy=100,
              pp=40,target=not fixed and 32 or 0,flags=51,secondaryChance=0,priority=0}
            data.gen3Moves._rom[number] = rom[number]
            data.gen3Pokemon._moveNames[number], names[number] = 'ACTION', 'ACTION'
            if metronome then
              rom[118]={effect=83,power=0,type=0,accuracy=0,pp=40,target=0,flags=0,secondaryChance=0,priority=0}
              data.gen3Moves._rom[118]=rom[118]
              data.gen3Pokemon._moveNames[118],names[118]='METRONOME','METRONOME'
            end
            if nature then
              rom[267]={effect=173,power=0,type=0,accuracy=0,pp=40,target=1,flags=0,secondaryChance=0,priority=0}
              data.gen3Moves._rom[267]=rom[267]
              data.gen3Pokemon._moveNames[267],names[267]='NATURE_POWER','NATURE_POWER'
            end
            data.gen3Items._byId[219] = {name='SHELL BELL',holdEffect=62,holdEffectParam=8}
          else
            data.moves.ACTION = {id='ACTION',index=number,name='ACTION',gen3Effect=effect,
              effect=fixed and 'SPECIAL_DAMAGE_EFFECT' or nature and 'NO_ADDITIONAL_EFFECT' or 'EXPLODE_EFFECT',
              power=fixed and 1 or nature and 100 or 200,type=nature and 'GROUND' or 'NORMAL',accuracy=100,pp=40,
              target=not fixed and 32 or 0,flags=51,secondaryChance=0,priority=0}
            data.items.ITEM_219 = {id='ITEM_219',index=219,name='SHELL BELL',
              gen3HoldEffect=62,holdEffect='SHELL_BELL',holdEffectParam=8}
            data.constants.generation = 3
            if metronome then
              data.moves.METRONOME={id='METRONOME',index=118,name='METRONOME',gen3Effect=83,
                effect='METRONOME_EFFECT',power=0,type='NORMAL',accuracy=0,pp=40,target=0,flags=0}
              -- Authored one-entry pool: exercises the real caller; does not
              -- claim that the default cartridge selector has this pool.
              data.constants.moveOrder={'ACTION'}
            end
            if nature then data.moves.NATURE_POWER={id='NATURE_POWER',index=267,name='NATURE POWER',
              gen3Effect=173,effect='NATURE_POWER_EFFECT',power=0,type='NORMAL',accuracy=0,pp=40,target=1,flags=0}end
            data.type_chart.types = data.type_chart.types or {}
            data.type_chart.types.GHOST = {id='GHOST',index=7,category='physical'}
            data.type_chart.matchups[#data.type_chart.matchups+1] = {attacker='NORMAL',defender='GHOST',multiplier=0}
          end
        end, function(files)
          files['mods/portable_enemy_action/main.lua'] = 'return function(mod)mod.exports.api=mod end'
        end)
      local c = f.fresh('TACKLE')
      local b = c.battle
      if backend == 'gen2' then b:syncSides() end
      b.double = mode ~= 'single'
      if b.double then
        local copy = require('src.mods.Merge').deepCopy
        for id=2,3 do
          local mon = copy((id==2 and c.user or c.target).mon)
          if backend == 'gen1' then
            b.battlers[id] = require('src.core.game3.battle.state').makeBattler(mon,
              id==2 and 'player' or 'enemy', {id=id,partyIndex=2})
          else b:placeBattler(id,require('src.battle.BattleState').makeBattler(f.data,mon,id==2)) end
        end
      end
      local function actor(id)
        if backend=='gen1' then return b.battlers[id] end
        return b:battlerAt(id)
      end
      local function pos(who) return who and (who.id or who.position) end
      if mode=='right-empty-left' then
        if backend=='gen1' then b.battlers[1]=nil;b.absent=b.absent or {};b.absent[1]=true
        else b:placeBattler(1,nil);b:syncSides() end
      end
      local user = actor(b.double and 2 or 0)
      local target = actor(b.double and 3 or 1)
      if nature then b.terrain=2 end -- native SAND -> EARTHQUAKE on both engines
      if metronome and backend=='gen1' then
        b.moveMax=153;b.moveExcluded={}
        for id=1,152 do b.moveExcluded[id]=true end
      end
      if profile:find('ally Bond',1,true) and b.double then target=actor(0) end
      if profile=='Nature Power first foe Bond' then target=actor(1)or target end
      local targets = {}
      for id=0,3 do
        local who=actor(id)
        if who then
          who.mon.hp,who.mon.maxHp,who.mon.level=400,400,50
          if backend=='gen1' then
            who.type1,who.type2,who.ability=0,0,0
            who.mon.attack,who.mon.defense,who.mon.speed,who.mon.spAtk,who.mon.spDef=50,50,50,50,50
            who.mon.moves,who.mon.pp,who.mon.maxPp={number},{40},{40}
          else
            who.curTypes,who.abilityOverride={'NORMAL'},false;who.mon.stats.hp=400
            for _,key in ipairs({'attack','defense','speed','special','spatk','spdef'})do who.curStats[key]=50;who.mon.stats[key]=50 end
            who.curMoves={{id='ACTION',pp=40}};who.mon.moves=who.curMoves
          end
          if who~=user then targets[#targets+1]=who end
        end
      end
      local function ability(who)
        if backend=='gen1' then who.ability=6 else who.abilityOverride='DAMP' end
      end
      local function flag(who,which)
        who[backend=='gen1' and ('exp'..which) or (which:sub(1,1):lower()..which:sub(2))]=true
      end
      if profile=='protect first' or profile=='protect all' then
        for i,who in ipairs(targets)do if i==1 or profile=='protect all' then who[backend=='gen1'and'expProtected'or'protecting']=true end end
      elseif profile=='immune first' then
        if backend=='gen1'then targets[1].type1,targets[1].type2=7,7 else targets[1].curTypes={'GHOST'}end
      elseif profile=='Damp' then ability(target)
      elseif profile=='fainted Damp' and b.double then actor(0).mon.hp=0;ability(actor(0))
      elseif profile=='fainted target' and b.double then actor(0).mon.hp=0
      elseif profile=='burned user' then user.mon.status='BRN'
      elseif profile=='target status' or profile=='Metronome status' then target.mon.status='TOX';target.toxicCounter=5;target.sleepTurns=3
      elseif profile=='user both' then flag(user,'Grudge');flag(user,'DestinyBond') end
      if profile=='all targets faint' or profile=='target status' then
        for _,who in ipairs(targets)do who.mon.hp=1 end
      end
      if profile=='Metronome status' then target.mon.hp=1 end
      if profile:find('Grudge',1,true) or profile:find('both',1,true) and profile~='user both' then flag(target,'Grudge');target.mon.hp=1 end
      if profile:find('Bond',1,true) or profile:find('both',1,true) and profile~='user both' then flag(target,'DestinyBond');target.mon.hp=1 end
      if profile=='Shell Bell heals' then user.mon.item=backend=='gen1'and 219 or 'ITEM_219';if backend=='gen1'then user.item=219 end end
      if metronome then
        if backend=='gen1' then user.mon.moves={118}
        else user.curMoves={{id='METRONOME',pp=40}};user.mon.moves=user.curMoves end
      end
      if nature then
        if backend=='gen1' then user.mon.moves={267}
        else user.curMoves={{id='NATURE_POWER',pp=40}};user.mon.moves=user.curMoves end
      end
      local draws,calculations,events={},{},{}
      b.rng=function(lo,hi)local value=high and hi or lo;draws[#draws+1]={lo=lo,hi=hi,value=value};return value end
      local function pp(who) return backend=='gen1' and who.mon.pp[1] or who.curMoves[1].pp end
      local function state(who)
        return {id=pos(who),hp=who.mon.hp,status=who.mon.status or false,pp=pp(who),
          toxic=who.toxicCounter or false,sleep=who.sleepTurns or false,
          grudge=not not who[backend=='gen1'and'expGrudge'or'grudge'],
          bond=not not who[backend=='gen1'and'expDestinyBond'or'destinyBond']}
      end
      f.e.api.hooks:wrap('battle.damage',function(nextDamage,ctx)
        if profile=='damage hook heals' or profile=='Shell Bell heals' or profile=='Metronome heal' then ctx.user.hp=100 end
        local damage,info=nextDamage(ctx)
        calculations[#calculations+1]={userHP=ctx.user.hp,status=ctx.user.status or false,damage=damage,draws=#draws}
        return damage,info
      end)
      f.e.api.events:on('battle.damage_dealt',function(e)
        events[#events+1]={op='damage',target=pos(e.target),damage=e.damage,draws=#draws,user=state(user)}
        if profile=='Damp after first' then ability(targets[1]) end
      end)
      f.e.api.events:on('battle.fainted',function(e)
        events[#events+1]={op='faint',id=e.battler.id,status=e.battler.mon.status or false,
          draws=#draws,user=state(user),target=state(target)}
      end)
      if backend=='gen1' then
        require('src.core.game3.battle.engine').resolveMove(user,target,nature and 267 or metronome and 118 or number,not called and 1 or nil,
          require('src.core.game3.battle.adapter').new(b),b,{}, {called=called,noRetarget=true})
      elseif called then b:performMove(user,target,{id='ACTION',pp=1},true)
      else b:executeAction(user,target,user.curMoves[1]) end
      local after={}
      for id=0,3 do after[id+1]=actor(id) and state(actor(id)) or false end
      rows[#rows+1]={profile=profile,mode=mode,high=high,after=after,rng=draws,calculations=calculations,events=events}
      f.close()
    end
  end
  return rows
end
return C
