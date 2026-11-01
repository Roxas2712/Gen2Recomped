-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- CreateNPCTrainerParty uses encoded cartridge names, a fixed personality
-- and one fixed IV for all six stats. Display translations cannot seed it.
local M = {}
local versions = {ruby=true,sapphire=true,emerald=true,firered=true,leafgreen=true}
local keys = {'hp','attack','defense','speed','spatk','spdef'}
local function integer(n,lo,hi)
  return type(n)=='number' and n%1==0 and n>=lo and n<=hi
end
function M.supports(version) return versions[version] == true end
function M.recipe(version,count,slots)
  return {format=1,version=version,recipe='encoded-name-fixed-iv-v1',
    trainerCount=count,partySlots=slots}
end
function M.validRecipe(record,version)
  return type(record)=='table' and record.format==1
    and versions[record.version] and (not version or record.version==version)
    and record.recipe=='encoded-name-fixed-iv-v1'
    and integer(record.trainerCount,1,2048) and integer(record.partySlots,0,12288)
end
function M.importedSlot(version,slot,nameHash,base)
  assert(versions[version] and integer(nameHash,0,16777215))
  assert(base==120 or base==128 or base==136)
  assert(integer(slot.iv,0,255),'Invalid native trainer IV byte')
  return {version=version,personality=base+nameHash*256,
    fixedIV=math.floor(slot.iv*31/255),species=slot.species,level=slot.level}
end
function M.validSlot(version,slot)
  local r=type(slot)=='table' and slot.nativeTrainerBirth
  return type(r)=='table' and r.version==version and versions[version]
    and integer(r.personality,0,4294967295)
    and (r.personality%256==120 or r.personality%256==128 or r.personality%256==136)
    and integer(slot.iv,0,255) and r.fixedIV==math.floor(slot.iv*31/255)
    and r.species==slot.species and r.level==slot.level
end
function M.forSlot(data,slot)
  local r=(data.constants or {}).gen3TrainerBirth
  if not M.validRecipe(r) or not M.validSlot(r.version,slot) then return nil end
  -- Authored/stored genes retain their existing construction path.
  if slot.dvs or slot.statExp or slot.ivs or slot.evs or slot.personality then return nil end
  return slot.nativeTrainerBirth
end
function M.seed(data,def,birth,rng)
  assert(type(birth)=='table' and versions[birth.version]
    and integer(birth.personality,0,4294967295) and integer(birth.fixedIV,0,31),
    'Invalid native trainer birth')
  rng=rng or love.math.random
  local bit=require('bit')
  local otId
  repeat
    -- Random32: low half first. Fixed PID/IVs spend no random birth rolls.
    local low=rng(0,65535)
    local high=rng(0,65535)
    otId=low+high*65536
  until bit.bxor(low,high,birth.personality%65536,
    math.floor(birth.personality/65536))>=8
  local ivs,evs={},{}
  for _,key in ipairs(keys) do ivs[key],evs[key]=birth.fixedIV,0 end
  local order=(data.constants or {}).natureOrder
  local abilities=def.abilities
  return {personality=birth.personality,ivs=ivs,evs=evs,otId=otId,
    nature=order and order[birth.personality%25+1] or nil,
    abilitySlot=type(abilities)=='table' and (abilities[2] and birth.personality%2+1
      or abilities[1] and 1) or nil}
end
return M
