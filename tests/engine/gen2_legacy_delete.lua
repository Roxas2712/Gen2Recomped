package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local V=require('src.core.GameVersion')
local old=V.get()
for _,edition in ipairs{'gold','silver','crystal','prism','polishedcrystal'}do
 for _,api in ipairs{1,2}do
  V.set(edition)
  local data=T.fixtures.fresh();data.constants.gen=2
  data.map_scripts={marts={[0]={'TEST_ITEM'}}}
  local run=T.sdk.loadMods({'mods/delete_probe'},{data=data,fs=T.sdk.memfs({
   ['mods/delete_probe/manifest.json']=('{"id":"delete_probe","name":"Deletion contracts","version":"1.0.0","api":%d,"entry":"main.lua","affects_link":true}'):format(api),
   ['mods/delete_probe/main.lua']=[[
    local mod=...
    local mon={}
    for k,v in pairs(mod.content.pokemon:get('FIXMON_A'))do mon[k]=v end
    mon.id,mon.name='DELETE_MON','DELETE MON'
    mod.content.pokemon:register('DELETE_MON',mon)
    mod.content.pokemon:patch('DELETE_MON',{types=mod.DELETE})
    assert(mod.content.pokemon:get('DELETE_MON').types==nil,'nested type deletion survives source-name adaptation')
    mod.content.pokemon:remove('DELETE_MON')
    assert(mod.content.pokemon:get('DELETE_MON')==nil,'Pokemon removal preserves the native registry contract')
    mod.content.move_effects:register('DELETE_EFFECT',{kind='primary',run=function()end})
    mod.content.moves:register('DELETE_MOVE',{id='DELETE_MOVE',name='DELETE MOVE',type='NORMAL',
      power=20,accuracy=100,pp=10,effect='DELETE_EFFECT'})
    mod.content.moves:remove('DELETE_MOVE')
    assert(mod.content.moves:get('DELETE_MOVE')==nil,'move removal preserves the native registry contract')
    mod.content.move_effects:remove('DELETE_EFFECT')
    assert(mod.content.move_effects:get('DELETE_EFFECT')==nil,'effect removal preserves the native registry contract')
    mod.content.type_chart:register('DELETE_TYPE',{name='DELETE TYPE',category='physical'})
    mod.content.type_chart:remove('DELETE_TYPE')
    assert(mod.content.type_chart:get('DELETE_TYPE')==nil,'type removal preserves the native registry contract')
    mod.content.marts:remove('0')
    assert(mod.content.marts:get('0')==nil,'shop removal preserves the native registry contract')
   ]],
  })})
  local label=edition..' API '..api
  T.eq(#run.errors,0,label..' deletes through the real content API')
  T.eq(data.pokemon.DELETE_MON,nil,label..' removes the native species record')
  T.eq(data.moves.DELETE_MOVE,nil,label..' removes the native move record')
  T.eq(data.move_effects and data.move_effects.DELETE_EFFECT,nil,label..' removes the native effect record')
  T.eq(data.type_chart.types.DELETE_TYPE,nil,label..' removes the native type record')
  T.same(data.map_scripts.marts[0],{},label..' removes stock from the actual native shop')
  run.release()
 end
end
V.set(old)
T.finish('Legacy Gen2 content deletion and nested tombstone identity through native registries')
