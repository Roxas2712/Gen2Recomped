-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Original Emerald item-storage labels; existing Emerald fonts/frames suffice.
local M={labels={'gText_Cancel2','gText_ConfirmTossItems','gText_GoBackPrevMenu',
 'gText_MoveVar1Where','gText_No','gText_NoRoomInBag','gText_NoItems','gText_ThrewAwayVar2Var1s',
 'gText_TooImportantToToss','gText_TossHowManyVar1s','gText_TossItem',
 'gText_WithdrawHowManyItems','gText_WithdrawItem','gText_WithdrawXItems','gText_Yes','gText_xVar1'}}
function M.extract(x)
 if x.version~='emerald'then return end
 x:beginStage('Emerald original item storage')
 local load=require('compat.gen1-rs.Loader').new('emerald')
 local symbols=load('src.import.gba.syms').of('emerald')
 local IR=load('src.core.game3.scripting.text_ir');local labels={}
 for _,name in ipairs(M.labels)do
  local at=assert(symbols.off(name));local bytes={}
  for i=0,2047 do local b=x.rom:u8(at+i);bytes[#bytes+1]=b;if b==255 then break end end
  assert(bytes[#bytes]==255,'Unterminated Emerald item-PC label '..name)
  labels[name]=IR.decode(bytes,{dialect='rse'})
 end
 local capacity=assert(x.manifest.saveFields.bag.pcItemCount)
 assert(capacity==50)
 x._constants.gen3EmeraldItemPc={format=1,version='emerald',capacity=capacity,slotMax=999,textIR=labels}
 x:write('constants',x._constants)
end
function M.valid(spec,version)
 if not(version=='emerald'and type(spec)=='table'and spec.format==1 and spec.version==version
  and spec.capacity==50 and spec.slotMax==999 and type(spec.textIR)=='table')then return false end
 for _,name in ipairs(M.labels)do if type(spec.textIR[name])~='table'then return false end end
 return true
end
function M.missing(version)
 if version~='emerald'then return{}end
 local raw=require('src.import.CacheFs').read('data/generated/constants.lua')
 local f=raw and loadstring(raw);if f then setfenv(f,{})end
 local ok,value=false,nil;if f then ok,value=pcall(f)end
 if ok and type(value)=='table'and M.valid(value.gen3EmeraldItemPc,version)then return{}end
 return{'<emerald:native-item-pc-text>'}
end
return M
