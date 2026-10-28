love=require('tests.love_stub');love.filesystem.load=loadfile
local function read(p)local f=assert(io.open(p,'rb'));local s=f:read('*a');f:close();return s end
local edition=assert(arg[1]);local bytes=read(assert(arg[2]))
local manifest=require('src.link.Json').decode(read('tools/rom_manifest_'..edition..'.json'))
local x=require('src.import.RomExtractorGen3').new(bytes,edition,manifest)
local S=require('compat.gen1-rs.Loader').new(edition)('src.import.gba.syms').of(edition)
local at=S.off('gMonIconTable');local indices=S.off('gMonIconPaletteIndices')
assert(at==manifest.symbols.gMonIconTable and indices==manifest.symbols.gMonIconPaletteIndices)
local actual,ok=x:iconTableBase(at,indices,411);assert(actual==at and ok)
for _,name in ipairs({'gMonIcon_Bulbasaur','gMonIcon_Pikachu','gMonIcon_Treecko','gMonIcon_Mudkip','gMonIcon_Egg'})do
  local found=false;local target=S.off(name)
  for i=0,439 do if x.rom:pointer(at+i*4)==target then found=true end end
  assert(found,'Icon table does not name '..name)
end
local win=S.off('gWindowTemplate_81E6CAC')
assert(x.rom:u8(win+8)==4,'Party mon text requires the native imported small font 4')
assert(x.rom:u8(S.off('gWindowTemplate_81E6CC8')+8)==3,'Party action text requires native font 3')
print('PASS_RS_PARTY_ROM '..edition)
