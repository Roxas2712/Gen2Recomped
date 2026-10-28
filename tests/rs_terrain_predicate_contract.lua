local M=require('src.import.Gen3RsTerrain')
local n=0
local function check(value,why)n=n+1;assert(value,why)end
local words={0xB500,0x0600,0x0E00,0x2820,0xD001,0x2000,0xE000,0x2001,0xBC02,0x4708}
local mock={u16=function(_,off)return words[off/2+1]end}
for _,v in ipairs({0,0x20,0x26,0x27,0x48,0x66,0xD2,255})do
  words[4]=0x2800+v;check(M.readEquality(mock,0)==v,'Native comparison immediate')
end
for i=1,10 do
  local old=words[i];words[i]=i==4 and 0x2920 or old+1
  check(not pcall(M.readEquality,mock,0),'Reject changed opcode/register/branch/return at word '..i)
  words[i]=old
end
love={filesystem={load=loadfile}}
local Map=require('src.world.Map')
for _,edition in ipairs({'ruby','sapphire'})do
  local path=assert(os.getenv('RS_TERRAIN_'..edition:upper()..'_ROM'),'Both real ROM inputs required')
  local f=assert(io.open(path,'rb'));local bytes=f:read('*a');f:close()
  local rom={u16=function(_,off)local a,b=bytes:byte(off+1,off+2);assert(a and b);return a+b*256 end}
  local spec=M.extract(edition,rom);check(M.valid(spec,edition),'Accept exact native '..edition..' predicates')
  for key,value in pairs({ice=0x20,iceAlias=0x20,trickFloor=0x48,thinIce=0x26,
    crackedIce=0x27,crackedFloor=0xD2,crackedFloorHole=0x66})do
    check(spec.values[key]==value,'Raw cartridge predicate '..edition..' '..key)
  end
  check(not M.valid(spec,edition=='ruby'and 'sapphire'or 'ruby'),'Reject mixed-edition metadata')
  local tile={behaviourBytes=true,iceBehaviours={spec.values.ice,spec.values.trickFloor},
    thinIceBehaviour=spec.values.thinIce,crackedFloorBehaviours={spec.values.crackedFloor,spec.values.crackedFloorHole}}
  local map=setmetatable({tileset=tile,cellBehaviour=function(self)return self.behaviour end},Map)
  for _,v in ipairs({0x20,0x48})do map.behaviour=v;check(map:isIceCell(0,0),'Native sliding floor')end
  for _,v in ipairs({0xD2,0x66,0x45,0x46,0x47})do
    map.behaviour=v;check(not map:isIceCell(0,0),'Non-ice terrain must not slide')
  end
  for _,v in ipairs({0xD2,0x66})do map.behaviour=v;check(map:isCrackedFloorCell(0,0),'Native cracked floor/hole')end
  for _,v in ipairs({0x45,0x46,0x47,0x20})do
    map.behaviour=v;check(not map:isCrackedFloorCell(0,0),'Directional slides and ice must not become cracked floor')
  end
  map.behaviour=0x26;check(map:isThinIceCell(0,0),'Native thin ice')
  map.behaviour=0x27;check(not map:isThinIceCell(0,0),'Cracked ice is distinct from thin ice')
  spec.format=99;check(not M.valid(spec,edition),'Reject unknown cache format')
end
print('RS_TERRAIN_PREDICATE_CHECKS',n)
