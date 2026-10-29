-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit');local Guard=dofile('tools/async-get-check/poll_guard.lua')
local g=Guard.new();local calls=0
local api={read=function(n)calls=calls+1;return n end}
g:watch(api,'read','fixture.read');g:watch(api,'missing')
T.eq(api.read(7),7);T.eq(calls,1,'ordinary IO outside poll remains available')
T.eq(g:poll(function()return'pending'end),'pending')
T.eq(pcall(function()g:poll(api.read,8)end),false,'blocking IO is rejected in the caller')
T.eq(calls,1);T.eq(g.inside,false,'failure restores the scope')
T.eq(pcall(function()g:poll(function()pcall(api.read,9);return'ok'end)end),false,
 'an implementation cannot hide IO by catching its exception')
T.eq(calls,1);T.eq(g.inside,false)
T.eq(pcall(function()g:poll(function()error('unrelated failure')end)end),false)
T.eq(g.inside,false)
T.eq(g:poll(function()return'ok'end),'ok','later polls remain usable')
T.eq(api.read(10),10);T.eq(calls,2)
T.finish('Main-thread poll IO guard and error restoration')
