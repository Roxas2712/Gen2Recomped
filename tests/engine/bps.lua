package.path='./?.lua;'..package.path
local B=require('src.translation.Bps')
local checks=0;local function check(v,m)assert(v,m);checks=checks+1 end
local function n(value)
 local out={}
 while true do local b=value%128;value=math.floor(value/128)
  if value==0 then out[#out+1]=string.char(b+128);return table.concat(out)end
  out[#out+1]=string.char(b);value=value-1
 end
end
local function u32(v)local out={};for _=1,4 do out[#out+1]=string.char(v%256);v=math.floor(v/256)end;return table.concat(out)end
local function patch(source,target,actions,metadata)
 metadata=metadata or''
 local p='BPS1'..n(#source)..n(#target)..n(#metadata)..metadata..actions..u32(B.crc32(source))..u32(B.crc32(target))
 return p..u32(B.crc32(p))
end
check(B.crc32('123456789')==0xcbf43926,'standard independent CRC32 vector')
local p=patch('abc','abXY',n(4)..n(5)..'XY')
check(B.apply('abc',p,4)=='abXY','source read plus literal expansion')
check(B.apply('abc',patch('abc','cba',n(2)..n(4)..n(2)..n(5)..n(2)..n(5)))=='cba','positive and negative source-copy deltas')
local copy=patch('','abababab',n(5)..'ab'..n(23)..n(0))
check(B.apply('',copy,8)=='abababab','overlapping target-copy expands only produced seed bytes')
check(B.apply('',patch('','abcdabcdabcd',n(5)..'ab'..n(5)..'cd'..n(31)..n(0)))=='abcdabcdabcd','target-copy reads across output chunks without flattening the whole prefix')
check(B.apply('',patch('','', '', 'metadata'))=='','empty image and bounded metadata')
local calls=0;check(B.apply('abc',p,4,function()calls=calls+1 end)=='abXY'and calls==1,'progress is observable without yielding once per tiny operation')
local function rejects(source,p,limit,label)check(not pcall(B.apply,source,p,limit),label)end
rejects('abc',p,3,'output allocation bound')
rejects('xyz',p,4,'wrong source checksum')
rejects('ab',p,4,'wrong source size')
rejects('abc',p:sub(1,-2)..string.char((p:byte(-1)+1)%256),4,'corrupt patch checksum')
rejects('','BPS1',4,'truncated header')
rejects('abc',patch('abc','abcd',n(12)),4,'source read outside input')
rejects('',patch('','x',n(3)..n(0)),4,'target copy before initial output')
rejects('abc',patch('abc','x',n(2)..n(7)),4,'negative source position')
rejects('abc',patch('abc','x',n(5)..'XX'),4,'action exceeding output size')
rejects('abc',patch('abc','z',n(0)),4,'incorrect target checksum')
rejects('abc',patch('abc','a',n(0)..n(0)),4,'trailing actions')
check(not pcall(B.apply,'abc',p,4,function()error('cancelled')end),'cancel stops before returning any output')
print('BPS: '..checks..' checks passed')
