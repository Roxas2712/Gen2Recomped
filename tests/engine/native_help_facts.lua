-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local Facts=require('src.import.Gen3HelpFacts')
local Rom=require('src.import.RomGba')
local tables={{0x30,0xE4,44},{0x198,0x25C,48},{0x320,0x3D0,43},{0x480,0x4A0,7},{0x4C0,0x550,35}}
local function fixture()
 local size,base=65536,0x1000;local bytes,labels={},{}
 for i=1,size do bytes[i]=0 end
 local function put(at,value)
  for i=0,3 do bytes[at+i+1]=value%256;value=math.floor(value/256)end
 end
 local nextText=0xB400
 local function text(name,address)
  address=address or nextText;if address==nextText then nextText=nextText+4 end
  labels[name]=address;bytes[address+1],bytes[address+2]=0,255
  return 0x08000000+address
 end
 local names={'WhatShouldIDo','HowDoIDoThis','WhatDoesThisTermMean','AboutThisGame','TypeMatchupList','Exit'}
 for i,name in ipairs(names)do
  put(base+(i-1)*4,text('Help_Text_'..name,i==1 and 0xB000 or nil))
  put(base+24+(i-1)*4,text('Help_Text_Desc'..name))
 end
 text('Help_Text_NativeGreeting',0xB000+0x1D1);text('Help_Text_Cancel',0xB000+0x77)
 text('Help_Text_TheHelpSystem')
 for topic,row in ipairs(tables)do
  for id=1,row[3]do
   put(base+row[1]+id*4,text(('Help_Text_Q%d_%d'):format(topic,id)))
   put(base+row[2]+id*4,text(('Help_Text_A%d_%d'):format(topic,id)))
  end
 end
 bytes[base+0x93E+1],bytes[base+0x93E+2],bytes[base+0x93E+3]=1,43,255
 local order={3,0,1,2,4,5}
 for i,value in ipairs(order)do bytes[base+0xC40+i]=value end
 for context=0,35 do for topic=1,6 do
  bytes[base+0xC40+6+context*6+topic]=(topic==6 or context>0 and topic==4)and 1 or 0
 end end
 for context=0,35 do for topic,row in ipairs(tables)do
  local list=base+0x2000+(context*5+topic-1)*4
  bytes[list+1],bytes[list+2],bytes[list+3]=1,row[3],255
  put(base+0x960+(context*5+topic-1)*4,0x08000000+list)
 end end
 for i=0,287 do bytes[base+0x8F88+i+1]=i%256 end
 for i=0,31 do bytes[base+0x90A8+i+1]=i end
 local function reader()
  local chars={};for i,value in ipairs(bytes)do chars[i]=string.char(value)end
  return Rom.new(table.concat(chars))
 end
 return reader,put,bytes,labels,base
end
for _,edition in ipairs{'firered','leafgreen'}do
 local reader,put,bytes,labels,base=fixture()
 local rom=reader();local data=Facts.decode(rom,edition,labels,'synthetic reader')
 T.eq(data.schema,1);T.eq(data.edition,edition);T.eq(data.romSha1,'synthetic reader')
 T.eq(data.greeting,'Help_Text_NativeGreeting');T.eq(data.cancel,'Help_Text_Cancel')
 T.eq(#data.topics,6);T.eq(#data.entries,5)
 T.same(data.topicOrder,{4,1,2,3,5,6});T.same(data.topicFlags[0],{false,false,false,false,false,true})
 for topic,row in ipairs(tables)do
  T.eq(#data.entries[topic],row[3])
  for id,entry in ipairs(data.entries[topic])do
   T.eq(entry.question,('Help_Text_Q%d_%d'):format(topic,id))
   T.eq(entry.answer,('Help_Text_A%d_%d'):format(topic,id))
  end
 end
 for context=0,35 do for topic,row in ipairs(tables)do
  T.same(data.contexts[context][topic],{1,row[3]},'actual native context/topic indexing')
 end end
 T.same(data.basicTerms,{1,43});T.eq(data.frame.format,'4bpp');T.eq(#data.frame.tiles,288)
 for i,value in ipairs(data.frame.tiles)do T.eq(value,(i-1)%256)end
 for i,value in ipairs(data.frame.palette)do T.eq(value,(i-1)*2+i*2*256-256)end
 T.eq(data.rom,nil);T.eq(data.labels,nil,'descriptor retains no reader/profile')
 labels.Help_Text_Q1_1=7;T.eq(data.entries[1][1].question,'Help_Text_Q1_1','names are detached')
 -- Real import admission cannot be forged by the pure decoder fixture.
 local extractor={rom=rom,version=edition,manifest={romSha1=require('src.core.GameVersion').info(edition).sha1}}
 local value,why=Facts.extract(extractor);T.eq(value,nil);T.check(why:find('verified',1,true)~=nil)
 -- Corrupt pointer, unknown label, list ID and termination are independent
 -- rejected controls over the real native RomGba reader.
 local pointerAt=base+tables[1][1]+4
 put(pointerAt,0xFFFFFFFF);T.raises(function()Facts.decode(reader(),edition,labels,'x')end,'pointer exceeds')
 put(pointerAt,0x08000007);labels.Help_Text_Q1_1=nil
 T.raises(function()Facts.decode(reader(),edition,labels,'x')end,'catalog label')
 local _,_,_,fresh=fixture();labels=fresh
 put(pointerAt,0x08000000+labels.Help_Text_Q1_1)
 local list=base+0x2000;bytes[list+1]=45
 T.raises(function()Facts.decode(reader(),edition,labels,'x')end,'entry ID')
 bytes[list+1]=1;for i=1,64 do bytes[list+i]=1 end
 T.raises(function()Facts.decode(reader(),edition,labels,'x')end,'unterminated')
end
for _,edition in ipairs{'red','crystal','emerald','ruby','sapphire','platinum','black'}do
 T.eq(Facts.supports(edition),false)
 T.eq(Facts.extract({version=edition}),nil,'other editions have no invented Help resource')
end
T.finish('native Help pointer metadata, shared catalog names, context bounds and original frame bytes')
