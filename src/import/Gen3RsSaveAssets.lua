-- The native RS save dialog reuses the edition's existing fonts and frames.
local M={}
local LABELS={gText_SavingPlayer='gOtherText_Player',gText_SavingBadges='gOtherText_Badges',
  gText_SavingPokedex='gOtherText_Pokedex',gText_SavingTime='gOtherText_PlayTime',
  gText_ConfirmSave='gSaveText_WouldYouLikeToSave',gText_AlreadySavedFile='gSaveText_ThereIsAlreadyAFile',
  gText_SavingDontTurnOff='gSaveText_DontTurnOff',gText_PlayerSavedGame='gSaveText_PlayerSavedTheGame',
  -- Host file IO failures use the original generic failure message. The
  -- cartridge's backup-memory replacement warning needs a different screen.
  gText_SaveError='gSystemText_SaveFailed',gText_Yes='OtherText_Yes',gText_No='OtherText_No'}
function M.extract(x,load,rom)
  x:beginStage('Ruby/Sapphire original save dialog')
  local S=load('src.import.gba.syms').of(x.version)
  local ir=load('src.core.game3.scripting.text_ir');local labels={}
  for key,symbol in pairs(LABELS)do
    local at=assert(S.off(symbol));local bytes={};local ended=false
    for i=0,1023 do
      local b=rom:get(at+i);bytes[#bytes+1]=b
      if b==255 then ended=true;break end
    end
    assert(ended,'Unterminated native RS save label '..symbol)
    labels[key]=ir.decode(bytes,{dialect='rs'})
  end
  x._constants.gen3RsSave={format=1,version=x.version,textIR=labels,
    source='ROM: original RS save-info labels, save/overwrite prompts, result and error'}
end
function M.valid(spec,version)
  if not((version=='ruby'or version=='sapphire')and type(spec)=='table'and spec.format==1
    and spec.version==version and type(spec.textIR)=='table')then return false end
  for key in pairs(LABELS)do if type(spec.textIR[key])~='table'then return false end end
  return true
end
function M.missing(version)
  local raw=require('src.import.CacheFs').read('data/generated/constants.lua')
  local f=raw and loadstring(raw);if f then setfenv(f,{})end
  local ok,value=false,nil;if f then ok,value=pcall(f)end
  if ok and type(value)=='table'and M.valid(value.gen3RsSave,version)then return{}end
  return{'<rs:native-save-dialog-text>'}
end
return M
