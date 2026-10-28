-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Portable error/handle contract. The Windows CI driver separately exercises
-- the actual wide APIs against files written by LÖVE in a Unicode directory.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.harness')
local Native=require('src.core.NativeFile')
local oldLove,oldOpen=love,io.open
love={system={getOS=function()return 'Linux'end}}
for _,bad in ipairs{false,42,'','a\0b'}do
 local bytes,why=Native.read(bad);T.eq(bytes,nil);T.check(type(why)=='string')
end
local closed=0
io.open=function(path,mode)
 T.eq(path,'owned fixture');T.eq(mode,'rb')
 return{read=function()return '\0PNG\255'end,close=function()closed=closed+1 end}
end
T.eq(Native.read('owned fixture'),'\0PNG\255');T.eq(closed,1)
io.open=function()return nil,'owned open failure'end
local bytes,why=Native.read('owned fixture');T.eq(bytes,nil);T.eq(why,'owned open failure')
io.open=function()error('owned open exception')end
bytes,why=Native.read('owned fixture');T.eq(bytes,nil);T.check(why:find('owned open exception',1,true)~=nil)
for _,read in ipairs{function()return ''end,function()error('owned read exception')end,function()return nil,'owned read failure'end}do
 io.open=function()return{read=read,close=function()closed=closed+1 end}end
 bytes,why=Native.read('owned fixture');T.eq(bytes,nil);T.check(type(why)=='string')
end
T.eq(closed,4,'all opened handles are closed, including read failures')
io.open, love=oldOpen,oldLove
T.finish('native readonly file bytes and error cleanup')
