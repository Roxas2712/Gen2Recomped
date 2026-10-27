-- Original RS main-menu labels; geometry and state machine remain pinned.
local M={}
local LABELS={'gMainMenuString_Continue','gMainMenuString_NewGame','gMainMenuString_Option',
  'gMainMenuString_MysteryEvents','SystemText_Exit','gMainMenuString_Player',
  'gMainMenuString_Time','gMainMenuString_Pokedex','gMainMenuString_Badges',
  'gSaveFileDeletedMessage','gSaveFileCorruptMessage','gBoardNotInstalledMessage','gBatteryDryMessage'}
function M.extract(x,load,rom)
  x:beginStage('Ruby/Sapphire original main menu')
  local S=load('src.import.gba.syms').of(x.version)
  local IR=load('src.core.game3.scripting.text_ir');local labels={}
  for _,key in ipairs(LABELS)do
    local at=assert(S.off(key));local bytes={};local ended=false
    for i=0,2047 do
      local b=rom:get(at+i);bytes[#bytes+1]=b
      if b==255 then ended=true;break end
    end
    assert(ended,'Unterminated original RS menu label '..key)
    labels[key]=IR.decode(bytes,{dialect='rs'})
  end
  x._constants.gen3RsMainMenu={format=1,version=x.version,textIR=labels,
    source='ROM: original RS main-menu labels and save/RTC error messages'}
end
function M.valid(spec,version)
  if not((version=='ruby'or version=='sapphire')and type(spec)=='table'and spec.format==1
    and spec.version==version and type(spec.textIR)=='table')then return false end
  for _,key in ipairs(LABELS)do
    if type(spec.textIR[key])~='table'or #spec.textIR[key]==0 then return false end
  end
  return true
end
function M.missing(version)
  local raw=require('src.import.CacheFs').read('data/generated/constants.lua')
  local f=raw and loadstring(raw);if f then setfenv(f,{})end
  local ok,c=false,nil;if f then ok,c=pcall(f)end
  if ok and type(c)=='table'and M.valid(c.gen3RsMainMenu,version)then return{}end
  return{'<rs:native-main-menu>'}
end
return M
