love=require('tests.love_stub');love.filesystem.load=loadfile
local Rom=require('src.import.RomGba');local X=require('src.import.RomExtractorGen3')
local J=require('src.link.Json')
for _,version in ipairs({'ruby','sapphire'})do
  local f=assert(io.open(assert(os.getenv('RS_BIKE_'..version:upper()..'_ROM')),'rb'));local raw=f:read('*a');f:close()
  local rom=Rom.new(raw);local load=require('compat.gen1-rs.Loader').new(version)
  local S=load('src.import.gba.syms').of(version);local funcs='\n'..load('src.import.gba.syms.'..version..'_funcs').data
  local function size(name)local at,n=funcs:match('\n'..name..' (%x+) (%x+)');assert(tonumber(at,16)==S.funcOff(name));return tonumber(n,16)end
  local x=setmetatable({rom=rom,version=version},X)
  local read=require('src.import.Gen3RsTerrain').readEquality
  local bike={muddySlope=read(rom,S.funcOff('MetatileBehavior_IsMuddySlope')),
    acro={[read(rom,S.funcOff('MetatileBehavior_IsBumpySlope'))]={kind='bumpy_slope'}}}
  local rules,ruleWhy=x:bikeRules(bike);local hop,hopWhy=x:acroHopFrames(bike)
  local frames,frameWhy=x:bikeSpeedFrames();local sound,soundWhy=x:acroHopSound()
  print('LEGACY_BIKE',J.encode({version=version,bike=bike,rules=rules or false,ruleWhy=ruleWhy,
    hop=hop or false,hopWhy=hopWhy,frames=frames or false,frameWhy=frameWhy,sound=sound or false,soundWhy=soundWhy}))
  for _,name in ipairs({'sForcedMovementTestFuncs','sForcedMovementFuncs','sMachBikeSpeeds','sMachBikeSpeedCallbacks','sAcroBikeTransitions',
    'gWalkSlowMovementActions','gWalkNormalMovementActions','gWalkFastMovementActions','gRideWaterCurrentMovementActions','gWalkFastestMovementActions'})do
    local values={};for at=S.off(name),S.off(name)+S.size(name)-1 do values[#values+1]=rom:u8(at)end
    print('RS_BIKE_TABLE',J.encode({version=version,name=name,offset=S.off(name),values=values}))
  end
  if version=='ruby'then
    for _,name in ipairs({'obj_npc_ministep','MovementAction_WalkNormalDown_Step0','PlayerGoSpeed1','PlayerGoSpeed2','PlayerGoSpeed4',
      'AcroBikeTransition_Moving','AcroBikeTransition_WheelieHoppingStanding','GetPlayerSpeed','ForcedMovement_MuddySlope',
      'AcroBikeHandleInputWheelieStanding','PlayerStandingHoppingWheelie',
      'MachBikeTransition_TrySpeedUp','MachBikeTransition_TrySlowDown','MachBikeTransition_TurnDirection'})do
      local at,n=S.funcOff(name),size(name);local words={}
      for p=at,at+n-2,2 do words[#words+1]=('%04X'):format(rom:u16(p))end
      local calls=x:blTargets(at,math.floor(n/2));local pools=x:poolWords(at,math.floor(n/2))
      print('RS_BIKE_FUNCTION',J.encode({name=name,offset=at,bytes=n,words=words,calls=calls,poolWords=pools}))
    end
  end
end
