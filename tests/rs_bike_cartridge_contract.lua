love=require('tests.love_stub');love.filesystem.load=loadfile
local Rom=require('src.import.RomGba');local X=require('src.import.RomExtractorGen3')
local M=require('src.import.Gen3RsBike');local J=require('src.link.Json')
local n=0
local function check(v,why)n=n+1;assert(v,why)end
local function equal(a,b,why)check(J.encode(a)==J.encode(b),why)end
local original=X.BIKE_RULES.STEP_TIMES
for _,version in ipairs({'ruby','sapphire'})do
  local f=assert(io.open(assert(os.getenv('RS_BIKE_'..version:upper()..'_ROM')),'rb'))
  local bytes=f:read('*a');f:close();local rom=Rom.new(bytes)
  local context=M.new(version,rom);local S=context.S
  local x=setmetatable({rom=rom,version=version},X)
  -- Exercise the production constants writer, including its mud-ramp closure.
  local collision={0xD0,0xD1,0xD3,0xD4,0xD5,0xD6}
  local tile={collision=collision}
  local blocks={};for i=0,#collision-1 do blocks[#blocks+1]=string.char(i,0)end
  x._maps={fixture={tileset='fixture',width=#collision,height=1,blocks=table.concat(blocks)}}
  x:bikeBehaviours({fixture=tile})
  local bike=x._constants.gen3Bike;local rules=assert(bike.rules)
  check(M.valid(bike,version),'Complete native bike cache '..version)
  check(not M.valid(bike,version=='ruby'and 'sapphire'or 'ruby'),'Reject mixed edition cache')
  equal(rules.machLadder,{1,2,4},'Three actual cartridge acceleration rungs')
  equal(rules.speedFrames,{16,8,6,4},'Distinct cartridge movement times')
  check(rules.acroHopSound==34 and rules.acroHopFrames==40,'Native hop delay and sound')
  check(tile.muddySlopeBehaviour==0xD0 and tile.acroObstacles[0xD1].kind=='bumpy_slope','Map terrain linked')
  local params=M.parameters(context)
  check(rules.nativeRsBike.stepTimesOffset==params.STEP_TIMES,'Actual step source recorded')
  check(rules.nativeRsBike.counterRule.advance==1 and rules.nativeRsBike.counterRule.limit==2,
    'Native acceleration advances after the first tile')
  check(rules.source:find(('%07X'):format(params.STEP_TIMES),1,true),'No Emerald address in provenance')
  -- Each direction resolves through the real action function table, rather
  -- than inheriting the timing of whichever direction happened to be tested.
  for speed,at in ipairs(params.WALK_ACTIONS)do
    for dir=0,4 do
      local action=rom:u8(at+dir)
      local list=assert(rom:pointer(params.ACTION_FUNCS+action*4))
      local fn=assert(rom:pointer(list))-1
      check(rom:u16(fn+6)==0x2200+math.max(1,dir),
        ('Movement direction init %s %d %d: %04X'):format(version,speed,dir,rom:u16(fn+6)))
      local op=rom:u16(fn+8)
      check(math.floor(op/256)==0x23,'Movement init speed register')
      check(rom:u16(params.STEP_TIMES+(op%256)*2)==rules.speedFrames[speed],
        'Directional movement times agree '..version..' '..speed..' '..dir)
    end
  end
  local handler,slot=x:forcedMovementHandler(S.funcOff('MetatileBehavior_IsMuddySlope'))
  check(handler==S.funcOff('ForcedMovement_MuddySlope')and slot==18,'Actual forced mud handler')
  check(not x:forcedMovementHandler(S.funcOff('PlaySE')),'Unrelated predicate must fail')
  local function modified(off,word)
    local raw=bytes:sub(1,off)..string.char(word%256,math.floor(word/256))..bytes:sub(off+3)
    return setmetatable({rom=Rom.new(raw),version=version},X)
  end
  local bad=modified(params.STEP_TIMES,0)
  check(not bad:bikeSpeedFrames(),'Reject invalid cartridge step time')
  local mover=S.funcOff('PlayerStandingHoppingWheelie')
  bad=modified(mover+8,0x2101)
  check(not pcall(bad.acroHopSound,bad),'Reject wrong hop sound register')
  bad=modified(mover+10,0x2000)
  check(not pcall(bad.acroHopSound,bad),'Reject missing PlaySE call')
  bad=modified(S.funcOff('obj_npc_ministep')+4,0x4C14)
  check(not pcall(bad.bikeSpeedFrames,bad),'Reject wrong ministep duration literal register')
  rules.acroHopSound=nil;check(not M.valid(bike,version),'Old incomplete cache must be rebuilt')
  check(X.BIKE_RULES.STEP_TIMES==original,'RS extraction must not mutate other editions')
end
for _,version in ipairs({'emerald','firered','leafgreen','red','gold'})do
  local x=setmetatable({version=version},X)
  check(x:rsBikeContext()==nil,'Other editions retain their own reader '..version)
end
print('RS_BIKE_CARTRIDGE_CHECKS',n)
