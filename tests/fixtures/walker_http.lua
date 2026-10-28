-- Uses the real cloud, task, storage and walker modules against loopback Laravel.
-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
local task,started
function love.load()
 local Auth=require('src.cloud.RetroCloud')
 local endpoint=assert(os.getenv('WALKER_HTTP_URL'))
 assert(endpoint:match('^http://127%.0%.0%.1:%d+$'),'Only isolated loopback is permitted')
 Auth.API=endpoint..'/api/cloud/v1'
 assert(Auth.acceptConnection({account_id=assert(os.getenv('WALKER_HTTP_ACCOUNT')),access_token=assert(os.getenv('WALKER_HTTP_TOKEN')),email='qa@example.invalid',expires_in=3600}))
 local Policy=require('src.storage.AccountStorage');Policy.enable();assert(Policy.bind())
 task=assert(require('src.cloud.Task').new(function()
  local W=require('src.pokewalker.Walker');local C=require('src.pokewalker.WalkerCloud')
  local store=assert(Auth.open());local phase=assert(os.getenv('WALKER_HTTP_PHASE'));local checks=0
  local function check(v,m)assert(v,m);checks=checks+1 end
  if phase=='seed'then
   local st=W.load();st.watts=125;st.minigames={games={memory={best=321,plays=2}},day=1,daily={watts=25}};assert(W.save(st))
   check(C.sync(store)=='uploaded','first isolated client uploads')
  elseif phase=='advance200'or phase=='advance300'or phase=='pull'then
   local result,why=C.sync(store,true);assert(result,why)
   local st=W.load()
   check(st.minigames.games.memory.best==321,'personal record crosses profiles through HTTP')
   if phase=='pull'then check(st.watts==200,'original client resumes the second client’s updated progress')
   else
    st.watts=phase=='advance200'and 200 or 300;assert(W.save(st))
    check(C.sync(store)=='uploaded','restored client advances cloud progress')
   end
  elseif phase=='conflict'then
   local st=W.load();st.watts=250;assert(W.save(st))
   local result,why=C.sync(store)
   check(not result and why:find('both devices',1,true),'real HTTP detects conflicting offline branches')
   check(W.load().watts==250,'local conflicting balance stays unchanged')
   check(C.decode(store.read(C.PATH)).state.watts==300,'cloud conflicting balance stays unchanged')
  elseif phase=='foreign'then
   check(not store.read(C.PATH),'another account cannot read the first account’s snapshot')
   check(C.sync(store,true)=='empty','another account does not restore the first account’s walker')
  elseif phase=='revision'then
   local first=assert(Auth.open());local second=assert(Auth.open())
   local S=require('src.core.SaveSerializer');local raw=assert(first.read(C.PATH));local doc=S.decode(raw);doc.state.watts=301
   assert(second.write(C.PATH,S.encode(doc)))
   local result,why=first.write(C.PATH,raw)
   check(not result and why:find('another device',1,true),'real server enforces If-Match on competing object writes')
  else error('Unknown isolated phase')end
  return{passed=true,checks=checks,phase=phase,scope='Real HTTP with isolated Laravel SQLite and LÖVE profiles; not production'}
 end))
 started=love.timer.getTime()
end
function love.update()
 assert(love.timer.getTime()-started<60,'HTTP scenario timed out')
 local result=task:poll();if not result then return end
 assert(result.kind=='done'and result.first,result.second or result.error)
 local file=assert(io.open(assert(os.getenv('WALKER_HTTP_REPORT')),'wb'))
 file:write(require('src.link.Json').encode(result.first));file:close()
 love.event.quit(0)
end
function love.errorhandler(err)print(tostring(err)..'\n'..debug.traceback());return function()return 1 end end
