-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local V=require('src.core.GameVersion');local Data=require('src.core.Data')
local Scripts=require('src.script.MapScripts');local VM=require('src.script.Gen3ScriptVM')
local priorMaps,priorPool=Data.maps,Data.map_scripts
local function reset()
 Scripts.resetBase()
 for name in pairs(package.loaded)do
  if name:sub(1,13)=='data.scripts.'then package.loaded[name]=nil end
 end
end
for _,edition in ipairs{'firered','leafgreen'}do
 V.set(edition);reset()
 local data=T.fixtures.fresh();data.maps={}
 data.map_scripts={source='RomExtractorGen3',maps={},scripts={}}
 for n=75,80 do
  local id=('MAP_G01_N%02d'):format(n);local key='OWNED_'..n
  data.maps[id]={id=id,group=1,number=n,width=13,height=13,tileset='FIX_OUT',
   blocks={0},objects={{index=1,text='TEXT_'..id..'_OBJ_001'}}}
  data.map_scripts.maps[id]={objects={key},callbacks={{type=1,script=key}}}
  data.map_scripts.scripts[key]={{'setvar',0x400B,n},{'end'}}
 end
 Data.seedDefaults(data);Data.maps,Data.map_scripts=data.maps,data.map_scripts
 local dispatch=require('data.scripts.init')
 for n=75,80 do
  local id=('MAP_G01_N%02d'):format(n);local map=data.maps[id]
  local text=map.objects[1].text
  T.eq(dispatch.talkScript(id,text),VM.compile(data,'OWNED_'..n),
   edition..': readable League alias must retain the original object program')
 end
 -- An authored alias with a distinct registry record has no native owner.
 reset();data.maps.LORELEIS_ROOM={id='LORELEIS_ROOM',objects={}}
 require('data.scripts.init')
 T.eq(type(Scripts.talkScript('LORELEIS_ROOM','TEXT_LORELEISROOM_LORELEI')),'function',
  'authored non-native room retains its hand-ported story')
end
for _,edition in ipairs{'ruby','sapphire','emerald'}do
 V.set(edition);reset()
 local data=T.fixtures.fresh();data.maps={}
 local id='MAP_G00_N00';data.maps[id]={id=id,group=0,number=0,objects={{text='OWNED_TALK'}}}
 data.map_scripts={source='RomExtractorGen3',maps={[id]={objects={'OWNED'}}},
  scripts={OWNED={{'setvar',0x400B,7},{'end'}}}}
 Data.seedDefaults(data);Data.maps,Data.map_scripts=data.maps,data.map_scripts
 T.eq(require('data.scripts.init').talkScript(id,'OWNED_TALK'),VM.compile(data,'OWNED'),
  'Hoenn retains its original object program')
end
Data.maps,Data.map_scripts=priorMaps,priorPool;reset()
T.finish('Native GBA script ownership through shared aliases and authored fallback')
