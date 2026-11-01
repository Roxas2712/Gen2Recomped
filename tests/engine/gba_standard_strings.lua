-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local M=require('src.import.Gen3StandardStrings')
local C=require('src.script.Commands');local G=require('src.script.Gen3Commands')
local V=require('src.core.GameVersion')
local hashes={ruby='f28b6ffc97847e94a6c21a63cacf633ee5c8df1e',sapphire='3ccbbd45f8553c36463f13b938e833f652b793e4',
 emerald='f3ae088181bf583e55daf962a92bb46f4f1d07b7',firered='41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc',leafgreen='574fa542ffebb14be69902d1d36f1ec0a4afd71e'}
local previous=V.get()
for _,edition in ipairs{'ruby','sapphire','emerald','firered','leafgreen'}do
 V.set(edition)
 local hash=hashes[edition];local p=M.profile(edition,hash)
 local bytes,pointers,expected={},{},{}
 for i=0,p.count-1 do
  local at=i*80;local name=('Zeile %d é'):format(i);expected[i]=name
  pointers[p.at+i*4]=at
  for j=1,#name do bytes[at+j-1]=name:byte(j)end
  bytes[at+#name]=255
 end
 local rom={size=p.at+p.count*4}
 function rom:pointer(at)return pointers[at]end
 function rom:u8(at)return bytes[at]or 0 end
 local function decode(at,length)
  local out={}
  for j=0,length-1 do local b=rom:u8(at+j);if b==255 then break end;out[#out+1]=string.char(b)end
  return table.concat(out)
 end
 local record,why=M.extract(rom,{romSha1=hash},hash,edition,decode)
 T.check(record~=nil,why);T.check(M.valid(record,edition))
 T.eq(record.count,edition=='emerald'and 30 or(edition=='ruby'or edition=='sapphire')and 19 or 29)
 local ctx={game={data={constants={gen3StandardStrings=record},text={TEXT_PLAIN='unchanged'}}},save={gen3Vars={}}}
 for i=0,p.count-1 do
  T.eq(M.lookup(record,edition,i),expected[i],'every original zero-based table row survives')
  C.g3_buffer(ctx,0,'std',i)
  T.eq(ctx.game.stringBuffers[1],expected[i],edition..' bufferstdstring fills the text substitution')
 end
 G.setVar(ctx.save,0x8004,p.count-1);C.g3_buffer(ctx,2,'std',0x8004)
 T.eq(ctx.game.stringBuffers[3],expected[p.count-1],'VarGet resolves the standard-string index')
 C.g3_buffer(ctx,1,'text','TEXT_PLAIN');T.eq(ctx.game.stringBuffers[2],'unchanged')
 for _,index in ipairs{-1,.5,p.count,0/0,math.huge}do
  T.eq(M.lookup(record,edition,index),nil,'out-of-range IDs cannot read adjacent ROM tables')
 end
 C.g3_buffer(ctx,0,'std',p.count);T.eq(ctx.game.stringBuffers[1],'','invalid ID clears stale substitution')
 T.eq(M.lookup(record,edition=='ruby'and'sapphire'or'ruby',0),nil,'another cartridge cannot supply labels')
 local value=record.strings[0];record.strings[0]=nil
 T.eq(M.valid(record,edition),false,'missing row invalidates cache readiness');record.strings[0]=value
 local Cache=require('src.import.CacheFs');local read=Cache.read
 Cache.read=function()return 'return {}'end
 T.eq(#M.missing(edition),1,'an older constants cache requires the missing table')
 Cache.read=function()return 'invalid Lua constants' end
 T.eq(#M.missing(edition),1,'unreadable constants cannot mark the import ready')
 Cache.read=read
 T.eq(M.extract(rom,{romSha1='other'},hash,edition,decode),nil,'manifest must match the admitted cartridge')
 T.eq(M.extract(rom,{romSha1=hash},'other',edition,decode),nil,'unknown ROM cannot use pinned offsets')
 local ptr=pointers[p.at];pointers[p.at]=nil
 T.eq(M.extract(rom,{romSha1=hash},hash,edition,decode),nil,'invalid pointer fails the import')
 pointers[p.at]=ptr;local endByte=bytes[#expected[0]];bytes[#expected[0]]=0
 T.eq(M.extract(rom,{romSha1=hash},hash,edition,decode),nil,'unterminated strings are rejected')
 bytes[#expected[0]]=endByte
 T.eq(M.extract(rom,{romSha1=hash},hash,edition,function()return '{BYTE:01}'end),nil,'unreadable text cannot mark import complete')
 local size=rom.size;rom.size=p.at+p.count*4-1
 T.eq(M.extract(rom,{romSha1=hash},hash,edition,decode),nil,'table bounds are checked before reading')
 rom.size=size
end
V.set(previous)
T.finish('GBA standard script buffers use complete cartridge-owned tables and zero-based VarGet indices')
