package.path='./?.lua;'..package.path
love=require('tests.love_stub')
local n=0;local function check(v,m) assert(v,m);n=n+1 end
local file=assert(io.open('src/core/SaveData.lua','rb'));local source=file:read('*a');file:close()
local peek=assert(source:match('(function SaveData.peekSlot%(version, slotId%)%s.-)\n%-%- Give a registered'))
local data={player={name='Untouched'},meta={mods={{id='local',version='development'}}}}
local reads=0;local state='ok'
local module={}
local setup=assert(loadstring('return function(SaveData,knownVersion,decodeSlot,persistFs) '..peek..' end'))()
setup(module,function(v) return v=='red' end,function(_,version,id) reads=reads+1;return state~='unreadable' and data or nil,state end,function() return {} end)
check(module.peekSlot('red','slot1')==data and reads==1,'pre-launch inspection returns the raw save before mod migrations or quarantine')
check(data.meta.resume==nil and data.player.name=='Untouched','inspection does not rewrite older saves or their requirements')
check(not module.peekSlot('blue','slot1') and not module.peekSlot('red','../../outside') and reads==1,'unknown games and invalid slot paths never reach persistence')
state='unreadable';local _,why=module.peekSlot('red','slot1');check(why:find('recovery',1,true),'unreadable progress is distinguished from an empty new-game slot')
local meta=assert(source:match('(function SaveData.buildMeta%(mods, previous%)%s.-)\n%-%- {added'))
local setupMeta=assert(loadstring('return function(SaveData,Version) '..meta..' end'))();setupMeta(module,require('src.core.Version'))
local requirements={schema=1,mods={{id='local',version='development'}}}
check(module.buildMeta(nil,{resume=requirements,mods={}}).resume==requirements,'ordinary metadata refreshes preserve save-bound requirements')
print('Save resume slot inspection: '..n..' checks passed')
