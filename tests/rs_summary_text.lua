-- Inspect exact RS map-section text using the actual host decoder, no writes.
love=require('tests.love_stub')
love.filesystem.load=loadfile
local function read(path)local f=assert(io.open(path,'rb'));local raw=f:read('*a');f:close();return raw end
local edition=assert(arg[1])
local bytes=read(assert(arg[2]))
local manifest=require('src.link.Json').decode(read('tools/rom_manifest_'..edition..'.json'))
local x=require('src.import.RomExtractorGen3').new(bytes,edition,manifest)
local S=require('compat.gen1-rs.Loader').new(edition)('src.import.gba.syms').of(edition)
local at=S.off('gRegionMapEntries')
local bad=0
local names={}
for i=0,S.count('gRegionMapEntries',8)-1 do
  local ptr=x.rom:u32(at+i*8+4)-0x08000000
  if ptr>=0 and ptr<x.rom.size then
    local text=x:readText(ptr,32,nil,{rsNameEnd=true})
    names[i]=text
    if not text then
      local hex={};for p=ptr,ptr+31 do hex[#hex+1]=('%02X'):format(x.rom:u8(p))end
      print(('RS_MAP_TEXT_FAILURE row=%d off=%X bytes=%s'):format(i,ptr,table.concat(hex,' ')))
      bad=bad+1
    end
  end
end
assert(bad==0,'RS map sections refused by the host text decoder: '..bad)
assert(names[0]=='LITTLEROOT TOWN' and names[16]=='ROUTE 101','Native map-name stem, suffix and route')
local probe=require('src.import.RomExtractorGen3').new(string.char(0xFC,0x00,0xBB,0xFF),edition,manifest)
assert(probe:readText(0)==nil,'General RS scan retains strict rejection')
assert(probe:readText(0,nil,nil,{rsNameEnd=true})=='A','RS NAME_END has zero operands')
probe.version='emerald';assert(probe:readText(0,nil,nil,{rsNameEnd=true})==nil,'Other dialects retain strict rejection')
probe.version=edition;probe.rom=require('src.import.RomExtractorGen3').new(string.char(0xFC,0x7F,0xBB,0xFF),edition,manifest).rom
assert(probe:readText(0,nil,nil,{rsNameEnd=true})==nil,'Unknown RS control remains rejected')
print('PASS_RS_SUMMARY_TEXT '..edition)
