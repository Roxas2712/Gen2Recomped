-- Native RS bottom-panel data. The cartridge's tilemap is RAW, unlike Emerald.
local M={}
function M.extract(x,load,rom,cache)
  x:beginStage('Ruby/Sapphire native battle panels')
  local A=load('src.import.gba.rs.assets');local K=load('src.import.gba.rse.boot_gfx')
  local c=A.context(rom,cache,{},'battle_panel')
  local gfx=c:lz('gBattleTextboxTiles');local map=c:raw('gBattleTextboxTilemap')
  local rawPal=c:lz('gBattleTextboxPalette');local pal=c:palFrom(rawPal)
  assert(#gfx==8192 and #map==4096 and #rawPal==64,'Native RS battle panel dimensions changed')
  local images={}
  for i,key in ipairs({'message','action','moves'})do
    local pixels,w,h=K.bakeText(gfx,map,30,6,{linear=true,mapWidth=32,mapOffset=(14+(i-1)*20)*32})
    images[key]=c:png(key..'.png',w,h,pixels,pal,true)
  end
  assert(A.finish(c,{screen='battle_panel',images=images}))
  local function word(key)
    return assert(x:readText(c:off(key)),'Missing native RS battle label '..key)
  end
  x._constants.gen3RsBattlePanel={format=1,version=x.version,images=images,
    palette=K.palList(pal,0,16),pp=assert(word('BattleText_PP'):match('^[^\n]+')),switch=word('BattleText_SwitchWhich'),
    source='ROM:gBattleTextboxTiles, raw gBattleTextboxTilemap, gBattleTextboxPalette; native RS battle labels'}
end
function M.missing(version)
  local Fs=require('src.import.CacheFs')
  local function read(path)
    local raw=Fs.read(path);local f=raw and loadstring(raw);if not f then return end;setfenv(f,{})
    local ok,t=pcall(f);return ok and type(t)=='table'and t or nil
  end
  local c=read('data/generated/constants.lua')or {};local s=c.gen3RsBattlePanel
  if type(s)~='table'or s.format~=1 or s.version~=version or type(s.images)~='table'
    or type(s.palette)~='table'or #s.palette~=16 or type(s.pp)~='string'or type(s.switch)~='string'then
    return {'<rs:native-battle-panel>'}
  end
  local absent={};local path='data/generated/gba/battle_panel/manifest.lua';local man=read(path)
  if not man or man.layout~='rs'or man.game~=version or type(man.files)~='table'or #man.files~=3 then absent[#absent+1]=path
  else for _,name in ipairs(man.files)do if type(name)~='string'or not Fs.exists(name)then absent[#absent+1]=tostring(name)end end end
  for _,key in ipairs({'message','action','moves'})do
    if type(s.images[key])~='string'or not Fs.exists(s.images[key])then absent[#absent+1]='<rs:battle-panel-'..key..'>'end
  end
  return absent
end
return M
