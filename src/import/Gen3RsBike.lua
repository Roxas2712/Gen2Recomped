-- Resolve RS bicycle code through its own sized symbols. Emerald's tables
-- live elsewhere and must never supply RS movement times or sound IDs.
local M={}
function M.new(version,rom)
  assert(version=='ruby'or version=='sapphire','Native RS bike version required')
  local load=require('compat.gen1-rs.Loader').new(version)
  local S=load('src.import.gba.syms').of(version)
  local funcs='\n'..load('src.import.gba.syms.'..version..'_funcs').data
  local c={version=version,rom=rom,S=S}
  function c:func(name)
    local at,n=funcs:match('\n'..name..' (%x+) (%x+)')
    at,n=tonumber(at,16),tonumber(n,16)
    assert(at==S.funcOff(name)and n and n>0,'Unsupported native RS bike function '..name)
    return at,n
  end
  function c:data(name,bytes)
    local at=S.off(name)
    assert(at and S.size(name)==bytes,'Unsupported native RS bike table '..name)
    return at
  end
  function c:codePointer(at)
    local p=rom:pointer(at)
    assert(p and p%2==1 and p<rom.size,'Invalid native RS bike code pointer')
    return p-1
  end
  return c
end
function M.parameters(c)
  local rom=c.rom
  local at,n=c:func('obj_npc_ministep')
  -- The ministep loop loads r5 with the u16 duration table, then indexes it
  -- by sprite data[6]. Follow that exact literal load, not its unnamed pool.
  assert(n==0x68 and rom:u16(at)==0xB530 and rom:u16(at+2)==0x1C04
    and rom:u16(at+6)==0x2036 and rom:u16(at+8)==0x5E22
    and rom:u16(at+10)==0x0050 and rom:u16(at+12)==0x1940,
    'Unsupported native RS ministep loop')
  local ldr=rom:u16(at+4)
  assert(math.floor(ldr/256)==0x4D,'Native RS ministep must load duration table into r5')
  local pool=math.floor((at+8)/4)*4+(ldr%256)*4
  local times=assert(rom:pointer(pool),'Native RS step duration literal missing')
  local sized=false
  for _,name in ipairs(c.S.namesAt(times))do
    if c.S.size(name)==10 then sized=true end
  end
  assert(sized,'Native RS step durations must be five u16 values')
  local actions={}
  for i,name in ipairs({'gWalkNormalMovementActions','gWalkFastMovementActions',
    'gRideWaterCurrentMovementActions','gWalkFastestMovementActions'})do
    actions[i]=c:data(name,5)
  end
  return {STEP_TIMES=times,STEP_COUNT=5,WALK_ACTIONS=actions,
    ACTION_FUNCS=c:data('gMovementActionFuncs',0x228)}
end
function M.forcedHandler(c,predicate)
  local count=c.S.count('sForcedMovementTestFuncs',4)
  assert(count>0 and count<=64,'Unsupported native RS forced movement table')
  local tests=c:data('sForcedMovementTestFuncs',count*4)
  local handlers=c:data('sForcedMovementFuncs',(count+1)*4)
  local slot
  for i=0,count-1 do
    if c:codePointer(tests+i*4)==predicate then
      assert(not slot,'Duplicate native RS forced movement predicate');slot=i+1
    end
  end
  if not slot then return nil,'Predicate missing from native RS forced movement table' end
  return c:codePointer(handlers+slot*4),slot
end
function M.hopSound(c,reader)
  local rom=c.rom
  local transition,n=c:func('AcroBikeTransition_WheelieHoppingStanding')
  local tableAt=c:data('sAcroBikeTransitions',13*4)
  assert(c:codePointer(tableAt+6*4)==transition,'Native RS standing hop transition moved')
  local mover,bytes=c:func('PlayerStandingHoppingWheelie')
  local calls=reader:blTargets(transition,n/2)
  assert(calls[#calls]==mover,'Native RS standing hop calls another mover')
  assert(bytes==36 and rom:u16(mover)==0xB510 and rom:u16(mover+2)==0x1C04
    and rom:u16(mover+4)==0x0624 and rom:u16(mover+6)==0x0E24,
    'Unsupported native RS standing hop mover')
  local op=rom:u16(mover+8)
  assert(math.floor(op/256)==0x20 and op%256>0,'Native RS standing hop has no sound ID')
  local soundCalls=reader:blTargets(mover+10,2)
  local play=c:func('PlaySE')
  assert(#soundCalls==1 and soundCalls[1]==play,'Native RS hop sound must call PlaySE')
  return op%256
end
function M.counterRule(c)
  local at,n=c:func('MachBikeTransition_TrySpeedUp')
  -- After dispatching the current rung, the native transition increments
  -- bikeFrameCounter while it is <=1. The next tile therefore uses the next
  -- rung immediately, including after the first tile of a new run.
  local tail={0x7AB2,0x0610,0x0E01,0x0E40,0x1810,0x72F0,0x2901,0xD801,0x1C50,0x72B0}
  local found
  for off=at,at+n-#tail*2,2 do
    local match=true
    for i,v in ipairs(tail)do if c.rom:u16(off+(i-1)*2)~=v then match=false;break end end
    if match then assert(not found,'Ambiguous native RS acceleration tail');found=off end
  end
  assert(found,'Unsupported native RS acceleration transition')
  return {advance=1,limit=2,offset=found}
end
function M.valid(bike,version)
  if version~='ruby'and version~='sapphire'then return false end
  local r=type(bike)=='table'and bike.rules
  local spec=type(r)=='table'and r.nativeRsBike
  if type(spec)~='table'or spec.format~=1 or spec.version~=version
    or type(spec.stepTimesOffset)~='number'or type(spec.counterRule)~='table'
    or spec.counterRule.advance~=1 or spec.counterRule.limit~=2
    or type(spec.counterRule.offset)~='number'then return false end
  if type(r.machLadder)~='table'or #r.machLadder~=3
    or r.machLadder[1]~=1 or r.machLadder[2]~=2 or r.machLadder[3]~=4
    or r.machCounterMax~=2 or r.acroSpeed~=3 or r.footSpeed~=1 or r.surfSpeed~=2
    or r.muddyMinSpeed~=3 or r.muddyDirection~=2 or r.acroHopFrames~=40
    or r.acroHopSound~=34 or type(r.speedFrames)~='table'then return false end
  for i,v in ipairs({16,8,6,4})do if r.speedFrames[i]~=v then return false end end
  return true
end
return M
