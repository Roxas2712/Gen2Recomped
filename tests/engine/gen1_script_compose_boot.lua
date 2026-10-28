-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local Version=require('src.core.GameVersion')
local Scripts=require('src.script.MapScripts')
local Data=require('src.core.Data')
local oldMaps,oldScripts=Data.maps,Data.map_scripts
for _,edition in ipairs({'red','blue','yellow'})do
 Version.set(edition)
 Scripts.resetBase()
 for name in pairs(package.loaded)do
  if name:sub(1,13)=='data.scripts.'then package.loaded[name]=nil end
 end
 local data=T.fixtures.fresh()
 local run=T.sdk.loadMods({'mods/map_extension'},{data=data,fs=T.sdk.memfs({
  ['mods/map_extension/manifest.json']='{"id":"map_extension","name":"Map extension","version":"1.0.0","api":2,"entry":"main.lua"}',
  ['mods/map_extension/main.lua']=[[
   local mod=...
   mod.content.map_scripts:register('OAKS_LAB',{priority=1800,
    onInteract=function(_,_,x,y)return x==1 and y==1 end})
  ]],
 })})
 T.eq(#run.errors,0,edition..': map extension loads through the actual registry')
 -- Map dispatch reads the live Data singleton. Publish the registry merge
 -- there just as Game:load does, while retaining ROM-free fixture content.
 Data.maps,Data.map_scripts=data.maps,data.map_scripts
 local maps=require('data.scripts.init')
 local lab=assert(maps.get('OAKS_LAB'))
 T.eq(type(lab.onEnter),'function','ROM-free Gen1 story entry remains installed')
 T.eq(type(lab.onStep),'function','starter and rival coordinate scripts remain installed')
 T.check(lab.onInteract(nil,nil,1,1),'mod interaction composes over the actual story')
 T.check(not lab.onInteract(nil,nil,2,1),'neighbouring cells remain unhandled')
 local town=assert(maps.get('PALLET_TOWN'))
 T.eq(type(town.onStep),'function','Oak escort remains installed beside mod scripts')
 local fake={save={flags={}},stack={}}
 local ok=pcall(lab.onEnter,fake,{})
 T.check(ok,'repeatable source wrapping has a native entry to call')
 run.release()
end
Data.maps,Data.map_scripts=oldMaps,oldScripts
T.finish('Gen1 story boot with composed map extensions')
