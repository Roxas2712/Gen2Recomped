package.path='./?.lua;'..package.path
love=require('tests.love_stub')
local n=0;local function check(v,m) assert(v,m);n=n+1 end
local file=assert(io.open('src/core/Game.lua','rb'));local source=file:read('*a');file:close()
local fn=assert(source:match('(function Game:writeSave%(%)%s.-)\n%-%- Persist options'))
local stamp={schema=1,version='red',mods={}}
local saved,allowed=true,true
local captures,emitted=0,0
local data={ensurePlaythroughId=function(value)check(value.meta.playthroughId=='same-adventure','the writer ensures the durable identity before stamping metadata');return value.meta.playthroughId end,
 buildMeta=function(_,prior) return {format=4,mods={},playthroughId=prior.playthroughId} end,
 loadOptions=function() return {secret='KEEP LOCAL'} end,save=function(value) saved=value;return true end}
local runtime={call=function() return allowed end,wants=function() return true end,emit=function(_,payload) emitted=emitted+1;check(payload.meta.resume==stamp or payload.meta.resume.schema==0,'save hooks observe the requirements that will be persisted') end}
package.loaded['src.storage.SaveResume']={capture=function(version,loaded,options)
 captures=captures+1;check(version=='red' and loaded[1].id=='required' and options.secret=='KEEP LOCAL','the writer captures the actual loaded mod set before persisting')
 return stamp
end}
local chunk=assert(loadstring('return function(Game,SaveData,ModRuntime) '..fn..' end'))()
local Game={};chunk(Game,data,runtime)
local game=setmetatable({save={version='red',meta={playthroughId='same-adventure'}},modStatus={loaded={{id='required'}}},overworld={captureSave=function() end}},{__index=Game})
check(game:writeSave() and saved.meta.resume==stamp and saved.meta.playthroughId=='same-adventure','normal progress writes include save-bound requirements without replacing playthrough identity')
allowed=false;local before=captures;check(not game:writeSave() and captures==before,'a mod write veto runs before any metadata capture or write')
allowed=true;package.loaded['src.storage.SaveResume'].capture=function() error('unstable mod metadata') end
check(game:writeSave() and saved.meta.resume.schema==0,'a metadata failure preserves local progress but cannot masquerade as a vanilla save')
print('Save requirement capture: '..n..' checks passed')
