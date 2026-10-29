-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Own-cartridge item quantity, confirmation and result vocabulary.
local M={}
local versions={emerald=true,firered=true,leafgreen=true}
function M.labels(version)
  if version=='emerald'then return{
    prompt='gText_TossHowManyVar1s',count='gText_xVar1',confirm='gText_ConfirmTossItems',
    done='gText_ThrewAwayVar2Var1s',yes='gText_Yes',no='gText_No'}end
  return{prompt='gText_TossOutHowManyStrVar1s',count='gText_TimesStrVar1',
    confirm='gText_ThrowAwayStrVar2OfThisItemQM',done='gText_ThrewAwayStrVar2StrVar1s',
    yes='gText_Yes',no='gText_No'}
end
function M.extract(x)
  if not versions[x.version]then return end
  x:beginStage('Original bag toss quantity and confirmation')
  local load=require('compat.gen1-rs.Loader').new(x.version)
  local IR=load('src.core.game3.scripting.text_ir');local symbols,labels
  if x.version=='emerald'then symbols=load('src.import.gba.syms').of(x.version)
  else labels=require('src.import.gba.text_labels.'..x.version)end
  local text={}
  for key,name in pairs(M.labels(x.version))do
    local at=assert(symbols and symbols.off(name)or(labels and labels[name]),'Missing native bag text '..name)
    local bytes={}
    for i=0,2047 do local b=x.rom:u8(at+i);bytes[#bytes+1]=b;if b==255 then break end end
    assert(bytes[#bytes]==255,'Unterminated native bag text '..name)
    text[key]=IR.decode(bytes,{dialect=x.version=='emerald'and'rse'or'frlg'})
  end
  x._constants.gen3BagToss={format=1,version=x.version,textIR=text}
  x:write('constants',x._constants)
end
function M.valid(spec,version)
  if not(versions[version]and type(spec)=='table'and spec.format==1 and spec.version==version
    and type(spec.textIR)=='table')then return false end
  for key in pairs(M.labels(version))do
    if type(spec.textIR[key])~='table'or#spec.textIR[key]==0 then return false end
  end
  return true
end
function M.missing(version)
  if not versions[version]then return{}end
  local raw=require('src.import.CacheFs').read('data/generated/constants.lua')
  local f=raw and loadstring(raw);if f then setfenv(f,{})end
  local ok,c=false,nil;if f then ok,c=pcall(f)end
  if ok and type(c)=='table'and M.valid(c.gen3BagToss,version)then return{}end
  return{'<'..version..':native-bag-toss>'}
end
return M
