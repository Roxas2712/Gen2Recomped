-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Cartridge table facts, validated against pret/pokefirered help_system.c
-- ce6406d8c2eaf46d543c8a2606de0c3cb1951982 and both native FR/LG ROMs.
-- Text remains in the native structured catalog; no second text decoder.
local M={SCHEMA=1,REVISION=1}
local titles={'WhatShouldIDo','HowDoIDoThis','WhatDoesThisTermMean',
 'AboutThisGame','TypeMatchupList','Exit'}
local tables={{0x30,0xE4,44},{0x198,0x25C,48},{0x320,0x3D0,43},
 {0x480,0x4A0,7},{0x4C0,0x550,35}}
function M.supports(edition)return edition=='firered'or edition=='leafgreen'end
local function word(value)
 return string.char(value%256,math.floor(value/256)%256,
  math.floor(value/65536)%256,math.floor(value/16777216)%256)
end
-- Pure decoding is separate from admission so small synthetic readers can
-- exercise malformed tables without inventing a verified cartridge hash.
function M.decode(rom,edition,labels,sha1)
 assert(M.supports(edition),'native Help is an FR/LG resource')
 local reverse,signature={},{}
 for name,address in pairs(labels)do
  if type(name)=='string'and type(address)=='number'and address%1==0
   and address>=0 and address<rom.size then
   if not reverse[address]or name<reverse[address]then reverse[address]=name end
  end
 end
 for i,name in ipairs(titles)do
  local address=assert(labels['Help_Text_'..name],'missing native Help title')
  signature[i]=word(address+0x08000000)
 end
 signature=table.concat(signature)
 local found=assert(rom.data:find(signature,1,true),'native Help pointer table missing')
 assert(not rom.data:find(signature,found+1,true),'ambiguous native Help pointer table')
 local base=found-1;assert(base%4==0,'unaligned native Help pointer table')
 -- Locate the native topic order beside its boolean context matrix. These
 -- bytes describe the menu; no runtime heuristic substitutes list emptiness.
 local orderNeedle=string.char(3,0,1,2,4,5,0,0,0,0,0,1,0,0,0,1,0,1)
 local orderAt=assert(rom.data:find(orderNeedle,base+0xC30+1,true),'native Help topic matrix missing')-1
 assert(orderAt>=base+0xC30 and orderAt+6+36*6<=base+0x8F88,'native Help topic matrix exceeds table region')
 assert(not rom.data:find(orderNeedle,orderAt+2,true),'ambiguous native Help topic matrix')
 local function pointer(at)
  assert(at>=0 and at+4<=rom.size,'native Help table exceeds ROM')
  local address=rom:u32(at)-0x08000000
  assert(address>=0 and address<rom.size,'native Help pointer exceeds ROM')
  return address
 end
 local function label(address)
  return assert(reverse[address],'native Help text has no structured catalog label')
 end
 local function text(at)return label(pointer(at))end
 local function list(at,maximum)
  local result={}
  for i=0,63 do
   assert(at+i<rom.size,'native Help list exceeds ROM')
   local value=rom:u8(at+i)
   if value==255 then return result end
   assert(value>=1 and value<=maximum,'invalid native Help entry ID')
   result[#result+1]=value
  end
  error('unterminated native Help list')
 end
 local out={schema=M.SCHEMA,edition=edition,romSha1=sha1,topics={},entries={},contexts={},
  greeting=label(pointer(base)+0x1D1),cancel=label(pointer(base)+0x77),
  heading='Help_Text_TheHelpSystem',basicTerms=list(base+0x93E,43),topicOrder={},topicFlags={},
  frame={format='4bpp',tiles={},palette={}}}
 for i=1,6 do out.topics[i]={label=text(base+(i-1)*4),description=text(base+24+(i-1)*4)}end
 for i=0,5 do out.topicOrder[i+1]=rom:u8(orderAt+i)+1 end
 for context=0,35 do
  local row={};out.topicFlags[context]=row
  for topic=1,6 do
   local value=rom:u8(orderAt+6+context*6+topic-1)
   assert(value==0 or value==1,'invalid native Help topic flag');row[topic]=value==1
  end
 end
 for topic,t in ipairs(tables)do
  local entries={};out.entries[topic]=entries
  for i=1,t[3]do entries[i]={question=text(base+t[1]+i*4),answer=text(base+t[2]+i*4)}end
 end
 for context=0,35 do
  local row={};out.contexts[context]=row
  for topic,t in ipairs(tables)do
   local at=base+0x960+(context*5+topic-1)*4
   row[topic]=rom:u32(at)==0 and{}or list(pointer(at),t[3])
  end
 end
 assert(base+0x90A8+32<=rom.size,'native Help artwork exceeds ROM')
 for i=0,287 do out.frame.tiles[i+1]=rom:u8(base+0x8F88+i)end
 for i=0,15 do out.frame.palette[i+1]=rom:u16(base+0x90A8+i*2)end
 return out
end
function M.extract(extractor)
 local Version=require('src.core.GameVersion')
 local edition=type(extractor.version)=='table'and extractor.version.id or extractor.version
 if not M.supports(edition)then return nil,'this cartridge has no native Help resource'end
 local info=Version.info(edition)
 local verified,digest=pcall(require('src.import.RomVerification').sha1,extractor.rom.data)
 if not info or extractor.manifest.romSha1~=info.sha1 or not verified or digest~=info.sha1 then
  return nil,'native Help requires a verified FR/LG cartridge'
 end
 local out=M.decode(extractor.rom,edition,require('src.import.gba.text_labels.'..edition),info.sha1)
 -- Reuse the native naming extractor's edition-adjusted keypad source.
 -- All thirteen regions are the text.c sKeypadIcons ABI, not new artwork.
 local at=assert(extractor.FRLG_NAMING and extractor.FRLG_NAMING.KEYPAD_GFX)
 assert(at>=0 and at+2048<=extractor.rom.size,'native keypad artwork exceeds ROM')
 out.keypad={tiles={},regions={}}
 for i=0,2047 do out.keypad.tiles[i+1]=extractor.rom:u8(at+i)end
 local starts={0,1,2,4,6,9,12,13,14,15,32,33,34}
 local widths={8,8,16,16,24,24,8,8,8,8,8,8,8}
 for i,tile in ipairs(starts)do out.keypad.regions[i]={tile=tile,width=widths[i],height=12}end
 return out
end
return M
