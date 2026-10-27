love=require('tests.love_stub');love.filesystem.load=loadfile
local Rom=require('src.import.RomGba');local M=require('src.import.Gen3RsBike')
local X=require('src.import.RomExtractorGen3');local J=require('src.link.Json')
for _,version in ipairs({'ruby','sapphire'})do
  local f=assert(io.open(assert(os.getenv('RS_BIKE_'..version:upper()..'_ROM')),'rb'))
  local raw=f:read('*a');f:close();local rom=Rom.new(raw)
  local c=M.new(version,rom);local x=setmetatable({rom=rom,version=version},X)
  local slow,n=c:func('MachBikeTransition_TrySlowDown')
  assert(n==0x6c)
  for i,v in ipairs({0xB5F0,0x0600,0x0E04,0x1C27,0x4E0B,0x7AF0,0x2800,0xD002,0x3801,0x72F0,0x72B0})do
    assert(rom:u16(slow+(i-1)*2)==v,'Native coast decrements speed and copies it to the next rung')
  end
  -- The final indirect call dispatches the chosen rung through this edition's
  -- real speed callback table: slowing down is another movement, not an idle.
  assert(rom:u16(slow+0x52)==0x4805 and rom:u16(slow+0x54)==0x7AB1
    and rom:u16(slow+0x56)==0x0089 and rom:u16(slow+0x58)==0x1809
    and rom:u16(slow+0x5A)==0x6809)
  assert(rom:pointer(slow+0x68)==c.S.off('sMachBikeSpeedCallbacks'))
  local transition,bytes=c:func('GetMachBikeTransition');assert(bytes==0x56)
  assert(x:blTargets(transition,bytes/2)[1]==c.S.funcOff('GetPlayerMovementDirection'))
  for off,word in pairs({[0x10]=0x2900,[0x18]=0x7AD0,[0x1A]=0x2800,[0x1C]=0xD10E,
    [0x1E]=0x7091,[0x20]=0x2000,[0x2A]=0x4299,[0x2C]=0xD00E,[0x2E]=0x7890,
    [0x30]=0x2802,[0x32]=0xD00B,[0x34]=0x7AD0,[0x36]=0x2800,[0x38]=0xD006,
    [0x3A]=0x7023,[0x3C]=0x2002,[0x3E]=0x7090,[0x40]=0x2003,[0x48]=0x2001,
    [0x4C]=0x2002,[0x4E]=0x7090})do
    assert(rom:u16(transition+off)==word,'Native moving/standing turn decision changed')
  end
  local turn,turnBytes=c:func('PlayerTurnInPlace')
  assert(turnBytes==0x18 and x:blTargets(turn,turnBytes/2)[1]==c.S.funcOff('GetWalkInPlaceFastMovementAction'))
  local action,actionBytes=c:func('MovementAction_WalkInPlaceFastDown_Step0')
  assert(actionBytes==0x36 and rom:u16(action+0x14)==0x2008 and rom:u16(action+0x16)==0x9000,
    'The native standing turn holds an eight-frame movement action')
  print('RS_MACH_CARTRIDGE_CONTRACT',version,'coast, moving/standing branch, 8-frame turn')
end
dofile('tests/rs_mach_controller_contract.lua')
