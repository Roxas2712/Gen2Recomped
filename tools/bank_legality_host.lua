-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
love=require('tests.love_stub')
local J=require('src.link.Json')
local function read(path)local f=assert(io.open(path,'rb'));local b=f:read('*a');f:close();return b end
local function indices(value)
 if type(value)~='table'then return value end
 local out={};for k,v in pairs(value)do local n=type(k)=='string'and k:match('^%d+$')and tonumber(k);out[n or k]=indices(v)end;return out
end
local function run()
 local bytes=read(assert(arg[1]));assert(#bytes<=512*1024,'Bank request exceeds limit')
 local input=assert(J.decode(bytes));local entry=indices(input.entry)
 assert(type(entry)=='table'and entry.schema==1 and type(entry.source)=='table'and type(entry.mon)=='table','Invalid Bank entry')
 local V=require('src.core.GameVersion');assert(V.info(entry.source.version),'Unknown edition');V.set(entry.source.version)
 local D=require('src.core.Data');D:load();require('src.mods.Loader').new({noMods=true}):load(D)
 local result=require('src.storage.LegalityRecord').export(entry,D)
 result.reward_genetics=require('src.storage.RewardVerification').check(indices(input.issued),entry,D,entry.source.version)
 return result
end
local ok,record=pcall(run)
local f=assert(io.open(assert(arg[2]),'wb'));f:write(J.encode(ok and record or{schema=1,error='Native Bank record could not be exported',detail=tostring(record):sub(1,300)}));f:close()
os.exit(ok and 0 or 2)
