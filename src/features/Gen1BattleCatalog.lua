-- Convert actual mounted catalogs/party to the pinned common g3u records.
-- No imported files or native singleton are changed. Contributions by Roxas2712.
local Bundle=require('src.features.gen1_gsc.Bundle')
local Ids=require('src.compat.gen1.BattleIds')
local Contract=require('src.mods.MoveEffectContract')
local M={}
local names={'hp','attack','defense','speed','spatk','spdef'}
local short={'hp','atk','def','spe','spa','spd'}
local function typeName(id)return id=='PSYCHIC_TYPE'and'PSYCHIC'or id end
function M.build(data,generation)
  local b=Bundle.new{profile='g3u'}
  local T=b:require('src.battle.g3u.Table')
  local Identity=b:require('src.online.xgen.Identity')
  local gen=generation==1 and 1 or 2
  local limits=T.LIMITS[gen]
  local ids=Ids.new(data)
  local catalog={v=1,gen=gen,moveMax=limits.moveMax,dexMax=limits.dexMax,moves={},species={},illegal={}}
  local bySpecies,byMove={},{}
  for key,row in pairs(data.pokemon or{})do
    if type(row)=='table'then
      local n=row.dex or row.nationalDex or ids:read('pokemon',key)
      if n and n>=1 and n<=limits.dexMax then
        if bySpecies[n]and data.pokemon[bySpecies[n]]~=row then return nil,'ambiguous common species '..n end
        bySpecies[n]=key
      end
    end
  end
  for n=1,limits.dexMax do
    local def=data.pokemon[bySpecies[n]]
    if not def then return nil,'missing imported common species '..n end
    local base=def.baseStats or{}
    local row={Identity.GEN3_TYPE_ID[typeName((def.types or{})[1])],Identity.GEN3_TYPE_ID[typeName((def.types or{})[2]or(def.types or{})[1])]}
    for i,key in ipairs(names)do row[i+2]=base[key]or(key=='spatk'and(base.specialAttack or base.special))or(key=='spdef'and(base.specialDefense or base.special))end
    catalog.species[n]=row
  end
  for key,row in pairs(data.moves or{})do
    local n=ids:read('moves',key)
    if n and n>=1 and n<=limits.moveMax then
      if byMove[n]and data.moves[byMove[n]]~=row then return nil,'ambiguous common move '..n end
      byMove[n]=key
    end
  end
  for n=1,limits.moveMax do
    local mv=data.moves[byMove[n]]
    if not mv then return nil,'missing imported common move '..n end
    local chosen=mv.effect
    if gen==2 and(generation==3 or not T.MAPS[2].EFFECTS[chosen])then
      local binding=Contract.bindings[chosen]
      local semantic=mv.gen3Effect or(binding and binding[tostring(generation)]and binding[tostring(generation)].semantic)
      for _,alias in ipairs(Contract.native3[tostring(semantic)]or{})do
        if T.MAPS[2].EFFECTS[alias]then chosen=alias;break end
      end
    end
    local row=T.mapMove(gen,n,{effect=chosen,type=typeName(mv.type),power=mv.power,accuracy=mv.accuracy,pp=mv.pp,effectChance=mv.effectChance or mv.secondaryChance})
    if not row then
      catalog.illegal[#catalog.illegal+1]=n
      row={mv.power or 0,Identity.GEN3_TYPE_ID[typeName(mv.type)]or 0,0,1,0,0,0,0,0}
    end
    catalog.moves[n]=row
  end
  local valid,why=T.validate(catalog);if not valid then return nil,why end
  local function party(records,tableUsed)
    local out={}
    for _,mon in ipairs(records)do
      if require('src.pokemon.Party').isEgg(mon)then return nil,'eggs cannot battle'end
      local def=data.pokemon[mon.species]
      local number=def and(def.dex or def.nationalDex or ids:read('pokemon',mon.species))
      if not number or number>tableUsed.dexMax then return nil,'choose a species in the common battle catalog'end
      if mon.status or mon.hp<=0 then return nil,'heal the party before a common-rule battle'end
      local stats=mon.stats or{}
      local rec={species=number,level=mon.level,hp=mon.hp,maxHp=stats.hp,atk=stats.attack,def=stats.defense,
        speed=stats.speed,spAtk=stats.spatk or stats.specialAttack or stats.special,spDef=stats.spdef or stats.specialDefense or stats.special,
        nickname=mon.nickname,friendship=mon.friendship or mon.happiness or 70,moves={}}
      for i,move in ipairs(mon.moves)do
        rec.moves[i]={id=ids:read('moves',move.id),pp=move.pp,ppUps=move.ppUps or 0}
      end
      rec.ivs={}
      if generation==3 then
        if type(mon.personality)~='number'or mon.personality%1~=0 or mon.personality<0 or mon.personality>4294967295 then return nil,'native personality required'end
        local gender=require('src.pokemon.IdentityRolls').gender(data,mon,3)
        rec.gender=({male=0,female=1,unknown=2})[gender]
        for i,key in ipairs(names)do
          local iv=(mon.ivs or{})[key]
          if type(iv)~='number'or iv%1~=0 or iv<0 or iv>31 then return nil,'native IVs required'end
          rec.ivs[short[i]]=iv
        end
      else
        local dvs=mon.dvs or{}
        local dvKeys={'hp','attack','defense','speed','special','special'}
        for i,key in ipairs(dvKeys)do
          local dv=key=='hp'and require('src.pokemon.Stats').hpDV(dvs)or dvs[key]
          if type(dv)~='number'or dv%1~=0 or dv<0 or dv>15 then return nil,'native DVs required'end
          rec.ivs[short[i]]=dv*2+1
        end
        if generation==2 then rec.gender=({male=0,female=1,unknown=2})[require('src.pokemon.IdentityRolls').gender(data,mon,2)]end
      end
      local ok,reason=b:require('src.battle.g3u.Wire').record(rec,tableUsed)
      if not ok then return nil,reason end
      out[#out+1]=rec
    end
    return out
  end
  return catalog,party
end
return M
