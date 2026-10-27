-- Read the cartridge's own boolean metatile predicates. RS cracked floor
-- must never become sliding ice just because its map forms a large sheet.
local M={}
local FIXED={[0]=0xB500,[2]=0x0600,[4]=0x0E00,[8]=0xD001,[10]=0x2000,
  [12]=0xE000,[14]=0x2001,[16]=0xBC02,[18]=0x4708}
function M.readEquality(rom,offset)
  for off,word in pairs(FIXED)do
    assert(rom:u16(offset+off)==word,'Unsupported native RS metatile predicate at '..tostring(offset))
  end
  local cmp=rom:u16(offset+6)
  assert(math.floor(cmp/256)==0x28,'Native RS metatile predicate must compare r0')
  return cmp%256
end
local FUNCTIONS={ice='MetatileBehavior_IsIce',iceAlias='MetatileBehavior_IsIce_2',
  trickFloor='MetatileBehavior_IsTrickHouseSlipperyFloor',thinIce='MetatileBehavior_IsThinIce',
  crackedIce='MetatileBehavior_IsCrackedIce',crackedFloor='MetatileBehavior_IsCrackedFloor',
  crackedFloorHole='MetatileBehavior_IsCrackedFloorHole'}
function M.extract(version,rom)
  assert(version=='ruby'or version=='sapphire','Native RS terrain version required')
  local load=require('compat.gen1-rs.Loader').new(version)
  local S=load('src.import.gba.syms').of(version)
  local functionSymbols='\n'..load('src.import.gba.syms.'..version..'_funcs').data
  local spec={format=1,version=version,values={},predicates={},
    source='ROM: exact 20-byte native RS equality predicates, not map-shape classification'}
  for key,name in pairs(FUNCTIONS)do
    local offset=S.funcOff(name)
    local declaredOffset,size=functionSymbols:match('\n'..name..' (%x+) (%x+)')
    assert(tonumber(declaredOffset,16)==offset and tonumber(size,16)==20,
      'Unsupported native RS predicate size '..name)
    spec.values[key]=M.readEquality(rom,offset);spec.predicates[key]={symbol=name,offset=offset,bytes=20}
  end
  assert(spec.values.ice==spec.values.iceAlias,'Native RS ice predicates disagree')
  return spec
end
function M.valid(spec,version)
  if (version~='ruby'and version~='sapphire')or type(spec)~='table'or spec.version~=version or spec.format~=1 or type(spec.values)~='table'
    or type(spec.predicates)~='table'then return false end
  for key,value in pairs({ice=0x20,iceAlias=0x20,trickFloor=0x48,thinIce=0x26,
    crackedIce=0x27,crackedFloor=0xD2,crackedFloorHole=0x66})do
    local row=spec.predicates[key]
    if spec.values[key]~=value or type(row)~='table'or row.symbol~=FUNCTIONS[key]
      or row.bytes~=20 or type(row.offset)~='number'then return false end
  end
  return true
end
return M
